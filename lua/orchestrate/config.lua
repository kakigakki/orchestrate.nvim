local M = {}

local defaults = {
  layout = {
    browse_width = 0.7,
    todo_height = 0.5,
    min_browse_width = 40,
    min_sidebar_height = 6,
  },
  ui = {
    input_filetype = "markdown",
  },
  mock = {
    enabled = true,
    chunk_delay = 160,
  },
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
