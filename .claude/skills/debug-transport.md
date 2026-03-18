# 调试 Transport

帮助调试 orchestrate.nvim 的 Transport 问题。

## 常见问题排查

### 1. Transport 不可用

#### 检查步骤
```bash
# 检查 claude CLI 是否安装
which claude
claude --version

# 检查认证
ls -la ~/.config/claude-code/auth.json
echo $ANTHROPIC_API_KEY
```

#### Neovim 内检查
```lua
:lua print(vim.fn.executable("claude"))
:lua print(vim.env.ANTHROPIC_API_KEY and "API key set" or "No API key")
:checkhealth orchestrate
```

### 2. 消息发送失败

#### 检查步骤
```lua
-- 获取当前 session 状态
:lua print(vim.inspect(require("orchestrate").get_session()))

-- 检查状态
:lua print(require("orchestrate").get_session().status)
:lua print(require("orchestrate").get_session().meta.last_error)
```

#### 常见原因
- Transport 未连接
- 已有请求正在进行
- 认证过期
- 网络问题

### 3. 流式响应中断

#### 检查 Job 状态
```lua
-- 在 transport 中添加调试日志
function Transport:handle_exit(code)
  vim.notify(string.format("Job exited with code: %d", code))
  if #self.stderr_buffer > 0 then
    vim.notify("stderr: " .. table.concat(self.stderr_buffer, "\n"))
  end
end
```

#### 常见原因
- Claude CLI 崩溃
- Token 限制
- 网络超时

### 4. JSON 解析错误

#### 调试方法
```lua
-- 打印原始输出
function Transport:handle_json_line(line)
  print("Raw line: " .. line)
  local ok, data = pcall(vim.json.decode, line)
  if not ok then
    print("Parse error: " .. tostring(data))
  end
end
```

### 5. 事件未触发

#### 检查事件分发
```lua
-- 添加事件日志
local original_dispatch = transport.dispatch
transport:set_dispatch(function(event, payload)
  print(string.format("Event: %s", event))
  print(vim.inspect(payload))
  if original_dispatch then
    original_dispatch(event, payload)
  end
end)
```

## 手动测试 Transport

### 测试 Mock Transport
```lua
:lua <<EOF
local Registry = require("orchestrate.acp.registry")
local Config = require("orchestrate.config")
local Builtins = require("orchestrate.acp.builtins")

Builtins.register_all()

local transport = Registry.create("mock", Config.get())
transport:set_dispatch(function(event, payload)
  print(event, vim.inspect(payload))
end)

transport:send_message("test", {})
EOF
```

### 测试 Claude Code Transport
```lua
:lua <<EOF
local Registry = require("orchestrate.acp.registry")
local Config = require("orchestrate.config")
local Builtins = require("orchestrate.acp.builtins")

Builtins.register_all()

local transport = Registry.create("claude_code", Config.get())

-- 检查可用性
local ok, err = transport:is_available()
print("Available:", ok, err)

-- 检查健康状态
local health = transport:healthcheck()
print("Health:", vim.inspect(health))
EOF
```

### 手动发送消息
```lua
:lua <<EOF
local transport = require("orchestrate.acp.transports.claude_code").new({})

transport:set_dispatch(function(event, payload)
  vim.schedule(function()
    print(string.format("[%s] %s", event, vim.inspect(payload):sub(1, 100)))
  end)
end)

local ok, request_id = transport:send_message("Say hello", {})
print("Sent:", ok, request_id)
EOF
```

## 日志收集

### 启用调试模式
```lua
require("orchestrate").setup({
  debug = {
    enabled = true,
    log_level = "debug",
  },
})
```

### 收集诊断信息
```lua
:lua <<EOF
local info = {
  neovim_version = vim.version(),
  plugin_loaded = pcall(require, "orchestrate"),
  config = require("orchestrate.config").get(),
  session = require("orchestrate").get_session(),
  claude_available = vim.fn.executable("claude") == 1,
  api_key_set = vim.env.ANTHROPIC_API_KEY ~= nil,
}
print(vim.inspect(info))
EOF
```

## 问题报告模板

```markdown
## 环境
- Neovim 版本: `nvim --version`
- 操作系统:
- Claude CLI 版本: `claude --version`

## 问题描述
[描述问题]

## 复现步骤
1.
2.
3.

## 期望行为
[期望发生什么]

## 实际行为
[实际发生什么]

## 诊断信息
```lua
-- :lua 输出
```

## 错误信息
```
[粘贴错误信息]
```
```
