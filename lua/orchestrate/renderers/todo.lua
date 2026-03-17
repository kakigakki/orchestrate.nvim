local M = {}

function M.render(session, bufnr)
  local lines = {
    "ORCHESTRATE / TODO",
    string.rep("=", 28),
    "",
  }

  if #session.todos == 0 then
    table.insert(lines, "暂无任务。")
  else
    for index, todo in ipairs(session.todos) do
      table.insert(lines, string.format("%d. [%s] %s", index, todo.status or "todo", todo.title or "未命名任务"))
      if todo.detail and todo.detail ~= "" then
        table.insert(lines, "   " .. todo.detail)
      end
      table.insert(lines, "")
    end
  end

  if #session.approvals > 0 then
    table.insert(lines, "Approvals:")
    for _, approval in ipairs(session.approvals) do
      table.insert(lines, "- " .. (approval.title or "待审批事项"))
    end
    table.insert(lines, "")
  end

  if #session.reviews > 0 then
    table.insert(lines, "Reviews:")
    for _, review in ipairs(session.reviews) do
      table.insert(lines, "- " .. (review.title or "待审查事项"))
    end
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

return M
