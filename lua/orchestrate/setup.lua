local Store = require("orchestrate.core.store")
local Actions = require("orchestrate.core.actions")
local Client = require("orchestrate.acp.client")
local Events = require("orchestrate.acp.events")
local Builtins = require("orchestrate.acp.builtins")
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

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO)
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

local function ensure_app()
  Builtins.register_all()

  if not state.store then
    state.store = Store.new()
  end

  if not state.client then
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
      elseif event_name == Events.SESSION_UPDATED then
        Actions.set_transport_meta(state.store, payload)
      elseif event_name == Events.ERROR then
        Actions.set_error(state.store, payload)
        notify("orchestrate.nvim: " .. ((payload and payload.message) or "Unknown error."), vim.log.levels.ERROR)
      end
    end)
  end

  state.client:configure(Config.get())
  Actions.set_transport_meta(state.store, {
    transport = Config.get().transport.name,
  })
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

local function clear_input_modified()
  if state.buffers and vim.api.nvim_buf_is_valid(state.buffers.input) then
    vim.bo[state.buffers.input].modified = false
  end
end

local function current_context(mode)
  local session = state.store:get_state()
  return {
    mode = mode or "send",
    transport_session_id = session.meta and session.meta.transport_session_id or nil,
    cwd = vim.fn.getcwd(),
  }
end

local function do_submit(text, mode)
  ensure_app()

  local content = vim.trim(text or "")
  if content == "" then
    notify("orchestrate.nvim: input is empty", vim.log.levels.WARN)
    return false
  end

  Actions.submit_prompt(state.store, content)
  clear_input_modified()

  local ok, request_or_error = state.client:send_message(content, current_context(mode))
  if not ok then
    Actions.set_error(state.store, {
      message = request_or_error or "request failed",
    })
    notify("orchestrate.nvim: " .. (request_or_error or "request failed"), vim.log.levels.ERROR)
    return false
  end

  Actions.set_transport_meta(state.store, {
    last_request_id = request_or_error,
  })

  return true
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

  if state.client then
    state.client:cancel()
  end

  Layout.close(state.windows)
  state.windows = nil
  state.buffers = nil
end

function M.submit(text)
  return do_submit(text, "send")
end

function M.resume(text)
  ensure_app()

  local session = state.store:get_state()
  if not session.meta or not session.meta.transport_session_id then
    Actions.set_error(state.store, {
      message = "No Claude session_id is available for resume.",
    })
    notify("orchestrate.nvim: no Claude session_id is available for resume", vim.log.levels.ERROR)
    return false
  end

  return do_submit(text, "resume")
end

function M.continue_last(text)
  return do_submit(text, "continue")
end

function M.submit_from_input()
  return M.submit(get_input_text())
end

function M.resume_from_input()
  return M.resume(get_input_text())
end

function M.continue_from_input()
  return M.continue_last(get_input_text())
end

function M.setup(opts)
  Config.setup(opts)
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
