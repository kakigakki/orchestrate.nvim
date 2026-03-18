# 架构检查

检查代码变更是否符合 orchestrate.nvim 的架构原则。

## 输入参数

$ARGUMENTS = 要检查的文件或目录 (例如: lua/orchestrate/acp, 或留空检查全部)

## 核心架构原则

```
ACP (Transport) → Store (State) → Renderer → Neovim UI
```

1. **单向数据流** - 数据只能从左向右流动
2. **Transport 隔离** - Transport 不直接访问 UI
3. **状态集中** - 所有状态变更通过 Actions
4. **Renderer 纯函数** - Renderer 只读取状态，不修改状态
5. **UI 无业务逻辑** - UI 层只处理 Neovim API 调用

## 检查清单

### Transport 层 (`acp/`)
- [ ] Transport 不 require 任何 `ui/` 或 `renderers/` 模块
- [ ] Transport 只通过 `self:emit(event, payload)` 发送事件
- [ ] Transport 不直接调用 `vim.api.nvim_buf_*` 或 `vim.api.nvim_win_*`
- [ ] Transport 不直接修改 Store 状态

### Store/Actions 层 (`core/`)
- [ ] Actions 通过 `store:update(reducer)` 修改状态
- [ ] Actions 不 require 任何 `ui/` 或 `renderers/` 模块
- [ ] Actions 不调用 Neovim UI API
- [ ] Store 的 reducer 是纯函数（无副作用）

### Renderer 层 (`renderers/`)
- [ ] Renderer 只导出 `render(bufnr, state)` 函数
- [ ] Renderer 不调用 Actions 或修改 Store
- [ ] Renderer 不处理用户输入（快捷键）
- [ ] Renderer 只使用 `vim.api.nvim_buf_*` 写入内容

### UI 层 (`ui/`)
- [ ] UI 只处理窗口/缓冲区的创建和布局
- [ ] UI 不包含业务逻辑（状态转换、事件处理）
- [ ] 快捷键绑定调用 Actions，不直接修改状态

### Setup/Commands 层
- [ ] 作为粘合层，连接各个模块
- [ ] 订阅 Store 变化，调用 Renderer
- [ ] 处理用户命令，调用 Actions
- [ ] 管理 Transport 生命周期

## 违规模式示例

### 违规：Transport 直接写 buffer
```lua
-- BAD: Transport 直接操作 UI
function Transport:send_message(text)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Loading..." })  -- 违规!
end
```

### 违规：Renderer 修改状态
```lua
-- BAD: Renderer 中修改状态
function M.render(bufnr, state)
  state.rendered = true  -- 违规!
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end
```

### 违规：Action 调用 UI
```lua
-- BAD: Action 直接操作 UI
function Actions.submit_prompt(store, text)
  store:update(function(state)
    state.status = "connecting"
    return state
  end)
  vim.notify("Submitting...")  -- 违规!
end
```

### 违规：UI 包含业务逻辑
```lua
-- BAD: UI 层处理业务逻辑
function M.create_input_buffer()
  vim.keymap.set("n", "<CR>", function()
    local text = get_buffer_content()
    if text == "" then return end  -- 业务逻辑应该在 Action 中
    if #text > 10000 then return end  -- 业务逻辑应该在 Action 中
    Actions.submit_prompt(store, text)
  end)
end
```

## 正确模式示例

### 正确：Transport 发出事件
```lua
-- GOOD: Transport 只发出事件
function Transport:send_message(text)
  self:emit(Events.ASSISTANT_STREAM_START, { id = request_id })
  -- ...处理响应...
  self:emit(Events.ASSISTANT_STREAM_DELTA, { id = request_id, delta = chunk })
end
```

### 正确：Setup 层作为粘合剂
```lua
-- GOOD: Setup 层连接各模块
local function on_event(event_name, payload)
  if event_name == Events.ASSISTANT_STREAM_START then
    Actions.stream_start(store, payload)
  end
end

store:subscribe(function(state)
  BrowseRenderer.render(buffers.browse, state)
  TodoRenderer.render(buffers.todo, state)
end)

transport:set_dispatch(on_event)
```

## 执行检查

1. 使用 Grep 搜索违规模式
2. 检查模块间的 require 依赖
3. 验证数据流方向
4. 报告发现的问题和修复建议
