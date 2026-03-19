local Events = require("orchestrate.acp.events")
local PermissionServer = require("orchestrate.hooks.permission_server")

local ClaudeCodeTransport = {}
ClaudeCodeTransport.__index = ClaudeCodeTransport

local function decode_json(line)
  if line == "" then
    return nil
  end

  if vim.json and vim.json.decode then
    return vim.json.decode(line)
  end

  return vim.fn.json_decode(line)
end

local function find_session_id(payload)
  if type(payload) ~= "table" then
    return nil
  end

  if type(payload.session_id) == "string" and payload.session_id ~= "" then
    return payload.session_id
  end

  for _, key in ipairs({ "message", "result", "data" }) do
    if type(payload[key]) == "table" then
      local nested = find_session_id(payload[key])
      if nested then
        return nested
      end
    end
  end

  return nil
end

function ClaudeCodeTransport.new(opts)
  local self = setmetatable({}, ClaudeCodeTransport)
  self.dispatch = nil
  self.handle = nil
  self.stdin_pipe = nil
  self.stdout_pipe = nil
  self.stderr_pipe = nil
  self.request_id = nil
  self.stdout_buffer = ""
  self.stderr_buffer = ""
  self.stream_started = false
  self.current_content_blocks = {}
  self.pending_approvals = {}
  self:set_opts(opts)
  return self
end

function ClaudeCodeTransport:set_opts(opts)
  self.opts = opts or {}
end

function ClaudeCodeTransport:set_dispatch(dispatch)
  self.dispatch = dispatch
end

function ClaudeCodeTransport:emit(event_name, payload)
  if self.dispatch then
    vim.schedule(function()
      self.dispatch(event_name, payload or {})
    end)
  end
end

