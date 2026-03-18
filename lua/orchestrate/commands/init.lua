local M = {}
local registered = false

function M.setup(app)
  if registered then
    return
  end

  -- 基础命令
  vim.api.nvim_create_user_command("OrchestrateOpen", function()
    app.open()
  end, {
    desc = "Open orchestrate workspace",
  })

  vim.api.nvim_create_user_command("OrchestrateClose", function()
    app.close()
  end, {
    desc = "Close orchestrate workspace",
  })

  vim.api.nvim_create_user_command("OrchestrateToggle", function()
    if app.is_open() then
      app.close()
    else
      app.open()
    end
  end, {
    desc = "Toggle orchestrate workspace",
  })

  vim.api.nvim_create_user_command("OrchestrateSend", function(opts)
    if opts.args ~= "" then
      app.submit(opts.args)
      return
    end

    app.submit_from_input()
  end, {
    nargs = "?",
    desc = "Send message to agent",
  })

  vim.api.nvim_create_user_command("OrchestrateResume", function(opts)
    if opts.args ~= "" then
      app.resume(opts.args)
      return
    end

    app.resume_from_input()
  end, {
    nargs = "?",
    desc = "Resume with session ID",
  })

  vim.api.nvim_create_user_command("OrchestrateContinue", function(opts)
    if opts.args ~= "" then
      app.continue_last(opts.args)
      return
    end

    app.continue_from_input()
  end, {
    nargs = "?",
    desc = "Continue last task",
  })

  -- Approval 命令
  vim.api.nvim_create_user_command("OrchestrateApprove", function()
    app.approve()
  end, {
    desc = "Approve first pending approval",
  })

  vim.api.nvim_create_user_command("OrchestrateReject", function()
    app.reject()
  end, {
    desc = "Reject first pending approval",
  })

  vim.api.nvim_create_user_command("OrchestrateApprovalSelect", function()
    app.select_approval()
  end, {
    desc = "Select and resolve an approval",
  })

  -- Review 命令
  vim.api.nvim_create_user_command("OrchestrateReviewJump", function()
    app.review_jump()
  end, {
    desc = "Jump to first unseen review",
  })

  vim.api.nvim_create_user_command("OrchestrateReviewSelect", function()
    app.review_select()
  end, {
    desc = "Select a review to jump to",
  })

  vim.api.nvim_create_user_command("OrchestrateReviewQuickfix", function()
    app.review_quickfix()
  end, {
    desc = "Add all reviews to quickfix list",
  })

  -- 错误恢复命令
  vim.api.nvim_create_user_command("OrchestrateRetry", function()
    app.retry()
  end, {
    desc = "Retry after an error",
  })

  registered = true
end

return M
