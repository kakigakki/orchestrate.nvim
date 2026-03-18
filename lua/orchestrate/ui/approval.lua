local M = {}

local function get_pending_approvals(session)
  local pending = {}
  for _, approval in ipairs(session.approvals or {}) do
    if not approval.resolved then
      table.insert(pending, approval)
    end
  end
  return pending
end

function M.select_and_resolve(session, on_resolve)
  local pending = get_pending_approvals(session)

  if #pending == 0 then
    vim.notify("orchestrate.nvim: No pending approvals", vim.log.levels.INFO)
    return
  end

  -- 如果只有一个待审批项，直接显示决策选项
  if #pending == 1 then
    M.show_decision(pending[1], on_resolve)
    return
  end

  -- 多个待审批项，先选择哪一个
  vim.ui.select(pending, {
    prompt = "Select approval to review:",
    format_item = function(approval)
      local title = approval.title or "Untitled"
      local desc = approval.description and (" - " .. approval.description:sub(1, 40)) or ""
      return title .. desc
    end,
  }, function(selected)
    if not selected then
      return
    end
    M.show_decision(selected, on_resolve)
  end)
end

function M.show_decision(approval, on_resolve)
  local title = approval.title or "Untitled"
  local prompt_lines = { "Approval: " .. title }

  if approval.description then
    table.insert(prompt_lines, "")
    table.insert(prompt_lines, approval.description)
  end

  if approval.command then
    table.insert(prompt_lines, "")
    table.insert(prompt_lines, "Command: " .. approval.command)
  end

  local prompt = table.concat(prompt_lines, "\n")

  vim.ui.select({ "Accept", "Reject", "Cancel" }, {
    prompt = prompt .. "\n\nDecision:",
  }, function(choice)
    if not choice or choice == "Cancel" then
      return
    end

    local decision = choice == "Accept" and "accept" or "reject"
    if on_resolve then
      on_resolve(approval.id, decision)
    end
  end)
end

function M.approve_first(session, on_resolve)
  local pending = get_pending_approvals(session)

  if #pending == 0 then
    vim.notify("orchestrate.nvim: No pending approvals", vim.log.levels.INFO)
    return
  end

  local first = pending[1]
  if on_resolve then
    on_resolve(first.id, "accept")
  end
  vim.notify(
    string.format("orchestrate.nvim: Approved '%s'", first.title or "Untitled"),
    vim.log.levels.INFO
  )
end

function M.reject_first(session, on_resolve)
  local pending = get_pending_approvals(session)

  if #pending == 0 then
    vim.notify("orchestrate.nvim: No pending approvals", vim.log.levels.INFO)
    return
  end

  local first = pending[1]
  if on_resolve then
    on_resolve(first.id, "reject")
  end
  vim.notify(
    string.format("orchestrate.nvim: Rejected '%s'", first.title or "Untitled"),
    vim.log.levels.INFO
  )
end

return M
