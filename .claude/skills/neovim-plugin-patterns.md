# Neovim 插件开发模式

orchestrate.nvim 开发中常用的 Neovim 插件模式和最佳实践。

## 模块模式

### 标准模块结构
```lua
local M = {}

-- 私有函数
local function internal_helper()
  -- ...
end

-- 公共 API
function M.public_function()
  internal_helper()
end

return M
```

### 类模式（使用 metatable）
```lua
local MyClass = {}
MyClass.__index = MyClass

function MyClass.new(opts)
  local self = setmetatable({}, MyClass)
  self.opts = opts or {}
  return self
end

function MyClass:method()
  -- self 可用
end

return MyClass
```

## Buffer 操作

### 创建 Scratch Buffer
```lua
local function create_scratch_buffer(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", opts.bufhidden or "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", opts.modifiable or false, { buf = bufnr })

  if opts.filetype then
    vim.api.nvim_set_option_value("filetype", opts.filetype, { buf = bufnr })
  end

  return bufnr
end
```

### 安全写入 Buffer
```lua
local function safe_set_lines(bufnr, lines)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local was_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = bufnr })

  if not was_modifiable then
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  if not was_modifiable then
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  end

  return true
end
```

## Window 操作

### 创建浮窗
```lua
local function create_float(opts)
  opts = opts or {}

  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local bufnr = vim.api.nvim_create_buf(false, true)
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = opts.border or "rounded",
  }

  local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)

  return bufnr, winnr
end
```

### 分割窗口
```lua
local function split_window(direction, size)
  local cmd = direction == "vertical" and "vsplit" or "split"
  vim.cmd(cmd)

  if size then
    if direction == "vertical" then
      vim.api.nvim_win_set_width(0, size)
    else
      vim.api.nvim_win_set_height(0, size)
    end
  end

  return vim.api.nvim_get_current_win()
end
```

## 命令注册

### 用户命令
```lua
local function register_commands()
  vim.api.nvim_create_user_command("MyCommand", function(opts)
    local args = opts.args
    local bang = opts.bang
    -- 处理命令
  end, {
    nargs = "?",  -- 0 或 1 个参数
    bang = true,  -- 支持 !
    complete = function(arg_lead, cmd_line, cursor_pos)
      return { "option1", "option2" }
    end,
    desc = "My command description",
  })
end
```

### Autocmd
```lua
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("MyPlugin", { clear = true })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = "orchestrate://input",
    callback = function(args)
      -- 处理写入
      return true  -- 阻止实际写入
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = bufnr,
    callback = function()
      -- 清理资源
    end,
  })
end
```

## 快捷键

### Buffer 本地快捷键
```lua
local function setup_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true }

  vim.keymap.set("n", "<CR>", function()
    -- 处理回车
  end, vim.tbl_extend("force", opts, { desc = "Confirm" }))

  vim.keymap.set("n", "q", function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end, vim.tbl_extend("force", opts, { desc = "Close" }))
end
```

## 异步操作

### Job 控制
```lua
local function run_command(cmd, opts)
  opts = opts or {}
  local stdout = {}
  local stderr = {}

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = opts.buffered or false,
    stderr_buffered = opts.buffered or false,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr, data)
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if opts.on_exit then
          opts.on_exit(code, stdout, stderr)
        end
      end)
    end,
  })

  return job_id
end
```

### vim.schedule 使用
```lua
-- 在异步回调中安全调用 UI API
local function async_callback(data)
  vim.schedule(function()
    -- 现在可以安全调用 nvim_buf_* 等 API
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)
  end)
end
```

## 配置管理

### 配置合并
```lua
local defaults = {
  option1 = true,
  option2 = "default",
  nested = {
    a = 1,
    b = 2,
  },
}

local function setup(opts)
  local config = vim.tbl_deep_extend("force", defaults, opts or {})
  return config
end
```

### 配置验证
```lua
local function validate_config(config)
  vim.validate({
    option1 = { config.option1, "boolean" },
    option2 = { config.option2, "string" },
    callback = { config.callback, "function", true },  -- optional
  })
end
```

## 健康检查

```lua
-- health/myplugin.lua
local M = {}

function M.check()
  vim.health.start("myplugin")

  -- 检查 Neovim 版本
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim version is supported")
  else
    vim.health.error("Neovim 0.9+ required")
  end

  -- 检查依赖
  if vim.fn.executable("external_tool") == 1 then
    vim.health.ok("external_tool found")
  else
    vim.health.warn("external_tool not found", {
      "Install with: brew install external_tool",
    })
  end
end

return M
```

## 调试技巧

### 打印调试
```lua
-- 格式化打印表
print(vim.inspect(my_table))

-- 通知
vim.notify("Debug: " .. message, vim.log.levels.DEBUG)

-- 写入日志文件
local function log(msg)
  local file = io.open(vim.fn.stdpath("cache") .. "/myplugin.log", "a")
  if file then
    file:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. msg .. "\n")
    file:close()
  end
end
```

### 性能测量
```lua
local function measure(name, fn)
  local start = vim.loop.hrtime()
  local result = fn()
  local elapsed = (vim.loop.hrtime() - start) / 1e6
  print(string.format("%s took %.2fms", name, elapsed))
  return result
end
```
