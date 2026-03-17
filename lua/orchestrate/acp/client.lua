local Registry = require("orchestrate.acp.registry")

local Client = {}
Client.__index = Client

function Client.new(opts)
  local self = setmetatable({}, Client)
  self.opts = opts or {}
  self.transport_name = nil
  self.transport = nil
  self.dispatch = nil
  return self
end

function Client:set_dispatch(dispatch)
  self.dispatch = dispatch
  if self.transport and self.transport.set_dispatch then
    self.transport:set_dispatch(dispatch)
  end
end

function Client:configure(opts)
  self.opts = opts or self.opts

  local transport_name = self.opts.transport.name
  if self.transport and self.transport_name == transport_name then
    if self.transport.set_opts then
      self.transport:set_opts(self.opts)
    end
    if self.transport.set_dispatch then
      self.transport:set_dispatch(self.dispatch)
    end
    return self.transport
  end

  if self.transport and self.transport.disconnect then
    self.transport:disconnect()
  end

  self.transport_name = transport_name
  self.transport = Registry.create(transport_name, self.opts)

  if self.transport and self.transport.set_dispatch then
    self.transport:set_dispatch(self.dispatch)
  end

  return self.transport
end

function Client:get_transport()
  return self.transport
end

function Client:send_message(text, context)
  if not self.transport then
    return false, "transport_not_configured"
  end

  return self.transport:send_message(text, context or {})
end

function Client:cancel(request_id)
  if not self.transport or not self.transport.cancel then
    return false, "transport_cannot_cancel"
  end

  return self.transport:cancel(request_id)
end

function Client:is_available()
  if not self.transport or not self.transport.is_available then
    return false, "transport_not_configured"
  end

  return self.transport:is_available()
end

function Client:healthcheck()
  if not self.transport or not self.transport.healthcheck then
    return {
      ok = false,
      message = "transport is not configured",
    }
  end

  return self.transport:healthcheck()
end

return Client
