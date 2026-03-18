# Lua 代码审查

专门针对 Neovim Lua 插件的代码审查。

## 审查维度

### 1. Neovim API 使用

#### 检查项
- [ ] 使用 `vim.api.nvim_*` 而非废弃的 `vim.fn.*` (当有对应 API 时)
- [ ] 正确处理 buffer/window 生命周期
- [ ] 使用 `vim.schedule()` 处理异步回调中的 UI 操作
- [ ] 使用 `vim.validate()` 验证函数参数
- [ ] 使用 `pcall()` 包装可能失败的操作

#### 常见问题
```lua
-- BAD: 直接在回调中操作 UI
on_data = function(data)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)  -- 可能失败
end

-- GOOD: 使用 vim.schedule
on_data = function(data)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)
    end
  end)
end
```

### 2. Lua 惯用法

#### 检查项
- [ ] 使用 `local` 声明所有变量
- [ ] 模块使用 `local M = {}; return M` 模式
- [ ] 使用 `vim.tbl_*` 函数处理表操作
- [ ] 使用 `vim.deepcopy()` 复制表
- [ ] 字符串拼接使用 `table.concat()` 而非 `..` 循环

#### 常见问题
```lua
-- BAD: 循环中拼接字符串
local result = ""
for _, v in ipairs(items) do
  result = result .. v .. "\n"  -- 性能差
end

-- GOOD: 使用 table.concat
local parts = {}
for _, v in ipairs(items) do
  table.insert(parts, v)
end
local result = table.concat(parts, "\n")
```

### 3. 错误处理

#### 检查项
- [ ] 外部 API 调用使用 `pcall()`
- [ ] 文件操作检查返回值
- [ ] JSON 解析使用 `pcall(vim.json.decode, ...)`
- [ ] 提供有意义的错误消息

#### 常见问题
```lua
-- BAD: 不处理解析错误
local data = vim.json.decode(line)

-- GOOD: 安全解析
local ok, data = pcall(vim.json.decode, line)
if not ok then
  vim.notify("JSON parse error: " .. tostring(data), vim.log.levels.ERROR)
  return
end
```

### 4. 性能

#### 检查项
- [ ] 避免在循环中调用 Neovim API
- [ ] 大列表使用批量 API (`nvim_buf_set_lines` vs 多次 `nvim_buf_set_text`)
- [ ] 使用 `vim.loop` 进行文件 IO
- [ ] 延迟加载不常用的模块

#### 常见问题
```lua
-- BAD: 循环中多次调用 API
for i, line in ipairs(lines) do
  vim.api.nvim_buf_set_lines(bufnr, i-1, i, false, { line })
end

-- GOOD: 一次性设置
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
```

### 5. orchestrate.nvim 架构

#### 检查项
- [ ] 遵循 ACP → Store → Renderer → UI 数据流
- [ ] Transport 不直接访问 UI
- [ ] Actions 通过 store:update() 修改状态
- [ ] Renderer 是纯函数
- [ ] 使用 Events 常量而非字符串字面量

### 6. 代码风格

#### 检查项
- [ ] 2 空格缩进 (StyLua)
- [ ] 函数命名使用 `snake_case`
- [ ] 私有函数以 `_` 开头
- [ ] 有意义的变量名
- [ ] 适当的注释（解释 why，不是 what）

## 审查输出格式

```markdown
## 代码审查结果

### 严重问题 (必须修复)
1. **[文件:行号]** 问题描述
   - 原因: ...
   - 建议: ...

### 建议改进
1. **[文件:行号]** 改进建议
   - 当前: ...
   - 建议: ...

### 正面反馈
- 良好的模块化设计
- 错误处理完善
- ...
```
