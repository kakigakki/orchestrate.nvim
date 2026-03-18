local Events = require("orchestrate.acp.events")

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

local function find_first_string(value, keys)
  if type(value) ~= "table" then
    return nil
  end

  for _, key in ipairs(keys) do
    if type(value[key]) == "string" and value[key] ~= "" then
      return value[key]
    end
  end

  return nil
end

local function collect_text(value, output)
  output = output or {}

  if type(value) == "string" then
    table.insert(output, value)
    return output
  end

  if type(value) ~= "table" then
    return output
  end

  if value.type == "text" and type(value.text) == "string" then
    table.insert(output, value.text)
    return output
  end

  local direct_text = find_first_string(value, { "text", "delta" })
  if direct_text then
    table.insert(output, direct_text)
  end

  for _, key in ipairs({ "message", "content", "content_block", "delta" }) do
    local child = value[key]
    if type(child) == "table" then
      if vim.islist(child) then
        for _, item in ipairs(child) do
          collect_text(item, output)
        end
      else
        collect_text(child, output)
      end
    end
  end

  return output
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
  self.job_id = nil
  self.request_id = nil
  self.stdout_buffer = ""
  self.stderr_buffer = {}
  self.stream_started = false
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
    self.dispatch(event_name, payload or {})
  end
end

function ClaudeCodeTransport:get_command()
  return (((self.opts or {}).transport or {}).claude_code or {}).command or "claude"
end

function ClaudeCodeTransport:get_transport_opts()
  return ((self.opts or {}).transport or {}).claude_code or {}
end

function ClaudeCodeTransport:connect()
  return self:is_available()
end

function ClaudeCodeTransport:disconnect()
  if self.job_id then
    pcall(vim.fn.jobstop, self.job_id)
    self.job_id = nil
  end
end

function ClaudeCodeTransport:is_available()
  local command = self:get_command()
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

  if self.job_id then
    local ok = pcall(vim.fn.jobstop, self.job_id)
    self.job_id = nil
    return ok
  end

  return false, "no_running_job"
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

  if transport_opts.max_turns then
    table.insert(args, "--max-turns")
    table.insert(args, tostring(transport_opts.max_turns))
  end

  if transport_opts.model then
    table.insert(args, "--model")
    table.insert(args, transport_opts.model)
  end

  return args
end

function ClaudeCodeTransport:handle_json_line(line)
  local ok, payload = pcall(decode_json, line)
  if not ok or type(payload) ~= "table" then
    self:emit(Events.ERROR, {
      message = "Claude Code returned an invalid JSON line.",
      detail = line,
    })
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
  if event_type == "system" and payload.subtype == "init" then
    return
  end

  if event_type == "result" then
    if payload.is_error then
      self:emit(Events.ERROR, {
        message = type(payload.result) == "string" and payload.result
          or "Claude Code returned an error result.",
        detail = payload,
      })
      return
    end

    if type(payload.result) == "string" and payload.result ~= "" and not self.stream_started then
      self.stream_started = true
      self:emit(Events.ASSISTANT_STREAM_START, {
        id = self.request_id,
        title = "Claude Code",
      })
      self:emit(Events.ASSISTANT_STREAM_DELTA, {
        id = self.request_id,
        delta = payload.result,
      })
    end

    self:emit(Events.ASSISTANT_STREAM_END, {
      id = self.request_id,
    })
    return
  end

  local text = table.concat(collect_text(payload), "")
  if text == "" then
    return
  end

  if not self.stream_started then
    self.stream_started = true
    self:emit(Events.ASSISTANT_STREAM_START, {
      id = self.request_id,
      title = "Claude Code",
    })
  end

  self:emit(Events.ASSISTANT_STREAM_DELTA, {
    id = self.request_id,
    delta = text,
  })
end

function ClaudeCodeTransport:handle_stdout(data)
  if not data then
    return
  end

  for _, chunk in ipairs(data) do
    if chunk ~= "" then
      self.stdout_buffer = self.stdout_buffer .. chunk .. "\n"
    end
  end

  while true do
    local newline = self.stdout_buffer:find("\n", 1, true)
    if not newline then
      break
    end

    local line = self.stdout_buffer:sub(1, newline - 1)
    self.stdout_buffer = self.stdout_buffer:sub(newline + 1)
    self:handle_json_line(line)
  end
end

function ClaudeCodeTransport:handle_stderr(data)
  if not data then
    return
  end

  for _, chunk in ipairs(data) do
    if chunk ~= "" then
      table.insert(self.stderr_buffer, chunk)
    end
  end
end

function ClaudeCodeTransport:handle_exit(code)
  self.job_id = nil

  if code == 0 then
    return
  end

  self:emit(Events.ERROR, {
    message = "Claude Code process exited with failure.",
    detail = table.concat(self.stderr_buffer, "\n"),
    exit_code = code,
  })
end

function ClaudeCodeTransport:send_message(text, context)
  local available, err = self:is_available()
  if not available then
    return false, err
  end

  if self.job_id then
    return false, "A Claude Code request is already running."
  end

  local command = self:get_command()
  local args = self:build_args(text, context or {})

  self.request_id = string.format("claude-request-%d", vim.loop.hrtime())
  self.stdout_buffer = ""
  self.stderr_buffer = {}
  self.stream_started = false

  local cmd = vim.list_extend({ command }, args)
  self.job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    cwd = (context and context.cwd) or nil,
    on_stdout = function(_, data)
      self:handle_stdout(data)
    end,
    on_stderr = function(_, data)
      self:handle_stderr(data)
    end,
    on_exit = function(_, code)
      self:handle_exit(code)
    end,
  })

  if self.job_id <= 0 then
    self.job_id = nil
    return false, "Failed to start Claude Code process."
  end

  self:emit(Events.SESSION_UPDATED, {
    transport = "claude_code",
    last_request_id = self.request_id,
  })

  return true, self.request_id
end

return ClaudeCodeTransport
