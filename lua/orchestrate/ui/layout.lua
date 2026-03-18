local Config = require("orchestrate.config")

local Layout = {}

function Layout.open(buffers)
  local options = Config.get()
  vim.cmd("tabnew")

  local browse_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(browse_win, buffers.browse)

  vim.cmd("vsplit")
  local todo_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(todo_win, buffers.todo)

  local total_width = vim.o.columns
  local browse_width =
    math.max(math.floor(total_width * options.layout.browse_width), options.layout.min_browse_width)
  vim.api.nvim_win_set_width(browse_win, browse_width)

  vim.cmd("split")
  local input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(input_win, buffers.input)

  local right_height = vim.api.nvim_win_get_height(todo_win)
    + vim.api.nvim_win_get_height(input_win)
  local top_height = math.max(
    math.floor(right_height * options.layout.todo_height),
    options.layout.min_sidebar_height
  )
  vim.api.nvim_win_set_height(todo_win, top_height)

  vim.api.nvim_set_current_win(input_win)

  return {
    tabpage = vim.api.nvim_get_current_tabpage(),
    browse = browse_win,
    todo = todo_win,
    input = input_win,
  }
end

function Layout.close(windows)
  if not windows or not windows.tabpage then
    return
  end

  if vim.api.nvim_tabpage_is_valid(windows.tabpage) then
    vim.api.nvim_set_current_tabpage(windows.tabpage)
    vim.cmd("tabclose")
  end
end

return Layout
