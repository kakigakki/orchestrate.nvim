local M = {}

function M.setup(opts)
  require("orchestrate.setup").setup(opts or {})
end

function M.open()
  require("orchestrate.setup").open()
end

function M.close()
  require("orchestrate.setup").close()
end

function M.send(text)
  require("orchestrate.setup").submit(text)
end

function M.resume(text)
  require("orchestrate.setup").resume(text)
end

function M.continue_last(text)
  require("orchestrate.setup").continue_last(text)
end

function M.get_session()
  return require("orchestrate.setup").get_session()
end

function M.register_transport(name, transport)
  require("orchestrate.acp.registry").register(name, transport)
end

return M
