local M = {}

local status_icons = {
  pending = "[ ]",
  in_progress = "[*]",
  completed = "[x]",
  blocked = "[!]",
}

local function format_todo(index, todo)
  local icon = status_icons[todo.status] or "[ ]"
  local title = todo.title or todo.content or "Untitled"
  return string.format("%d. %s %s", index, icon, title)
end

local function format_approval(index, approval)
  local status = approval.resolved and "[done]" or "[pending]"
  local title = approval.title or "Untitled approval"
  local decision = ""
  if approval.resolved then
    decision = string.format(" (%s)", approval.decision or "unknown")
  end
  return string.format("   %d. %s %s%s", index, status, title, decision)
end

local function format_review(index, review)
  local status = review.seen and "[seen]" or "[new]"
  local title = review.title or "Untitled review"
  local severity = review.severity and string.format(" [%s]", review.severity) or ""
  local location = ""
  if review.file then
    location = string.format(" @ %s", review.file)
    if review.line then
      location = location .. ":" .. tostring(review.line)
    end
  end
  return string.format("   %d. %s%s %s%s", index, status, severity, title, location)
end

function M.render(session, bufnr)
  local lines = {
    "ORCHESTRATE / TODO",
    string.rep("=", 40),
    "",
  }

  -- Todos section
  if #session.todos == 0 then
    table.insert(lines, "No todos yet.")
  else
    table.insert(lines, string.format("Tasks (%d):", #session.todos))
    table.insert(lines, "")
    for index, todo in ipairs(session.todos) do
      table.insert(lines, format_todo(index, todo))
      if todo.detail and todo.detail ~= "" then
        for _, detail_line in ipairs(vim.split(todo.detail, "\n", { plain = true })) do
          table.insert(lines, "      " .. detail_line)
        end
      end
    end
  end

  table.insert(lines, "")

  -- Approvals section
  local pending_approvals = {}
  for _, approval in ipairs(session.approvals or {}) do
    if not approval.resolved then
      table.insert(pending_approvals, approval)
    end
  end

  if #pending_approvals > 0 then
    table.insert(lines, string.rep("-", 40))
    table.insert(lines, string.format("APPROVALS PENDING (%d):", #pending_approvals))
    table.insert(lines, "")
    for index, approval in ipairs(pending_approvals) do
      table.insert(lines, format_approval(index, approval))
      if approval.description then
        for _, desc_line in ipairs(vim.split(approval.description, "\n", { plain = true })) do
          table.insert(lines, "      " .. desc_line)
        end
      end
      if approval.command then
        table.insert(lines, string.format("      cmd: %s", approval.command))
      end
    end
    table.insert(lines, "")
    table.insert(lines, "   Use :OrchestrateApprove or :OrchestrateReject")
    table.insert(lines, "")
  end

  -- Reviews section
  local unseen_reviews = {}
  local seen_reviews = {}
  for _, review in ipairs(session.reviews or {}) do
    if review.seen then
      table.insert(seen_reviews, review)
    else
      table.insert(unseen_reviews, review)
    end
  end

  if #unseen_reviews > 0 then
    table.insert(lines, string.rep("-", 40))
    table.insert(
      lines,
      string.format("REVIEWS (new: %d, seen: %d):", #unseen_reviews, #seen_reviews)
    )
    table.insert(lines, "")
    for index, review in ipairs(unseen_reviews) do
      table.insert(lines, format_review(index, review))
      if review.message then
        for _, msg_line in ipairs(vim.split(review.message, "\n", { plain = true })) do
          table.insert(lines, "      " .. msg_line)
        end
      end
    end
    table.insert(lines, "")
    table.insert(lines, "   Use :OrchestrateReviewJump or :OrchestrateReviewQuickfix")
    table.insert(lines, "")
  elseif #seen_reviews > 0 then
    table.insert(lines, string.rep("-", 40))
    table.insert(lines, string.format("REVIEWS (all %d seen):", #seen_reviews))
    table.insert(lines, "")
  end

  -- Status summary
  table.insert(lines, string.rep("-", 40))
  table.insert(lines, string.format("Status: %s", session.status or "unknown"))

  if session.meta and session.meta.last_error then
    table.insert(lines, "")
    table.insert(lines, "LAST ERROR:")
    table.insert(lines, "  " .. (session.meta.last_error.message or "Unknown error"))
    table.insert(lines, "")
    table.insert(lines, "  Use :OrchestrateRetry to retry")
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

return M
