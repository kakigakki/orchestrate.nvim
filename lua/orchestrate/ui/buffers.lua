local Config = require("orchestrate.config")

local Buffers = {}

local function ensure_buffer(name)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, name)
  return bufnr
end

function Buffers.create()
  local options = Config.get()
  local browse = ensure_buffer("orchestrate://browse")
  local todo = ensure_buffer("orchestrate://todo")
  local input = ensure_buffer("orchestrate://input")

  vim.bo[browse].buftype = "nofile"
  vim.bo[browse].bufhidden = "hide"
  vim.bo[browse].swapfile = false
  vim.bo[browse].modifiable = false
  vim.bo[browse].filetype = "orchestrate-browse"

  vim.bo[todo].buftype = "nofile"
  vim.bo[todo].bufhidden = "hide"
  vim.bo[todo].swapfile = false
  vim.bo[todo].modifiable = false
  vim.bo[todo].filetype = "orchestrate-todo"

  vim.bo[input].buftype = "acwrite"
  vim.bo[input].bufhidden = "hide"
  vim.bo[input].swapfile = false
  vim.bo[input].modifiable = true
  vim.bo[input].filetype = options.ui.input_filetype

  return {
    browse = browse,
    todo = todo,
    input = input,
  }
end

return Buffers
