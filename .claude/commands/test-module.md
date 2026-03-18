# 测试模块

为指定的 orchestrate.nvim 模块运行或编写测试。

## 输入参数

$ARGUMENTS = 模块路径 (例如: core/actions, acp/transports/mock, renderers/browse)

## 任务

1. 阅读指定模块的代码
2. 检查 `tests/run.lua` 中是否已有该模块的测试
3. 如果缺少测试，添加完整的测试覆盖
4. 运行测试并报告结果

## 运行测试命令

```bash
nvim --headless --clean -u NONE \
  +"set rtp+=." \
  +"luafile tests/run.lua" \
  +q
```

## 测试框架

项目使用简单的断言函数：

```lua
local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_equal failed") ..
      string.format(" (expected=%s, actual=%s)",
        vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_truthy(value, message)
  if not value then
    error(message or "assert_truthy failed")
  end
end
```

## 测试模式

### Store 测试
```lua
local Store = require("orchestrate.core.store")

local store = Store.new()
local observed = {}
store:subscribe(function(state)
  table.insert(observed, state.status)
end)

-- 测试状态更新
store:update(function(state)
  state.status = "streaming"
  return state
end)

assert_equal(store:get_state().status, "streaming", "status should be streaming")
assert_truthy(#observed > 0, "subscriber should be called")
```

### Actions 测试
```lua
local Store = require("orchestrate.core.store")
local Actions = require("orchestrate.core.actions")

local store = Store.new()

Actions.submit_prompt(store, "hello")
assert_equal(store:get_state().status, "connecting")
assert_equal(#store:get_state().messages, 1)
assert_equal(store:get_state().messages[1].content, "hello")
```

### Transport 测试
```lua
local Registry = require("orchestrate.acp.registry")
local Config = require("orchestrate.config")

local transport = Registry.create("mock", Config.get())
local events = {}

transport:set_dispatch(function(event_name, payload)
  table.insert(events, { event = event_name, payload = payload })
end)

local ok, request_id = transport:send_message("test", {})
assert_truthy(ok, "send should succeed")
assert_truthy(type(request_id) == "string", "should return request_id")

-- 等待异步事件
vim.wait(2000, function()
  return #events > 0
end, 50)

assert_truthy(#events > 0, "should emit events")
```

### Renderer 测试（快照测试）
```lua
local BrowseRenderer = require("orchestrate.renderers.browse")

local bufnr = vim.api.nvim_create_buf(false, true)
local state = {
  status = "idle",
  messages = {
    { id = "1", kind = "user_submit", role = "user", content = "hello", created_at = "12:00:00" },
  },
  todos = {},
  approvals = {},
  reviews = {},
  meta = {},
}

BrowseRenderer.render(bufnr, state)

local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_truthy(#lines > 0, "should render lines")
assert_truthy(vim.tbl_contains(lines, "hello") or
  table.concat(lines, "\n"):find("hello"), "should contain message content")

vim.api.nvim_buf_delete(bufnr, { force = true })
```

## 覆盖率检查清单

### core/store.lua
- [ ] Store.new() 创建初始状态
- [ ] get_state() 返回状态副本
- [ ] subscribe() 注册订阅者
- [ ] subscribe() 返回的取消函数能工作
- [ ] set_state() 通知所有订阅者
- [ ] update() 正确应用 reducer

### core/actions.lua
- [ ] submit_prompt() 添加用户消息
- [ ] stream_start() 开始流式响应
- [ ] stream_delta() 追加内容
- [ ] stream_end() 结束流式响应
- [ ] update_todos() 更新任务列表
- [ ] add_approval() 添加审批
- [ ] add_review() 添加审查
- [ ] set_draft() 保存草稿
- [ ] set_error() 设置错误状态
- [ ] set_transport_meta() 更新传输元数据

### acp/transports/mock.lua
- [ ] is_available() 返回 true
- [ ] healthcheck() 返回正常状态
- [ ] send_message() 发送消息并发出事件
- [ ] cancel() 能取消请求

### acp/transports/claude_code.lua
- [ ] is_available() 检查 claude 命令
- [ ] healthcheck() 检查认证
- [ ] build_args() 正确构建参数
- [ ] handle_json_line() 正确解析 JSON
