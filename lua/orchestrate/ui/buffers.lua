local Config = require("orchestrate.config")

local Buffers = {}

local function find_or_create_buffer(name)
  -- 查找已存在的 buffer
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      if buf_name == name or buf_name:match(vim.pesc(name) .. "$") then
        return bufnr, true
      end
    end
  end

  -- 创建新 buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, name)
  return bufnr, false
end

function Buffers.create()
  local options = Config.get()
  local browse = find_or_create_buffer("orchestrate://browse")
  local input = find_or_create_buffer("orchestrate://input")

  -- Browse buffer: 使用 markdown 获得基础语法高亮
  -- 工具区域使用高优先级 extmark 覆盖
  vim.bo[browse].buftype = "nofile"
  vim.bo[browse].bufhidden = "hide"
  vim.bo[browse].swapfile = false
  vim.bo[browse].buflisted = false
  vim.bo[browse].modifiable = false
  vim.bo[browse].filetype = "markdown"

  -- 启用 treesitter markdown 高亮
  pcall(function()
    vim.treesitter.start(browse, "markdown")
  end)

  -- Input buffer: 使用 markdown，允许 treesitter 高亮
  vim.bo[input].buftype = "acwrite"
  vim.bo[input].bufhidden = "hide"
  vim.bo[input].swapfile = false
  vim.bo[input].modifiable = true
  vim.bo[input].filetype = options.ui.input_filetype

  return {
    browse = browse,
    input = input,
  }
end

return Buffers
