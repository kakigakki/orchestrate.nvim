local Registry = {
  transports = {},
}

local function instantiate(entry, opts)
  if type(entry) == "function" then
    return entry(opts)
  end

  if type(entry) == "table" and type(entry.new) == "function" then
    return entry.new(opts)
  end

  if type(entry) == "table" then
    local instance = vim.deepcopy(entry)
    if instance.set_opts then
      instance:set_opts(opts)
    else
      instance.opts = opts
    end
    return instance
  end

  error("invalid transport registration")
end

function Registry.register(name, transport)
  Registry.transports[name] = transport
end

function Registry.has(name)
  return Registry.transports[name] ~= nil
end

function Registry.get(name)
  return Registry.transports[name]
end

function Registry.create(name, opts)
  local entry = Registry.get(name)
  if not entry then
    error(string.format("transport '%s' is not registered", name))
  end

  return instantiate(entry, opts or {})
end

function Registry.list()
  local names = {}
  for name in pairs(Registry.transports) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

return Registry
