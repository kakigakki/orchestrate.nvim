local M = {}
local registered = false

function M.setup(app)
  if registered then
    return
  end

  vim.api.nvim_create_user_command("OrchestrateOpen", function()
    app.open()
  end, {})

  vim.api.nvim_create_user_command("OrchestrateClose", function()
    app.close()
  end, {})

  vim.api.nvim_create_user_command("OrchestrateSend", function(opts)
    if opts.args ~= "" then
      app.submit(opts.args)
      return
    end

    app.submit_from_input()
  end, {
    nargs = "?",
  })

  registered = true
end

return M
