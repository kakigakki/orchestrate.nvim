local M = {}

function M.render(session, bufnr)
  local existing = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local draft_lines = session.draft and session.draft.lines or {}

  if vim.deep_equal(existing, draft_lines) then
    return
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, draft_lines)
  vim.bo[bufnr].modifiable = true
end

return M
