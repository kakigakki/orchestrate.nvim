local Config = require("orchestrate.config")

local Layout = {}

-- 高亮组定义
local function setup_highlights()
  -- 活动窗口边框颜色 (亮色)
  vim.api.nvim_set_hl(0, "OrchestrateActiveBorder", { link = "DiagnosticInfo" })
  -- 非活动窗口边框颜色 (暗色)
  vim.api.nvim_set_hl(0, "OrchestrateInactiveBorder", { link = "FloatBorder" })
end

local function create_float_win(bufnr, row, col, width, height, opts)
  opts = opts or {}
  local win_opts = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = opts.border or "rounded",
    title = opts.title,
    title_pos = opts.title and "center" or nil,
  }
  local win = vim.api.nvim_open_win(bufnr, false, win_opts)

  vim.api.nvim_set_option_value("winhl", "Normal:NormalFloat,FloatBorder:OrchestrateInactiveBorder", { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  return win
end

-- 更新窗口边框高亮
local function update_border_highlight(windows)
  local current_win = vim.api.nvim_get_current_win()

  for _, win in pairs(windows) do
    if vim.api.nvim_win_is_valid(win) then
      if win == current_win then
        vim.api.nvim_set_option_value(
          "winhl",
          "Normal:NormalFloat,FloatBorder:OrchestrateActiveBorder",
          { win = win }
        )
      else
        vim.api.nvim_set_option_value(
          "winhl",
          "Normal:NormalFloat,FloatBorder:OrchestrateInactiveBorder",
          { win = win }
        )
      end
    end
  end
end

function Layout.open(buffers)
  setup_highlights()

  local options = Config.get()
  local layout = options.layout or {}

  -- 计算浮窗尺寸 (占屏幕 90% x 90%)
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines - vim.o.cmdheight - 1

  local float_width = layout.width or math.floor(screen_width * 0.9)
  local float_height = layout.height or math.floor(screen_height * 0.9)

  -- 居中
  local start_row = math.floor((screen_height - float_height) / 2)
  local start_col = math.floor((screen_width - float_width) / 2)

  -- 内部布局比例
  local browse_ratio = layout.browse_width or 0.65

  -- Browse 面板 (左侧)
  local browse_width = math.floor(float_width * browse_ratio) - 1
  local browse_height = float_height - 2

  -- Input 面板 (右侧)
  local input_width = float_width - browse_width - 3
  local input_col = start_col + browse_width + 2
  local input_height = float_height - 2

  -- 创建浮窗
  local browse_win = create_float_win(buffers.browse, start_row, start_col, browse_width, browse_height, {
    title = " Browse ",
    border = "rounded",
  })

  local input_win = create_float_win(buffers.input, start_row, input_col, input_width, input_height, {
    title = " Input (:w to send) ",
    border = "rounded",
  })

  -- 聚焦到 Input 窗口
  vim.api.nvim_set_current_win(input_win)

  local windows = {
    browse = browse_win,
    input = input_win,
  }

  -- 初始高亮当前窗口
  update_border_highlight(windows)

  -- 创建 autocmd 组
  local augroup = vim.api.nvim_create_augroup("OrchestrateWindowFocus", { clear = true })

  -- 监听窗口进入事件，更新边框高亮
  vim.api.nvim_create_autocmd("WinEnter", {
    group = augroup,
    callback = function()
      local current = vim.api.nvim_get_current_win()
      -- 只在 orchestrate 窗口内更新
      if current == windows.browse or current == windows.input then
        update_border_highlight(windows)
      end
    end,
  })

  -- 设置窗口切换快捷键
  local function setup_navigation(buf)
    -- Tab / Shift-Tab 循环切换窗口
    vim.keymap.set("n", "<Tab>", function()
      local current = vim.api.nvim_get_current_win()
      if current == windows.browse then
        vim.api.nvim_set_current_win(windows.input)
      else
        vim.api.nvim_set_current_win(windows.browse)
      end
    end, { buffer = buf, silent = true, desc = "Next window" })

    vim.keymap.set("n", "<S-Tab>", function()
      local current = vim.api.nvim_get_current_win()
      if current == windows.browse then
        vim.api.nvim_set_current_win(windows.input)
      else
        vim.api.nvim_set_current_win(windows.browse)
      end
    end, { buffer = buf, silent = true, desc = "Previous window" })

    -- 数字键快速切换: 1=Browse, 2=Input
    vim.keymap.set("n", "1", function()
      vim.api.nvim_set_current_win(windows.browse)
    end, { buffer = buf, silent = true, desc = "Go to Browse" })

    vim.keymap.set("n", "2", function()
      vim.api.nvim_set_current_win(windows.input)
    end, { buffer = buf, silent = true, desc = "Go to Input" })

    -- Ctrl + h/l 方向切换
    vim.keymap.set("n", "<C-h>", function()
      vim.api.nvim_set_current_win(windows.browse)
    end, { buffer = buf, silent = true, desc = "Go to Browse (left)" })

    vim.keymap.set("n", "<C-l>", function()
      vim.api.nvim_set_current_win(windows.input)
    end, { buffer = buf, silent = true, desc = "Go to Input (right)" })
  end

  -- 为所有 buffer 设置导航
  for _, buf in ipairs({ buffers.browse, buffers.input }) do
    setup_navigation(buf)
  end

  -- 所有面板按 q 退出浮窗
  for _, buf in ipairs({ buffers.browse, buffers.input }) do
    vim.keymap.set("n", "q", function()
      require("orchestrate").close()
    end, { buffer = buf, silent = true, desc = "Close orchestrate" })
  end

  -- Browse 按 i 跳转到 Input 并进入插入模式
  vim.keymap.set("n", "i", function()
    vim.api.nvim_set_current_win(windows.input)
    vim.cmd("startinsert")
  end, { buffer = buffers.browse, silent = true, desc = "Go to Input and insert" })

  return windows
end

function Layout.close(windows)
  if not windows then
    return
  end

  -- 清理 autocmd
  pcall(vim.api.nvim_del_augroup_by_name, "OrchestrateWindowFocus")

  for _, win_name in ipairs({ "browse", "input" }) do
    local win = windows[win_name]
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
end

return Layout
