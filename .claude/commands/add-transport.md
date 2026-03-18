# 添加新 Transport

为 orchestrate.nvim 创建一个新的 ACP Transport 实现。

## 输入参数

$ARGUMENTS = Transport 名称 (例如: openai, ollama, copilot)

## 任务

1. 在 `lua/orchestrate/acp/transports/` 下创建新的 transport 文件
2. 实现标准 Transport 接口:
   - `new(opts)` - 构造函数
   - `set_opts(opts)` - 设置配置
   - `set_dispatch(dispatch)` - 设置事件分发器
   - `connect()` - 连接
   - `disconnect()` - 断开
   - `is_available()` - 检查可用性
   - `healthcheck()` - 健康检查
   - `send_message(text, context)` - 发送消息
   - `cancel(request_id)` - 取消请求
3. 在 `lua/orchestrate/acp/builtins.lua` 中注册新 transport
4. 在 `lua/orchestrate/config.lua` 中添加默认配置
5. 更新 `health/orchestrate.lua` 支持新 transport 的检查

## 必须遵守的架构原则

- Transport 只产出标准事件，不直接访问 UI
- 使用 `self:emit(Events.XXX, payload)` 发送事件
- 支持的事件类型见 `lua/orchestrate/acp/events.lua`

## Transport 模板

```lua
local Events = require("orchestrate.acp.events")

local MyTransport = {}
MyTransport.__index = MyTransport

function MyTransport.new(opts)
  local self = setmetatable({}, MyTransport)
  self.dispatch = nil
  self.opts = opts or {}
  return self
end

function MyTransport:set_opts(opts)
  self.opts = opts or {}
end

function MyTransport:set_dispatch(dispatch)
  self.dispatch = dispatch
end

function MyTransport:emit(event_name, payload)
  if self.dispatch then
    self.dispatch(event_name, payload or {})
  end
end

function MyTransport:connect()
  return self:is_available()
end

function MyTransport:disconnect()
  -- 清理资源
end

function MyTransport:is_available()
  -- 检查依赖是否可用
  return true
end

function MyTransport:healthcheck()
  local available, err = self:is_available()
  if not available then
    return { ok = false, message = err }
  end
  return { ok = true, message = "Transport is available" }
end

function MyTransport:cancel(request_id)
  -- 取消正在进行的请求
  return false, "not_implemented"
end

function MyTransport:send_message(text, context)
  -- 1. 发送请求
  -- 2. 处理流式响应
  -- 3. 发出对应事件:
  --    self:emit(Events.ASSISTANT_STREAM_START, { id = request_id, title = "..." })
  --    self:emit(Events.ASSISTANT_STREAM_DELTA, { id = request_id, delta = "..." })
  --    self:emit(Events.ASSISTANT_STREAM_END, { id = request_id })
  --    self:emit(Events.SESSION_UPDATED, { transport = "my_transport", ... })
  --    self:emit(Events.ERROR, { message = "..." })
  return true, request_id
end

return MyTransport
```

## 参考实现

- `lua/orchestrate/acp/transports/claude_code.lua` - 完整的 CLI 集成示例
- `lua/orchestrate/acp/transports/mock.lua` - 简单的模拟实现
