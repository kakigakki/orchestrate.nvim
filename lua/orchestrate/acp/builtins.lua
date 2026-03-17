local Registry = require("orchestrate.acp.registry")

local M = {}
local registered = false

function M.register_all()
  if registered then
    return
  end

  Registry.register("mock", require("orchestrate.acp.transports.mock"))
  Registry.register("claude_code", require("orchestrate.acp.transports.claude_code"))
  registered = true
end

return M
