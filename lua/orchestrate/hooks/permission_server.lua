-- Permission server: 通过 Unix socket 与 hook 脚本通信
-- 当 Claude Code 请求权限时，hook 脚本会连接到这个服务器
-- Neovim 显示弹窗，用户决定后返回结果给 hook 脚本

local M = {}

local uv = vim.uv or vim.loop
local Logger = require("orchestrate.utils.logger")
local ApprovalUI = require("orchestrate.ui.approval")

-- 服务器状态
local server = nil
local socket_path = nil
local pending_requests = {}

-- 生成 socket 路径
function M.get_socket_path()
  if socket_path then
    return socket_path
  end
  local tmp = vim.fn.tempname()
  socket_path = tmp .. ".orchestrate.sock"
  return socket_path
end

-- 从 tool_input 中提取命令描述
local function extract_command_desc(tool_name, tool_input)
  if not tool_input then
    return nil
  end

  if tool_name == "Bash" then
    return tool_input.command
  elseif tool_name == "Edit" or tool_name == "Write" then
    return tool_input.file_path
  elseif tool_name == "Read" then
    return tool_input.file_path
  elseif tool_name == "Glob" or tool_name == "Grep" then
    return tool_input.pattern
  end

  -- 尝试 JSON 序列化
  local ok, str = pcall(vim.json.encode, tool_input)
  if ok then
    if #str > 60 then
      return str:sub(1, 57) .. "..."
    end
    return str
  end

  return nil
end

-- 处理来自 hook 脚本的权限请求 (PreToolUse 格式)
local function handle_permission_request(client, data)
  local ok, request = pcall(vim.json.decode, data)
  if not ok or type(request) ~= "table" then
    Logger.debug("Invalid permission request: %s", data)
    return
  end

  -- Claude Code PreToolUse 格式:
  -- {
  --   "session_id": "...",
  --   "hook_event_name": "PreToolUse",
  --   "tool_name": "Bash",
  --   "tool_input": { "command": "..." },
  --   "tool_use_id": "toolu_..."
  -- }

  local tool_name = request.tool_name
  local tool_input = request.tool_input
  local tool_use_id = request.tool_use_id
  -- 使用 tool_use_id 作为唯一标识符
  local request_id = tool_use_id or request.session_id or tostring(vim.loop.hrtime())

  Logger.info("PreToolUse request received: %s for tool %s", request_id, tool_name)

  -- 保存 pending request
  pending_requests[request_id] = {
    client = client,
    request = request,
  }

  -- 在主线程显示弹窗
  vim.schedule(function()
    Logger.info("Showing permission popup for tool: %s", tostring(tool_name))

    local command_desc = extract_command_desc(tool_name, tool_input)

    local approval = {
      id = request_id,
      title = tool_name or "Permission Required",
      description = request.description or "",
      tool_name = tool_name,
      command = command_desc,
      input = tool_input,
    }

    -- 强制刷新 UI
    vim.cmd("redraw")

    ApprovalUI.show_forced_popup(approval, function(approval_id, decision)
      Logger.info("Popup callback received: approval_id=%s, decision=%s", tostring(approval_id), tostring(decision))

      local pending = pending_requests[approval_id]
      if not pending then
        Logger.debug("No pending request for approval: %s", approval_id)
        return
      end

      -- 如果用户取消 (Esc/q)，默认为 deny
      if decision == nil then
        decision = "reject"
        Logger.info("User cancelled, treating as reject")
      end

      -- 构建响应 (Claude Code PreToolUse hook 格式)
      -- PreToolUse 使用 permissionDecision 而不是 decision.behavior
      local response = {
        hookSpecificOutput = {
          hookEventName = "PreToolUse",
          permissionDecision = decision == "accept" and "allow" or "deny",
        },
      }

      if decision ~= "accept" then
        response.hookSpecificOutput.permissionDecisionReason = "User rejected this action"
      else
        -- 传递原始输入
        response.hookSpecificOutput.updatedInput = pending.request.tool_input
      end

      local json_response = vim.json.encode(response) .. "\n"
      Logger.info("Sending response: %s", json_response:sub(1, 200))

      -- 发送响应到 hook 脚本
      if pending.client and not pending.client:is_closing() then
        pending.client:write(json_response, function(err)
          if err then
            Logger.debug("Failed to send response: %s", err)
          else
            Logger.info("Response sent successfully")
          end
          -- 关闭连接
          if not pending.client:is_closing() then
            pending.client:close()
          end
        end)
      else
        Logger.debug("Client already closed or nil")
      end

      -- 清除 pending request
      pending_requests[approval_id] = nil
      Logger.info("Permission %s: %s", approval_id, decision)
    end)
  end)
end

-- 启动服务器
function M.start()
  if server then
    return true, socket_path
  end

  local path = M.get_socket_path()

  -- 删除旧的 socket 文件
  vim.fn.delete(path)

  server = uv.new_pipe(false)
  local ok, err = server:bind(path)
  if not ok then
    Logger.debug("Failed to bind socket: %s", err)
    server:close()
    server = nil
    return false, err
  end

  server:listen(128, function(listen_err)
    if listen_err then
      Logger.debug("Listen error: %s", listen_err)
      return
    end

    local client = uv.new_pipe(false)
    server:accept(client)

    local buffer = ""
    client:read_start(function(read_err, chunk)
      if read_err then
        Logger.debug("Read error: %s", read_err)
        if not client:is_closing() then
          client:close()
        end
        return
      end

      if chunk then
        buffer = buffer .. chunk
        -- 查找完整的 JSON 行
        while true do
          local newline_pos = buffer:find("\n")
          if not newline_pos then
            break
          end
          local line = buffer:sub(1, newline_pos - 1)
          buffer = buffer:sub(newline_pos + 1)
          if line ~= "" then
            handle_permission_request(client, line)
          end
        end
      else
        -- EOF
        if not client:is_closing() then
          client:close()
        end
      end
    end)
  end)

  Logger.info("Permission server started at: %s", path)
  return true, path
end

-- 停止服务器
function M.stop()
  -- 关闭所有 pending clients
  for _, pending in pairs(pending_requests) do
    if pending.client and not pending.client:is_closing() then
      pending.client:close()
    end
  end
  pending_requests = {}

  if server then
    if not server:is_closing() then
      server:close()
    end
    server = nil
  end

  if socket_path then
    vim.fn.delete(socket_path)
    socket_path = nil
  end

  Logger.info("Permission server stopped")
end

-- 检查服务器是否运行
function M.is_running()
  return server ~= nil
end

return M
