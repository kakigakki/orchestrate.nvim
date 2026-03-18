package.path = table.concat({
  "./lua/?.lua",
  "./lua/?/init.lua",
  package.path,
}, ";")

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(
      (message or "assert_equal failed")
        .. string.format(" (expected=%s, actual=%s)", vim.inspect(expected), vim.inspect(actual))
    )
  end
end

local function assert_truthy(value, message)
  if not value then
    error(message or "assert_truthy failed")
  end
end

local function assert_falsy(value, message)
  if value then
    error(message or "assert_falsy failed")
  end
end

local Store = require("orchestrate.core.store")
local Actions = require("orchestrate.core.actions")
local Registry = require("orchestrate.acp.registry")
local Builtins = require("orchestrate.acp.builtins")
local Config = require("orchestrate.config")
local Orchestrate = require("orchestrate")

print("Running orchestrate.nvim tests...")

-- Setup
Builtins.register_all()
Config.setup({})
Orchestrate.setup({
  transport = {
    name = "mock",
  },
})
-- Test idempotent setup
Orchestrate.setup({
  transport = {
    name = "mock",
  },
})

-- Test commands exist
print("  Testing commands...")
assert_truthy(vim.fn.exists(":OrchestrateSend") == 2, "OrchestrateSend command should exist")
assert_truthy(vim.fn.exists(":OrchestrateResume") == 2, "OrchestrateResume command should exist")
assert_truthy(
  vim.fn.exists(":OrchestrateContinue") == 2,
  "OrchestrateContinue command should exist"
)
assert_truthy(vim.fn.exists(":OrchestrateApprove") == 2, "OrchestrateApprove command should exist")
assert_truthy(vim.fn.exists(":OrchestrateReject") == 2, "OrchestrateReject command should exist")
assert_truthy(
  vim.fn.exists(":OrchestrateReviewJump") == 2,
  "OrchestrateReviewJump command should exist"
)
assert_truthy(
  vim.fn.exists(":OrchestrateReviewQuickfix") == 2,
  "OrchestrateReviewQuickfix command should exist"
)
assert_truthy(vim.fn.exists(":OrchestrateRetry") == 2, "OrchestrateRetry command should exist")
assert_truthy(vim.fn.exists(":OrchestrateToggle") == 2, "OrchestrateToggle command should exist")
print("  Commands: OK")

-- Test Store
print("  Testing Store...")
local store = Store.new()
local observed = {}
store:subscribe(function(session)
  table.insert(observed, session.status)
end)

assert_equal(store:get_state().status, "idle", "initial status should be idle")
assert_truthy(store:get_state().resolved_approvals ~= nil, "resolved_approvals should exist")

