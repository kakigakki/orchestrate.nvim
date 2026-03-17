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

function M.get_session()
  return require("orchestrate.setup").get_session()
end

return M