function ClaudeCodeTransport:get_command()
  local configured_command = (((self.opts or {}).transport or {}).claude_code or {}).command
  if configured_command then
    return configured_command
  end

  -- 尝试查找 claude 命令
  -- 1. 先检查是否在 PATH 中
  if vim.fn.executable("claude") == 1 then
    return "claude"
  end

  -- 2. 尝试通过 glob 查找 Homebrew Cask 安装（最可靠）
  local cask_pattern = "/opt/homebrew/Caskroom/claude-code/*/claude"
  local cask_matches = vim.fn.glob(cask_pattern, false, true)
  if #cask_matches > 0 then
    -- 使用最新版本（最后一个）
    return cask_matches[#cask_matches]
  end

  -- 3. 检查常见安装位置（使用 filereadable 而不是 executable）
  local common_paths = {
    "/opt/homebrew/bin/claude",
    "/usr/local/bin/claude",
    vim.fn.expand("~/.local/bin/claude"),
  }

  for _, path in ipairs(common_paths) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end

  -- 4. 最后回退到 "claude"
  return "claude"
end

function ClaudeCodeTransport:get_transport_opts()
  return ((self.opts or {}).transport or {}).claude_code or {}
end

function ClaudeCodeTransport:connect()
  return self:is_available()
end

function ClaudeCodeTransport:disconnect()
  -- 先杀死进程
  if self.handle and not self.handle:is_closing() then
    self.handle:kill(9)
  end
  -- 然后清理状态
  self:_cleanup_process()
end

function ClaudeCodeTransport:is_available()
  local command = self:get_command()

  -- 对于绝对路径，使用 filereadable 检查文件是否存在且可读
  -- vim.fn.executable() 对绝对路径在某些情况下不可靠
  if command:sub(1, 1) == "/" then
    if vim.fn.filereadable(command) == 1 then
      return true
    end
    return false, string.format("Claude Code command not found: %s", command)
  end

  -- 对于相对命令名，使用 executable 检查 PATH
  if vim.fn.executable(command) ~= 1 then
    return false, string.format("Claude Code command not found: %s", command)
  end

  return true
end

function ClaudeCodeTransport:healthcheck()
  local available, err = self:is_available()
  if not available then
    return {
      ok = false,
      message = err,
    }
  end

  local auth_paths = {
    vim.fn.expand("~/.config/claude-code/auth.json"),
    vim.fn.expand("~/AppData/Roaming/claude-code/auth.json"),
  }

  for _, path in ipairs(auth_paths) do
    if vim.fn.filereadable(path) == 1 then
      return {
        ok = true,
        message = string.format("Claude Code is available and auth file was found: %s", path),
      }
    end
  end

  if vim.env.ANTHROPIC_API_KEY and vim.env.ANTHROPIC_API_KEY ~= "" then
    return {
      ok = true,
      message = "Claude Code is available and ANTHROPIC_API_KEY is set.",
    }
  end

  return {
    ok = false,
    message = "Claude Code command is available, but no auth file or API key was detected.",
  }
end

function ClaudeCodeTransport:cancel(request_id)
  if request_id and self.request_id ~= request_id then
    return false, "request_not_found"
  end

  if self.handle then
    self:disconnect()
    return true
  end

  return false, "no_running_process"
end

function ClaudeCodeTransport:build_args(prompt, context)
  local args = {}
  local transport_opts = self:get_transport_opts()

  if context and context.mode == "continue" then
    table.insert(args, "--continue")
  elseif context and context.transport_session_id and transport_opts.resume_strategy ~= "fresh" then
    table.insert(args, "--resume")
    table.insert(args, context.transport_session_id)
  end

  table.insert(args, "-p")
  table.insert(args, prompt)
  table.insert(args, "--output-format")
  table.insert(args, "stream-json")
  table.insert(args, "--verbose")

  if transport_opts.max_turns then
    table.insert(args, "--max-turns")
    table.insert(args, tostring(transport_opts.max_turns))
  end

  if transport_opts.model then
    table.insert(args, "--model")
    table.insert(args, transport_opts.model)
  end

  -- Permission settings
  if transport_opts.allowed_tools and #transport_opts.allowed_tools > 0 then
    table.insert(args, "--allowedTools")
    table.insert(args, table.concat(transport_opts.allowed_tools, ","))
  end

  if transport_opts.permission_mode then
    if transport_opts.permission_mode == "bypassPermissions" then
      table.insert(args, "--dangerously-skip-permissions")
    elseif transport_opts.permission_mode == "acceptEdits" or transport_opts.permission_mode == "auto" then
      table.insert(args, "--permission-mode")
      table.insert(args, transport_opts.permission_mode)
    end
  end

  return args
end

-- 处理 assistant 消息中的 content blocks
function ClaudeCodeTransport:handle_assistant_message(payload)
  local message = payload.message
  if not message or type(message.content) ~= "table" then
    return
  end

  for idx, block in ipairs(message.content) do
    if block.type == "text" then
      self:emit(Events.CONTENT_BLOCK_START, {
        id = self.request_id,
        block_type = "text",
        index = idx - 1,
      })
      if block.text and block.text ~= "" then
        self:emit(Events.CONTENT_BLOCK_DELTA, {
          id = self.request_id,
          block_type = "text",
          delta = block.text,
        })
      end
      self:emit(Events.CONTENT_BLOCK_END, {
        id = self.request_id,
        block_type = "text",
      })
    elseif block.type == "thinking" then
      self:emit(Events.CONTENT_BLOCK_START, {
        id = self.request_id,
        block_type = "thinking",
        index = idx - 1,
      })
      if block.thinking and block.thinking ~= "" then
        self:emit(Events.CONTENT_BLOCK_DELTA, {
          id = self.request_id,
          block_type = "thinking",
          delta = block.thinking,
        })
      end
      self:emit(Events.CONTENT_BLOCK_END, {
        id = self.request_id,
        block_type = "thinking",
      })
    elseif block.type == "tool_use" then
      self:emit(Events.TOOL_USE_START, {
        id = self.request_id,
        tool_use_id = block.id,
        tool_name = block.name,
        input = block.input,
      })
      self:emit(Events.TOOL_USE_END, {
        id = self.request_id,
        tool_use_id = block.id,
        tool_name = block.name,
      })
    end
  end
end

-- 处理 user 消息中的 tool results
function ClaudeCodeTransport:handle_user_message(payload)
  local message = payload.message
  if not message or type(message.content) ~= "table" then
    return
  end

  for _, block in ipairs(message.content) do
    if block.type == "tool_result" then
      local content = ""
      if type(block.content) == "string" then
        content = block.content
      elseif type(block.content) == "table" then
        for _, item in ipairs(block.content) do
          if type(item) == "table" and item.type == "text" then
            content = content .. (item.text or "")
          elseif type(item) == "string" then
            content = content .. item
          end
        end
      end

      self:emit(Events.TOOL_RESULT, {
        id = self.request_id,
        tool_use_id = block.tool_use_id,
        content = content,
        is_error = block.is_error,
      })
    end
  end
end

-- 处理流式事件 (stream_event)
function ClaudeCodeTransport:handle_stream_event(payload)
  local event = payload.event
  if not event then
    return
  end

  local event_type = event.type

  if event_type == "content_block_start" then
    local content_block = event.content_block or {}
    local block_type = content_block.type or "text"
    local index = event.index or 0

    self.current_content_blocks[index] = {
      type = block_type,
      tool_use_id = content_block.id,
      tool_name = content_block.name,
    }

    if block_type == "text" then
      self:emit(Events.CONTENT_BLOCK_START, {
        id = self.request_id,
        block_type = "text",
        index = index,
      })
    elseif block_type == "thinking" then
      self:emit(Events.CONTENT_BLOCK_START, {
        id = self.request_id,
        block_type = "thinking",
        index = index,
      })
    elseif block_type == "tool_use" then
      self:emit(Events.TOOL_USE_START, {
        id = self.request_id,
        tool_use_id = content_block.id,
        tool_name = content_block.name,
        index = index,
      })
    end
  elseif event_type == "content_block_delta" then
    local delta = event.delta or {}
    local delta_type = delta.type
    local index = event.index or 0

    if delta_type == "text_delta" then
      self:emit(Events.CONTENT_BLOCK_DELTA, {
        id = self.request_id,
        block_type = "text",
        delta = delta.text or "",
        index = index,
      })
    elseif delta_type == "thinking_delta" then
      self:emit(Events.CONTENT_BLOCK_DELTA, {
        id = self.request_id,
        block_type = "thinking",
        delta = delta.thinking or "",
        index = index,
      })
    elseif delta_type == "input_json_delta" then
      -- Tool input streaming
      self:emit(Events.CONTENT_BLOCK_DELTA, {
        id = self.request_id,
        block_type = "tool_input",
        delta = delta.partial_json or "",
        index = index,
      })
    end
  elseif event_type == "content_block_stop" then
    local index = event.index or 0
    local block_info = self.current_content_blocks[index]

    if block_info then
      if block_info.type == "text" then
        self:emit(Events.CONTENT_BLOCK_END, {
          id = self.request_id,
          block_type = "text",
          index = index,
        })
      elseif block_info.type == "thinking" then
        self:emit(Events.CONTENT_BLOCK_END, {
          id = self.request_id,
          block_type = "thinking",
          index = index,
        })
      elseif block_info.type == "tool_use" then
        self:emit(Events.TOOL_USE_END, {
          id = self.request_id,
          tool_use_id = block_info.tool_use_id,
          tool_name = block_info.tool_name,
          index = index,
        })
      end
      self.current_content_blocks[index] = nil
    end
  elseif event_type == "message_start" then
    if not self.stream_started then
      self.stream_started = true
      self:emit(Events.ASSISTANT_STREAM_START, {
        id = self.request_id,
        title = "Claude Code",
      })
    end
  elseif event_type == "message_stop" then
    self:emit(Events.ASSISTANT_STREAM_END, {
      id = self.request_id,
    })
    -- message_stop 也表示消息完成
    self.request_completed = true
  end
end

function ClaudeCodeTransport:handle_json_line(line)
  local ok, payload = pcall(decode_json, line)
  if not ok or type(payload) ~= "table" then
    return
  end

  local session_id = find_session_id(payload)
  if session_id then
    self:emit(Events.SESSION_UPDATED, {
      transport = "claude_code",
      transport_session_id = session_id,
      last_request_id = self.request_id,
    })
  end

  local event_type = payload.type

  -- system/init 事件
  if event_type == "system" and payload.subtype == "init" then
    self:emit(Events.CONNECTED, {
      model = payload.model,
      cwd = payload.cwd,
      tools = payload.tools,
      session_id = payload.session_id,
    })
    return
  end

  -- stream_event - 流式增量更新
  if event_type == "stream_event" then
    if not self.stream_started then
      self.stream_started = true
      self:emit(Events.ASSISTANT_STREAM_START, {
        id = self.request_id,
        title = "Claude Code",
      })
    end
    self:handle_stream_event(payload)
    return
  end

  -- assistant 完整消息
  if event_type == "assistant" then
    if not self.stream_started then
      self.stream_started = true
      self:emit(Events.ASSISTANT_STREAM_START, {
        id = self.request_id,
        title = "Claude Code",
      })
    end
    self:handle_assistant_message(payload)
    return
  end

  -- user 消息 (包含 tool results)
  if event_type == "user" then
    self:handle_user_message(payload)
    return
  end

  -- permission 事件 - 权限请求 (如果 CLI 支持)
  if event_type == "permission" or event_type == "tool_permission" then
    local approval_id = payload.id or string.format("approval-%d", vim.loop.hrtime())
    -- 保存 pending approval 以便后续响应
    self.pending_approvals[approval_id] = {
      id = approval_id,
      tool_name = payload.tool_name or payload.name,
      input = payload.input,
    }
    self:emit(Events.APPROVAL_REQUESTED, {
      id = approval_id,
      title = payload.tool_name or payload.name or "Permission Required",
      description = payload.description or payload.message or "",
      tool_name = payload.tool_name or payload.name,
      command = payload.command or payload.input,
      input = payload.input,
    })
    return
  end

  -- result 事件 - 最终结果
  if event_type == "result" then
    if payload.is_error then
      self:emit(Events.ERROR, {
        message = type(payload.result) == "string" and payload.result or "Claude Code returned an error result.",
        detail = payload,
      })
      return
    end

    -- 如果有 result 文本且没有开始过流
    if type(payload.result) == "string" and payload.result ~= "" and not self.stream_started then
      self.stream_started = true
      self:emit(Events.ASSISTANT_STREAM_START, {
        id = self.request_id,
        title = "Claude Code",
      })
      self:emit(Events.CONTENT_BLOCK_START, {
        id = self.request_id,
        block_type = "text",
      })
      self:emit(Events.CONTENT_BLOCK_DELTA, {
        id = self.request_id,
        block_type = "text",
        delta = payload.result,
      })
      self:emit(Events.CONTENT_BLOCK_END, {
        id = self.request_id,
        block_type = "text",
      })
    end

    self:emit(Events.ASSISTANT_STREAM_END, {
      id = self.request_id,
      cost_usd = payload.cost_usd,
      num_turns = payload.num_turns,
      duration_ms = payload.duration_ms,
    })

    -- result 事件表示 Claude 已完成，标记可以接受新请求
    -- 注意：不要在这里关闭 handle，让进程自然退出
    -- 但要设置一个标志表示可以接受新请求
    self.request_completed = true
    return
  end
end

function ClaudeCodeTransport:process_chunk(chunk)
  if not chunk then
    return
  end

  self.stdout_buffer = self.stdout_buffer .. chunk

  -- 按行处理
  while true do
    local newline_pos = self.stdout_buffer:find("\n")
    if not newline_pos then
      break
    end

    local line = self.stdout_buffer:sub(1, newline_pos - 1)
    self.stdout_buffer = self.stdout_buffer:sub(newline_pos + 1)

    -- 移除可能的 \r
    line = line:gsub("\r$", "")

    if line ~= "" then
      self:handle_json_line(line)
    end
  end
end

-- 检查是否可以接受新请求
function ClaudeCodeTransport:is_running()
  -- 如果没有 handle，肯定不在运行
  if not self.handle then
    return false
  end

  -- 如果请求已完成（收到 result 事件），可以接受新请求
  if self.request_completed then
    return false
  end

  return true
end

-- 清理进程状态
function ClaudeCodeTransport:_cleanup_process()
  local Logger = require("orchestrate.utils.logger")
  Logger.debug("_cleanup_process called, handle=%s", tostring(self.handle))

  if self.stdin_pipe and not self.stdin_pipe:is_closing() then
    self.stdin_pipe:close()
  end
  if self.stdout_pipe and not self.stdout_pipe:is_closing() then
    self.stdout_pipe:close()
  end
  if self.stderr_pipe and not self.stderr_pipe:is_closing() then
    self.stderr_pipe:close()
  end
  if self.handle and not self.handle:is_closing() then
    self.handle:close()
  end

  self.handle = nil
  self.stdin_pipe = nil
  self.stdout_pipe = nil
  self.stderr_pipe = nil
  self.pending_approvals = {}
  self.request_completed = false

  Logger.debug("_cleanup_process done, handle=%s", tostring(self.handle))

  -- 停止 permission server
  PermissionServer.stop()
end

function ClaudeCodeTransport:send_message(text, context)
  local available, err = self:is_available()
  if not available then
    return false, err
  end

  -- 使用更可靠的检查
  local Logger = require("orchestrate.utils.logger")
  Logger.debug("send_message: checking if running, handle=%s", tostring(self.handle))
  if self:is_running() then
    Logger.debug("send_message: still running, rejecting")
    return false, "A Claude Code request is already running."
  end
  Logger.debug("send_message: not running, proceeding")

  local transport_opts = self:get_transport_opts()
  local command = self:get_command()
  local args = self:build_args(text, context or {})

  self.request_id = string.format("claude-request-%d", vim.loop.hrtime())
  self.stdout_buffer = ""
  self.stderr_buffer = ""
  self.stream_started = false
  self.request_completed = false
  self.current_content_blocks = {}

  -- 使用 vim.uv (libuv) 进行真正的流式处理
  local uv = vim.uv or vim.loop

  self.stdout_pipe = uv.new_pipe(false)
  self.stderr_pipe = uv.new_pipe(false)

  -- 启动 permission server 用于交互式权限审批
  local Logger = require("orchestrate.utils.logger")
  if transport_opts.interactive_permissions == true then
    local ok, path = PermissionServer.start()
    Logger.info("Permission server started: ok=%s, path=%s", tostring(ok), tostring(path))
    if ok then
      -- 获取 hook 脚本路径 (优先使用 Python 脚本)
      local plugin_root = vim.fn.fnamemodify(
        debug.getinfo(1, "S").source:sub(2),
        ":h:h:h:h:h"
      )
      local hook_script = plugin_root .. "/scripts/permission_hook.py"

      -- 如果 Python 脚本不存在，回退到 shell 脚本
      if vim.fn.filereadable(hook_script) ~= 1 then
        hook_script = plugin_root .. "/scripts/permission_hook.sh"
      end
      Logger.info("Hook script: %s (exists: %s)", hook_script, tostring(vim.fn.filereadable(hook_script) == 1))

      if vim.fn.filereadable(hook_script) == 1 then
        -- 使用 /bin/bash -c 来正确执行带环境变量的命令
        local wrapper_command = string.format(
          "/bin/bash -c 'ORCHESTRATE_PERMISSION_SOCKET=\"%s\" exec \"%s\"'",
          path,
          hook_script
        )
        -- 使用 PreToolUse hook 而不是 PermissionRequest
        -- 因为 PermissionRequest 只在交互模式下显示权限对话框时触发
        -- 而 -p 模式下不会显示对话框，所以 PermissionRequest 不会被触发
        -- PreToolUse 在每次工具调用前都会触发
        local settings = {
          hooks = {
            PreToolUse = {
              {
                -- 匹配需要权限的工具: Bash, Edit, Write, NotebookEdit
                matcher = "Bash|Edit|Write|NotebookEdit",
                hooks = { { type = "command", command = wrapper_command, timeout = 120 } },
              },
            },
          },
        }
        local settings_json = vim.json.encode(settings)
        Logger.info("Settings JSON: %s", settings_json)

        -- 写入临时文件避免命令行引号问题
        local settings_file = vim.fn.tempname() .. ".json"
        local f = io.open(settings_file, "w")
        if f then
          f:write(settings_json)
          f:close()
          table.insert(args, "--settings")
          table.insert(args, settings_file)
          Logger.info("Settings file: %s", settings_file)
        end
      end
    end
  end

  Logger.info("Claude args: %s", vim.inspect(args))

  -- 不使用 stdin_pipe，避免 Claude 等待输入
  local spawn_opts = {
    args = args,
    stdio = { nil, self.stdout_pipe, self.stderr_pipe },
    cwd = (context and context.cwd) or nil,
  }

  local handle, pid_or_err
  handle, pid_or_err = uv.spawn(command, spawn_opts, function(code, signal)
    -- 进程退出回调
    vim.schedule(function()
      -- 使用统一的清理方法
      self:_cleanup_process()

      if code ~= 0 then
        self:emit(Events.ERROR, {
          message = "Claude Code process exited with failure.",
          detail = self.stderr_buffer,
          exit_code = code,
        })
      end
    end)
  end)

  if not handle then
    return false, "Failed to start Claude Code process: " .. tostring(pid_or_err)
  end

  self.handle = handle

  -- 读取 stdout (流式)
  self.stdout_pipe:read_start(function(read_err, chunk)
    if read_err then
      return
    end
    if chunk then
      vim.schedule(function()
        self:process_chunk(chunk)
      end)
    end
  end)

  -- 读取 stderr
  self.stderr_pipe:read_start(function(read_err, chunk)
    if read_err then
      return
    end
    if chunk then
      self.stderr_buffer = self.stderr_buffer .. chunk
    end
  end)

  self:emit(Events.SESSION_UPDATED, {
    transport = "claude_code",
    last_request_id = self.request_id,
  })

  return true, self.request_id
end

-- 发送权限响应到 stdin
-- Note: This method is currently a placeholder. Claude Code CLI in -p mode
-- does not support interactive permission responses via stdin.
-- Permission handling should be done via:
-- 1. --permission-mode (acceptEdits, bypassPermissions)
-- 2. --allowedTools to pre-approve specific tools
-- 3. Hooks configured in .claude/settings.json
-- accepted: boolean (true = accept, false = reject)
function ClaudeCodeTransport:respond_approval(approval_id, accepted)
  if not self.stdin_pipe then
    return false, "No active process"
  end

  local pending = self.pending_approvals[approval_id]
  if not pending then
    return false, "Approval not found: " .. tostring(approval_id)
  end

  -- 构建 stream-json 格式的响应
  local decision = accepted and "accept" or "reject"
  local response = {
    type = "permission_response",
    id = approval_id,
    decision = decision,
  }

  local json_str = vim.json.encode(response) .. "\n"

  local uv = vim.uv or vim.loop
  self.stdin_pipe:write(json_str, function(err)
    if err then
      vim.schedule(function()
        self:emit(Events.ERROR, {
          message = "Failed to send permission response",
          detail = err,
        })
      end)
    end
  end)

  -- 清除 pending approval
  self.pending_approvals[approval_id] = nil

  return true
end

return ClaudeCodeTransport