Actions.submit_prompt(store, "hello")
assert_equal(store:get_state().status, "connecting", "submit_prompt should enter connecting")
assert_equal(#store:get_state().messages, 1, "should have one message")

Actions.stream_start(store, { id = "assistant-1" })
assert_equal(store:get_state().status, "streaming", "stream_start should enter streaming")

Actions.stream_delta(store, { id = "assistant-1", delta = "world" })
local messages = store:get_state().messages
assert_equal(messages[2].content, "world", "stream_delta should append content")

Actions.stream_end(store)
assert_equal(store:get_state().status, "idle", "stream_end should return to idle")
print("  Store: OK")

-- Test Approval actions
print("  Testing Approval actions...")
local store2 = Store.new()

Actions.add_approval(store2, {
  id = "approval-1",
  title = "Test approval",
  description = "Please approve this",
})
assert_equal(
  store2:get_state().status,
  "waiting_approval",
  "add_approval should enter waiting_approval"
)
assert_equal(#store2:get_state().approvals, 1, "should have one approval")

Actions.resolve_approval(store2, "approval-1", "accept")
assert_equal(#store2:get_state().approvals, 0, "resolved approval should be removed")
assert_equal(
  #store2:get_state().resolved_approvals,
  1,
  "resolved approval should be in resolved list"
)
assert_equal(
  store2:get_state().resolved_approvals[1].decision,
  "accept",
  "decision should be accept"
)
assert_equal(store2:get_state().status, "idle", "status should return to idle after approval")
print("  Approval actions: OK")

-- Test Review actions
print("  Testing Review actions...")
local store3 = Store.new()

Actions.add_review(store3, {
  id = "review-1",
  title = "Test review",
  file = "test.lua",
  line = 10,
  severity = "warning",
})
assert_equal(store3:get_state().status, "reviewing", "add_review should enter reviewing")
assert_equal(#store3:get_state().reviews, 1, "should have one review")
assert_falsy(store3:get_state().reviews[1].seen, "review should not be seen initially")

Actions.mark_review_seen(store3, "review-1")
assert_truthy(store3:get_state().reviews[1].seen, "review should be marked as seen")
assert_equal(
  store3:get_state().status,
  "idle",
  "status should return to idle after all reviews seen"
)

-- Test mark_all_reviews_seen
local store4 = Store.new()
Actions.add_review(store4, { id = "r1", title = "Review 1" })
Actions.add_review(store4, { id = "r2", title = "Review 2" })
Actions.mark_all_reviews_seen(store4)
assert_truthy(store4:get_state().reviews[1].seen, "first review should be seen")
assert_truthy(store4:get_state().reviews[2].seen, "second review should be seen")
print("  Review actions: OK")

-- Test Error actions
print("  Testing Error actions...")
local store5 = Store.new()

Actions.set_error(store5, { message = "test error" })
assert_equal(store5:get_state().status, "error", "set_error should enter error status")
assert_equal(
  store5:get_state().meta.last_error.message,
  "test error",
  "error message should be stored"
)

Actions.retry_last(store5)
assert_equal(store5:get_state().status, "idle", "retry_last should reset to idle")
assert_equal(store5:get_state().meta.last_error, nil, "retry_last should clear error")
print("  Error actions: OK")

-- Test transport meta
print("  Testing transport meta...")
local store6 = Store.new()
Actions.set_transport_meta(store6, {
  transport = "claude_code",
  transport_session_id = "session-1",
})
assert_equal(
  store6:get_state().meta.transport_session_id,
  "session-1",
  "transport_session_id should be stored"
)
print("  Transport meta: OK")

-- Test subscriptions
assert_truthy(#observed > 0, "store subscription should receive updates")
print("  Subscriptions: OK")

-- Test Registry
print("  Testing Registry...")
assert_truthy(Registry.has("mock"), "mock transport should be registered")
assert_truthy(Registry.has("claude_code"), "claude_code transport should be registered")
print("  Registry: OK")

-- Test Mock transport
print("  Testing Mock transport...")
local mock = Registry.create("mock", Config.get())
local mock_messages = {}
mock:set_dispatch(function(event_name, payload)
  table.insert(mock_messages, { event = event_name, payload = payload })
end)

local ok_send, request_id = mock:send_message("test", {})
assert_truthy(ok_send, "mock transport should send successfully")
assert_truthy(type(request_id) == "string", "mock transport should return request_id")

vim.wait(2500, function()
  return #mock_messages > 0
end, 50)

assert_truthy(#mock_messages > 0, "mock transport should emit events")
print("  Mock transport: OK")

-- Test Logger module loads
print("  Testing Logger module...")
local Logger = require("orchestrate.utils.logger")
assert_truthy(Logger.setup ~= nil, "Logger.setup should exist")
assert_truthy(Logger.debug ~= nil, "Logger.debug should exist")
assert_truthy(Logger.info ~= nil, "Logger.info should exist")
Logger.setup({ enabled = false })
assert_falsy(Logger.is_enabled(), "Logger should be disabled")

-- Test sensitive data sanitization
assert_truthy(Logger.sanitize ~= nil, "Logger.sanitize should exist")
local sanitized = Logger.sanitize("api_key=sk-abc123 token=xyz password=secret123")
assert_truthy(
  not sanitized:find("sk%-abc123"),
  "API key should be redacted"
)
assert_truthy(
  not sanitized:find("secret123"),
  "Password should be redacted"
)
print("  Logger: OK")

print("")
print("All tests passed!")
