local Store = require("orchestrate.core.store")
local Actions = require("orchestrate.core.actions")
local Client = require("orchestrate.acp.client")
local Events = require("orchestrate.acp.events")
local Builtins = require("orchestrate.acp.builtins")
local Config = require("orchestrate.config")
local Logger = require("orchestrate.utils.logger")
local BrowseRenderer = require("orchestrate.renderers.browse")
local InputRenderer = require("orchestrate.renderers.input")
local Buffers = require("orchestrate.ui.buffers")
local Layout = require("orchestrate.ui.layout")
local ApprovalUI = require("orchestrate.ui.approval")
local ReviewUI = require("orchestrate.ui.review")
local Commands = require("orchestrate.commands")
local SessionStorage = require("orchestrate.core.session_storage")

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

  if vim.api.nvim_buf_is_valid(state.buffers.input) then
    InputRenderer.render(session, state.buffers.input)
  end
end

local function ensure_app()
  Builtins.register_all()

  if not state.store then
    state.store = Store.new()
    Logger.debug("Store created with id: %s", state.store:get_state().id)
  end

  if not state.client then
    state.client = Client.new(Config.get())
    state.client:set_dispatch(function(event_name, payload)
      Logger.debug("Event received: %s", event_name)

      if event_name == Events.CONNECTED then
        Actions.connected(state.store, payload)
      elseif event_name == Events.ASSISTANT_STREAM_START then
        Actions.stream_start(state.store, payload)
      elseif event_name == Events.ASSISTANT_STREAM_DELTA then
        Actions.stream_delta(state.store, payload)
      elseif event_name == Events.ASSISTANT_STREAM_END then
        Actions.stream_end(state.store, payload)
        -- 消息完成后自动保存会话
        local options = Config.get()
        if options.session and options.session.auto_save then
          vim.schedule(function()
            SessionStorage.save(state.store:get_state())
          end)
        end
      elseif event_name == Events.CONTENT_BLOCK_START then
        Actions.content_block_start(state.store, payload)
      elseif event_name == Events.CONTENT_BLOCK_DELTA then
        Actions.content_block_delta(state.store, payload)
      elseif event_name == Events.CONTENT_BLOCK_END then
        Actions.content_block_end(state.store, payload)
      elseif event_name == Events.TOOL_USE_START then
        Actions.tool_use_start(state.store, payload)
      elseif event_name == Events.TOOL_USE_END then
        Actions.tool_use_end(state.store, payload)
      elseif event_name == Events.TOOL_RESULT then
        Actions.tool_result(state.store, payload)
      elseif event_name == Events.TODO_UPDATED then
        Actions.update_todos(state.store, payload)
      elseif event_name == Events.APPROVAL_REQUESTED then
        Actions.add_approval(state.store, payload)
        -- 强制弹出授权弹窗
        vim.schedule(function()
          ApprovalUI.show_forced_popup(payload, function(approval_id, decision)
            Actions.resolve_approval(state.store, approval_id, decision)
            Logger.info("Approval %s: %s", approval_id, decision)
            -- 如果接受，通知 transport 继续 (如果支持的话)
            if decision == "accept" and state.client then
              state.client:respond_approval(approval_id, true)
            elseif decision == "reject" and state.client then
              state.client:respond_approval(approval_id, false)
            end
          end)
        end)
      elseif event_name == Events.REVIEW_READY then
        Actions.add_review(state.store, payload)
        notify("orchestrate.nvim: Review ready - use :OrchestrateReviewJump", vim.log.levels.INFO)
      elseif event_name == Events.SESSION_UPDATED then
        Actions.set_transport_meta(state.store, payload)
        -- 自动保存会话
        local options = Config.get()
        if options.session and options.session.auto_save then
          vim.schedule(function()
            SessionStorage.save(state.store:get_state())
          end)
        end
      elseif event_name == Events.ERROR then
        Actions.set_error(state.store, payload)
        notify(
          "orchestrate.nvim: " .. ((payload and payload.message) or "Unknown error."),
          vim.log.levels.ERROR
        )
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

  Logger.info("Submitting prompt (mode=%s): %s", mode, content:sub(1, 50))

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

  -- 检查浮窗是否已经打开
  if state.windows and state.windows.input and vim.api.nvim_win_is_valid(state.windows.input) then
    vim.api.nvim_set_current_win(state.windows.input)
    return
  end

  state.buffers = Buffers.create()
  state.windows = Layout.open(state.buffers)

  if state.unsubscribe then
    state.unsubscribe()
  end

  state.unsubscribe = state.store:subscribe(render_all)
  set_input_autocmd(M)

  -- 如果当前没有消息且启用了自动恢复，尝试恢复最近的会话
  local current_state = state.store:get_state()
  local options = Config.get()
  if
    #current_state.messages == 0
    and options.session
    and options.session.auto_restore
  then
    SessionStorage.get_latest_session(function(session_info)
      if session_info then
        SessionStorage.load(session_info.session_id, function(data, err)
          if data and not err then
            vim.schedule(function()
              state.store:update(function(s)
                s.messages = data.messages or {}
                s.todos = data.todos or {}
                s.meta = vim.tbl_extend("force", s.meta or {}, data.meta or {})
                s.status = "idle"
                return s
              end)
              Logger.info("Auto-restored session: %s", session_info.session_id)
              -- 恢复后重新渲染
              render_all(state.store:get_state())
            end)
          else
            -- 没有会话可恢复，正常渲染
            render_all(state.store:get_state())
          end
        end)
      else
        -- 没有会话可恢复，正常渲染
        render_all(state.store:get_state())
      end
    end)
  else
    render_all(state.store:get_state())
  end

  Logger.info("Workspace opened")
end

function M.close()
  -- 关闭前保存会话
  local options = Config.get()
  if state.store and options.session and options.session.auto_save then
    SessionStorage.save(state.store:get_state())
  end

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

  -- 清除 input buffer 的 modified 状态，避免退出时提示保存
  if state.buffers and state.buffers.input and vim.api.nvim_buf_is_valid(state.buffers.input) then
    vim.bo[state.buffers.input].modified = false
  end

  Layout.close(state.windows)
  state.windows = nil

  Logger.info("Workspace closed")
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

-- Approval 交互
function M.approve()
  ensure_app()
  local session = state.store:get_state()
  ApprovalUI.approve_first(session, function(approval_id, decision)
    Actions.resolve_approval(state.store, approval_id, decision)
    Logger.info("Approval %s: %s", approval_id, decision)
  end)
end

function M.reject()
  ensure_app()
  local session = state.store:get_state()
  ApprovalUI.reject_first(session, function(approval_id, decision)
    Actions.resolve_approval(state.store, approval_id, decision)
    Logger.info("Approval %s: %s", approval_id, decision)
  end)
end

function M.select_approval()
  ensure_app()
  local session = state.store:get_state()
  ApprovalUI.select_and_resolve(session, function(approval_id, decision)
    Actions.resolve_approval(state.store, approval_id, decision)
    Logger.info("Approval %s: %s", approval_id, decision)
  end)
end

-- Review 交互
function M.review_jump()
  ensure_app()
  local session = state.store:get_state()
  ReviewUI.jump_to_first_unseen(session, function(review_id)
    Actions.mark_review_seen(state.store, review_id)
  end)
end

function M.review_select()
  ensure_app()
  local session = state.store:get_state()
  ReviewUI.select_and_jump(session, function(review_id)
    Actions.mark_review_seen(state.store, review_id)
  end)
end

function M.review_quickfix()
  ensure_app()
  local session = state.store:get_state()
  ReviewUI.to_quickfix(session, function()
    Actions.mark_all_reviews_seen(state.store)
  end)
end

-- 错误恢复
function M.retry()
  ensure_app()
  local session = state.store:get_state()

  if session.status ~= "error" then
    notify("orchestrate.nvim: No error to retry", vim.log.levels.INFO)
    return false
  end

  Actions.retry_last(state.store)

  -- 获取最后一条用户消息并重试
  local last_user_message = nil
  for i = #session.messages, 1, -1 do
    if session.messages[i].kind == "user_submit" then
      last_user_message = session.messages[i].content
      break
    end
  end

  if last_user_message then
    notify("orchestrate.nvim: Retrying last message...", vim.log.levels.INFO)
    return do_submit(last_user_message, "send")
  else
    notify("orchestrate.nvim: No message to retry", vim.log.levels.WARN)
    return false
  end
end

function M.setup(opts)
  Config.setup(opts)

  -- 初始化日志
  local debug_opts = (opts and opts.debug) or {}
  Logger.setup({
    enabled = debug_opts.enabled or false,
    level = debug_opts.log_level or "INFO",
    to_file = debug_opts.to_file or false,
  })

  ensure_app()
  Commands.setup(M)

  -- 退出 Neovim 前保存会话并清除 input buffer 的 modified 状态
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("OrchestrateCleanup", { clear = true }),
    callback = function()
      -- 保存会话
      local options = Config.get()
      if state.store and options.session and options.session.auto_save then
        -- 同步保存，确保在退出前完成
        local current = state.store:get_state()
        if current and current.messages and #current.messages > 0 then
          local session_id = (current.meta and current.meta.transport_session_id) or current.id
          if session_id then
            local folder = SessionStorage.get_sessions_folder()
            vim.fn.mkdir(folder, "p")
            local data = {
              version = 1,
              session_id = session_id,
              timestamp = os.time(),
              cwd = vim.uv.cwd() or vim.fn.getcwd(),
              messages = current.messages,
              todos = current.todos,
              meta = {
                transport = current.meta and current.meta.transport,
                transport_session_id = current.meta and current.meta.transport_session_id,
                store_id = current.id,
              },
            }
            local ok, json = pcall(vim.json.encode, data)
            if ok then
              local path = SessionStorage.get_session_file(session_id)
              local file = io.open(path, "w")
              if file then
                file:write(json)
                file:close()
                Logger.debug("Session saved on exit: %s", session_id)
              end
            end
          end
        end
      end

      -- 清除 modified 状态
      if state.buffers and state.buffers.input and vim.api.nvim_buf_is_valid(state.buffers.input) then
        vim.bo[state.buffers.input].modified = false
      end
    end,
  })

  Logger.info("orchestrate.nvim setup complete")
