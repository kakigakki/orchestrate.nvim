local Events = require("orchestrate.acp.events")

local MockTransport = {}
MockTransport.__index = MockTransport

local function build_mock_reply(prompt)
  return {
    "Mock transport received your request.",
    "",
    "This transport is intended for local development and tests.",
    "",
    "Suggested next steps:",
    "1. Check the Browse buffer for streaming output.",
    "2. Use the Todo buffer to confirm store-driven updates.",
    "3. Switch to Claude Code transport for real ACP traffic.",
    "",
    "Prompt summary:",
    prompt,
  }
end

local function build_mock_todos(prompt)
  return {
    { title = "Parse user goal", status = "done", detail = "Input was captured successfully" },
    { title = "Generate response", status = "doing", detail = "Streaming mock output" },
    {
      title = "Wait for next step",
      status = "todo",
      detail = vim.trim(prompt) ~= "" and "Ready for follow-up work" or "Waiting for more input",
    },
  }
end

function MockTransport.new(opts)
  local self = setmetatable({}, MockTransport)
  self:set_opts(opts)
  self.dispatch = nil
  self.current_request_id = nil
  self.cancelled = false
  return self
end

function MockTransport:set_opts(opts)
  self.opts = opts or {}
end

function MockTransport:set_dispatch(dispatch)
  self.dispatch = dispatch
end

function MockTransport:emit(event_name, payload)
  if self.dispatch then
    self.dispatch(event_name, payload or {})
  end
end

function MockTransport:connect()
  return true
end

function MockTransport:disconnect()
  self.cancelled = true
end

function MockTransport:is_available()
  return true
end

function MockTransport:healthcheck()
  return {
    ok = true,
    message = "mock transport is available",
  }
end

function MockTransport:cancel(request_id)
  if request_id and self.current_request_id ~= request_id then
    return false, "request_not_found"
  end

  self.cancelled = true
  return true
end

function MockTransport:send_message(text, context)
  local request_id = string.format("mock-request-%d", vim.loop.hrtime())
  local session_id = (context and context.transport_session_id)
    or string.format("mock-session-%d", vim.loop.hrtime())
  local reply_chunks = build_mock_reply(text)
  local chunk_delay = ((self.opts or {}).mock or {}).chunk_delay or 160

  self.current_request_id = request_id
  self.cancelled = false

  self:emit(Events.ASSISTANT_STREAM_START, {
    id = request_id,
    title = "Mock Orchestrator",
  })

  for index, chunk in ipairs(reply_chunks) do
    vim.defer_fn(function()
      if self.cancelled or self.current_request_id ~= request_id then
        return
      end

      self:emit(Events.ASSISTANT_STREAM_DELTA, {
        id = request_id,
        delta = chunk .. "\n",
      })

      if index == math.ceil(#reply_chunks / 2) then
        self:emit(Events.TODO_UPDATED, build_mock_todos(text))
      end

      if index == #reply_chunks then
        self:emit(Events.SESSION_UPDATED, {
          transport = "mock",
          transport_session_id = session_id,
          last_request_id = request_id,
        })
        self:emit(Events.ASSISTANT_STREAM_END, {
          id = request_id,
        })
      end
    end, index * chunk_delay)
  end

  return true, request_id
end

return MockTransport
