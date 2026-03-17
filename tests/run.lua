package.path = table.concat({
  "./lua/?.lua",
  "./lua/?/init.lua",
  package.path,
}, ";")

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_equal failed") .. string.format(" (expected=%s, actual=%s)", vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_truthy(value, message)
  if not value then
    error(message or "assert_truthy failed")
  end
end

local Store = require("orchestrate.core.store")
local Actions = require("orchestrate.core.actions")
local Registry = require("orchestrate.acp.registry")
local Builtins = require("orchestrate.acp.builtins")
local Config = require("orchestrate.config")
local Orchestrate = require("orchestrate")

Builtins.register_all()
Config.setup({})
Orchestrate.setup({
  transport = {
    name = "mock",
  },
})
Orchestrate.setup({
  transport = {
    name = "mock",
  },
})

assert_truthy(vim.fn.exists(":OrchestrateSend") == 2, "OrchestrateSend command should exist")
assert_truthy(vim.fn.exists(":OrchestrateResume") == 2, "OrchestrateResume command should exist")
assert_truthy(vim.fn.exists(":OrchestrateContinue") == 2, "OrchestrateContinue command should exist")

local store = Store.new()
local observed = {}
store:subscribe(function(session)
  table.insert(observed, session.status)
end)

Actions.submit_prompt(store, "hello")
assert_equal(store:get_state().status, "connecting", "submit_prompt should enter connecting")

Actions.stream_start(store, { id = "assistant-1" })
Actions.stream_delta(store, { id = "assistant-1", delta = "world" })
Actions.stream_end(store)
assert_equal(store:get_state().status, "idle", "stream_end should return to idle")

Actions.set_transport_meta(store, {
  transport = "claude_code",
  transport_session_id = "session-1",
})
assert_equal(store:get_state().meta.transport_session_id, "session-1", "transport_session_id should be stored")

Actions.set_error(store, {
  message = "boom",
})
assert_equal(store:get_state().status, "error", "set_error should enter error")
assert_equal(store:get_state().meta.last_error.message, "boom", "error message should be stored")
assert_truthy(#observed > 0, "store subscription should receive updates")

assert_truthy(Registry.has("mock"), "mock transport should be registered")
assert_truthy(Registry.has("claude_code"), "claude_code transport should be registered")

local mock = Registry.create("mock", Config.get())
local messages = {}
mock:set_dispatch(function(event_name, payload)
  table.insert(messages, { event = event_name, payload = payload })
end)

local ok_send, request_id = mock:send_message("test", {})
assert_truthy(ok_send, "mock transport should send successfully")
assert_truthy(type(request_id) == "string", "mock transport should return request_id")

vim.wait(2500, function()
  return #messages > 0
end, 50)

assert_truthy(#messages > 0, "mock transport should emit events")

print("tests passed")