end

function M.get_session()
  ensure_app()
  return state.store:get_state()
end

function M.is_open()
  return state.windows ~= nil
    and state.windows.input
    and vim.api.nvim_win_is_valid(state.windows.input)
end

-- 会话恢复功能
function M.restore_session(session_id)
  ensure_app()

  local function do_restore(data)
    if not data then
      notify("orchestrate.nvim: No session data to restore", vim.log.levels.WARN)
      return
    end

    -- 恢复状态到 store
    state.store:update(function(current_state)
      current_state.messages = data.messages or {}
      current_state.todos = data.todos or {}
      current_state.meta = vim.tbl_extend("force", current_state.meta or {}, data.meta or {})
      current_state.status = "idle"
      return current_state
    end)

    notify(
      string.format(
        "orchestrate.nvim: Restored session with %d messages",
        #(data.messages or {})
      ),
      vim.log.levels.INFO
    )

    Logger.info("Session restored: %s", data.session_id or "unknown")
  end

  if session_id then
    -- 恢复指定会话
    SessionStorage.load(session_id, function(data, err)
      if err then
        notify("orchestrate.nvim: " .. err, vim.log.levels.ERROR)
        return
      end
      vim.schedule(function()
        do_restore(data)
      end)
    end)
  else
    -- 恢复最近的会话
    SessionStorage.get_latest_session(function(session_info)
      if not session_info then
        notify("orchestrate.nvim: No previous session found", vim.log.levels.INFO)
        return
      end
      SessionStorage.load(session_info.session_id, function(data, err)
        if err then
          notify("orchestrate.nvim: " .. err, vim.log.levels.ERROR)
          return
        end
        vim.schedule(function()
          do_restore(data)
        end)
      end)
    end)
  end
