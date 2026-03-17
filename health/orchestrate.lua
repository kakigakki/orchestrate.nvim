local Config = require("orchestrate.config")
local Registry = require("orchestrate.acp.registry")
local Builtins = require("orchestrate.acp.builtins")

local M = {}

local function health_module()
  return vim.health or require("health")
end

local function start(title)
  local health = health_module()
  if health.start then
    health.start(title)
  else
    health.report_start(title)
  end
end

local function ok(message)
  local health = health_module()
  if health.ok then
    health.ok(message)
  else
    health.report_ok(message)
  end
end

local function warn(message)
  local health = health_module()
  if health.warn then
    health.warn(message)
  else
    health.report_warn(message)
  end
end

local function err(message)
  local health = health_module()
  if health.error then
    health.error(message)
  else
    health.report_error(message)
  end
end

function M.check()
  Builtins.register_all()

  local options = Config.get()
  local default_name = options.transport.name
  local registered = Registry.list()

  start("orchestrate.nvim")
  ok("plugin loaded")

  if #registered == 0 then
    err("no transports registered")
    return
  end

  ok("registered transports: " .. table.concat(registered, ", "))

  if not Registry.has(default_name) then
    err("default transport is not registered: " .. default_name)
    return
  end

  ok("default transport: " .. default_name)

  local transport = Registry.create(default_name, options)
  local available, available_err = transport:is_available()
  if available then
    ok("default transport is available")
  else
    err(available_err or "default transport is not available")
  end

  local report = transport:healthcheck()
  if report.ok then
    ok(report.message)
  else
    warn(report.message)
  end
end

return M
