# 添加新 Renderer

为 orchestrate.nvim 创建一个新的缓冲区渲染器。

## 输入参数

$ARGUMENTS = Renderer 名称和用途 (例如: "context - 显示上下文列表")

## 任务

1. 在 `lua/orchestrate/renderers/` 下创建新的 renderer 文件
2. 实现 `render(bufnr, state)` 函数
3. 在 `lua/orchestrate/ui/buffers.lua` 中添加 buffer 创建逻辑
4. 在 `lua/orchestrate/ui/layout.lua` 中添加窗口布局
5. 在 `lua/orchestrate/setup.lua` 中订阅状态变化并调用渲染

## 必须遵守的架构原则

- Renderer 是纯函数，只负责把 state 渲染到 buffer
- 不在 renderer 中修改状态
- 不在 renderer 中处理用户输入（快捷键在 UI 层处理）
- 通过 `vim.api.nvim_buf_set_lines()` 写入内容

## Renderer 模板

```lua
-- lua/orchestrate/renderers/my_renderer.lua

local M = {}

local function format_item(item)
  -- 格式化单个项目
  return string.format("- %s", item.title or "Untitled")
end

local function build_lines(state)
  local lines = {}

  -- 添加标题
  table.insert(lines, "# My Panel")
  table.insert(lines, "")

  -- 渲染内容
  if #state.my_items == 0 then
    table.insert(lines, "(empty)")
  else
    for _, item in ipairs(state.my_items) do
      table.insert(lines, format_item(item))
    end
  end

  return lines
end

function M.render(bufnr, state)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = build_lines(state)

  -- 设置 buffer 为可修改
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  -- 写入内容
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- 设置 buffer 为只读（如果需要）
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

return M
```

## Buffer 创建模板

```lua
-- 在 lua/orchestrate/ui/buffers.lua 中添加

function M.create_my_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "orchestrate-my-panel", { buf = bufnr })

  return bufnr
end
```

## 订阅状态变化

```lua
-- 在 lua/orchestrate/setup.lua 中添加

local MyRenderer = require("orchestrate.renderers.my_renderer")

-- 在 open() 函数中
store:subscribe(function(state)
  MyRenderer.render(buffers.my_buffer, state)
end)
```

## 常见渲染模式

### 带状态图标
```lua
local status_icons = {
  pending = "[ ]",
  in_progress = "[*]",
  completed = "[x]",
}

local function format_todo(todo)
  local icon = status_icons[todo.status] or "[ ]"
  return string.format("%s %s", icon, todo.content)
end
```

### 带时间戳
```lua
local function format_message(msg)
  return string.format("[%s] %s: %s", msg.created_at, msg.role, msg.content)
end
```

### 带高亮（通过 extmarks）
```lua
function M.render(bufnr, state)
  -- ... 写入 lines ...

  -- 添加高亮
  local ns_id = vim.api.nvim_create_namespace("orchestrate-my-panel")
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  for i, item in ipairs(state.items) do
    if item.important then
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "WarningMsg", i - 1, 0, -1)
    end
  end
end
```

## 参考

- Browse renderer: `lua/orchestrate/renderers/browse.lua`
- Todo renderer: `lua/orchestrate/renderers/todo.lua`
- Input renderer: `lua/orchestrate/renderers/input.lua`
