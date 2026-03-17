local Store = {}
Store.__index = Store

local function deepcopy(value)
  return vim.deepcopy(value)
end

local function create_initial_state()
  return {
    id = tostring(vim.loop.hrtime()),
    status = "idle",
    messages = {},
    todos = {},
    approvals = {},
    reviews = {},
    draft = {
      lines = {},
    },
  }
end

function Store.new(initial_state)
  local self = setmetatable({}, Store)
  self.state = deepcopy(initial_state or create_initial_state())
  self.subscribers = {}
  return self
end

function Store:get_state()
  return deepcopy(self.state)
end

function Store:subscribe(callback)
  table.insert(self.subscribers, callback)

  return function()
    for index, subscriber in ipairs(self.subscribers) do
      if subscriber == callback then
        table.remove(self.subscribers, index)
        break
      end
    end
  end
end

function Store:set_state(next_state)
  self.state = deepcopy(next_state)

  for _, subscriber in ipairs(self.subscribers) do
    subscriber(self:get_state())
  end
end

function Store:update(reducer)
  local current_state = self:get_state()
  local next_state = reducer(current_state)
  self:set_state(next_state)
end

return Store