end

-- 列出可用的会话
function M.list_sessions(callback)
  SessionStorage.list_sessions(callback or function(sessions)
    if #sessions == 0 then
      notify("orchestrate.nvim: No saved sessions found", vim.log.levels.INFO)
      return
    end

    local items = {}
    for _, session in ipairs(sessions) do
      local time_str = os.date("%Y-%m-%d %H:%M", session.timestamp)
      table.insert(items, {
        session_id = session.session_id,
        display = string.format("[%s] %d messages", time_str, session.message_count),
      })
    end

    vim.ui.select(items, {
      prompt = "Select session to restore:",
      format_item = function(item)
        return item.display
      end,
    }, function(selected)
      if selected then
        M.restore_session(selected.session_id)
      end
    end)
  end)
end

-- 清除当前会话（开始新会话）
function M.new_session()
  ensure_app()

  state.store:update(function(current_state)
    current_state.messages = {}
    current_state.todos = {}
    current_state.approvals = {}
    current_state.resolved_approvals = {}
    current_state.reviews = {}
    current_state.status = "idle"
    current_state.meta.transport_session_id = nil
    current_state.meta.last_request_id = nil
    current_state.meta.last_error = nil
    return current_state
  end)

  notify("orchestrate.nvim: Started new session", vim.log.levels.INFO)
  Logger.info("New session started")
end

return M
