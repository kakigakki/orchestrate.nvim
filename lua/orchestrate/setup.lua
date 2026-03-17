local Store = require("orchestrate.core.store")
local Actions = require("orchestrate.core.actions")
local Client = require("orchestrate.acp.client")
local Events = require("orchestrate.acp.events")
local Config = require("orchestrate.config")
local BrowseRenderer = require("orchestrate.renderers.browse")
local TodoRenderer = require("orchestrate.renderers.todo")
local InputRenderer = require("orchestrate.renderers.input")
local Buffers = require("orchestrate.ui.buffers")
local Layout = require("orchestrate.ui.layout")
local Commands = require("orchestrate.commands")

local M = {}

local state = {
  store = nil,
  client = nil,
  buffers = nil,
  windows = nil,
  unsubscribe = nil,
  autocmd = nil,
}

local function ensure_app()
  if state.store and state.client then
    state.client.opts = Config.get()
    return
  end

  state.store = Store.new()
  state.client = Client.new(Config.get())

  state.client:set_dispatch(function(event_name, payload)
    if event_name == Events.ASSISTANT_STREAM_START then
      Actions.stream_start(state.store, payload)
    elseif event_name == Events.ASSISTANT_STREAM_DELTA then
      Actions.stream_delta(state.store, payload)
    elseif event_name == Events.ASSISTANT_STREAM_END then
      Actions.stream_end(state.store)
    elseif event_name == Events.TODO_UPDATED then
      Actions.update_todos(state.store, payload)
    elseif event_name == Events.APPROVAL_REQUESTED then
      Actions.add_approval(state.store, payload)
    elseif event_name == Events.REVIEW_READY then
      Actions.add_review(state.store, payload)
    end
  end)
end

local function render_all(session)
  if not state.buffers then
    return
  end

  if vim.api.nvim_buf_is_valid(state.buffers.browse) then
    BrowseRenderer.render(session, state.buffers.browse)
  end

  if vim.api.nvim_buf_is_valid(state.buffers.todo) then
    TodoRenderer.render(session, state.buffers.todo)
  end

  if vim.api.nvim_buf_is_valid(state.buffers.input) then
    InputRenderer.render(session, state.buffers.input)
  end
end

local function set_input_autocmd(app)
  if state.autocmd then
    pcall(vim.api.nvim_del_autocmd, state.autocmd)
    state.autocmd = nil
  end

  state.autocmd = vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = state.buffers.input,
    callback = function()
      app.submit_from_input()
    end,
  })
end

local function get_input_text()
  if not state.buffers or not vim.api.nvim_buf_is_valid(state.buffers.input) then
    return ""
  end

  local lines = vim.api.nvim_buf_get_lines(state.buffers.input, 0, -1, false)
  return table.concat(lines, "\n")
end

function M.open()
  ensure_app()

  if state.windows and state.windows.tabpage and vim.api.nvim_tabpage_is_valid(state.windows.tabpage) then
    vim.api.nvim_set_current_tabpage(state.windows.tabpage)
    if vim.api.nvim_win_is_valid(state.windows.input) then
      vim.api.nvim_set_current_win(state.windows.input)
    end
    return
  end

  state.buffers = Buffers.create()
  state.windows = Layout.open(state.buffers)

  if state.unsubscribe then
    state.unsubscribe()
  end

  state.unsubscribe = state.store:subscribe(render_all)

  set_input_autocmd(M)
  render_all(state.store:get_state())
end

function M.close()
  if state.unsubscribe then
    state.unsubscribe()
    state.unsubscribe = nil
  end

  if state.autocmd then
    pcall(vim.api.nvim_del_autocmd, state.autocmd)
    state.autocmd = nil
  end

  Layout.close(state.windows)
  state.windows = nil
  state.buffers = nil
end

function M.submit(text)
  ensure_app()

  local content = vim.trim(text or "")
  if content == "" then
    vim.notify("orchestrate.nvim: 输入内容为空", vim.log.levels.WARN)
    return
  end

  Actions.submit_prompt(state.store, content)

  if state.buffers and vim.api.nvim_buf_is_valid(state.buffers.input) then
    vim.bo[state.buffers.input].modified = false
  end

  local sent = state.client:send_message(content)
  if sent == false then
    Actions.reset_status(state.store)
  end
end

function M.submit_from_input()
  ensure_app()

  local text = get_input_text()
  M.submit(text)
end

function M.setup(_opts)
  Config.setup(_opts)
  ensure_app()
  Commands.setup(M)
end

function M.get_session()
  ensure_app()
  return state.store:get_state()
end

function M.is_open()
  return state.windows ~= nil
end

return M

