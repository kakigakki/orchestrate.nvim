local Actions = {}

local function timestamp()
  return os.time()
end

local function next_message_id(prefix, collection)
  return string.format("%s-%d", prefix, #collection + 1)
end

local function find_message(messages, id)
  for _, message in ipairs(messages) do
    if message.id == id then
      return message
    end
  end

  return nil
end

function Actions.submit_prompt(store, text)
  local content = vim.trim(text or "")
  if content == "" then
    return
  end

  store:update(function(state)
    table.insert(state.messages, {
      id = next_message_id("user", state.messages),
      kind = "user_submit",
      role = "user",
      content = content,
      created_at = timestamp(),
    })
    state.status = "connecting"
    state.draft = { lines = {} }
    state.meta.last_error = nil
    return state
  end)
end

function Actions.set_status(store, status)
  store:update(function(state)
    state.status = status
    return state
  end)
end

function Actions.clear_error(store)
  store:update(function(state)
    state.meta.last_error = nil
    return state
  end)
end

function Actions.connected(store, payload)
  store:update(function(state)
    if state.status == "connecting" then
      state.status = "streaming"
    end
    table.insert(state.messages, {
      id = next_message_id("system", state.messages),
      kind = "system_info",
      role = "system",
      content = string.format("Connected to %s", payload.model or "Claude"),
      created_at = timestamp(),
      meta = {
        model = payload.model,
        cwd = payload.cwd,
      },
    })
    return state
  end)
end

function Actions.stream_start(store, payload)
  store:update(function(state)
    table.insert(state.messages, {
      id = payload.id,
      kind = "assistant_stream",
      role = "assistant",
      title = payload.title or "Assistant",
      content = "",
      blocks = {},
      created_at = timestamp(),
      streaming = true,
    })
    state.status = "streaming"
    state.meta.last_error = nil
    return state
  end)
end

function Actions.stream_delta(store, payload)
  store:update(function(state)
    local message = find_message(state.messages, payload.id)
    if message then
      message.content = (message.content or "") .. (payload.delta or "")
    end
    return state
  end)
end

function Actions.stream_end(store, payload)
  store:update(function(state)
    for index = #state.messages, 1, -1 do
      local message = state.messages[index]
      if message.kind == "assistant_stream" and message.streaming then
        message.streaming = false
        if payload then
          message.cost_usd = payload.cost_usd
          message.num_turns = payload.num_turns
          message.duration_ms = payload.duration_ms
        end
        break
      end
    end

    if state.status ~= "error" then
      state.status = "idle"
    end

    return state
  end)
end

-- Content block handling
function Actions.content_block_start(store, payload)
  store:update(function(state)
    local message = find_message(state.messages, payload.id)
    if message then
      message.blocks = message.blocks or {}
      local index = (payload.index or #message.blocks) + 1
      message.blocks[index] = {
        type = payload.block_type or "text",
        content = "",
        streaming = true,
      }
      message.current_block_index = index
    end
    return state
  end)
end

function Actions.content_block_delta(store, payload)
  store:update(function(state)
    local message = find_message(state.messages, payload.id)
    if message and message.blocks then
      local index = message.current_block_index or #message.blocks
      local block = message.blocks[index]
      if block then
        block.content = (block.content or "") .. (payload.delta or "")
        -- Also append to main content for text blocks
        if block.type == "text" then
          message.content = (message.content or "") .. (payload.delta or "")
        end
      end
    end
    return state
  end)
end

function Actions.content_block_end(store, payload)
  store:update(function(state)
    local message = find_message(state.messages, payload.id)
    if message and message.blocks then
      local index = message.current_block_index or #message.blocks
      local block = message.blocks[index]
      if block then
        block.streaming = false
      end
    end
    return state
  end)
end

-- Tool use handling
function Actions.tool_use_start(store, payload)
  store:update(function(state)
    local message = find_message(state.messages, payload.id)
    if message then
      message.blocks = message.blocks or {}
      local index = (payload.index or #message.blocks) + 1
      message.blocks[index] = {
        type = "tool_use",
        tool_use_id = payload.tool_use_id,
        tool_name = payload.tool_name,
        input = payload.input,
        input_json = "",
        streaming = true,
      }
      message.current_block_index = index
    end
    return state
  end)
end

function Actions.tool_use_end(store, payload)
  store:update(function(state)
    local message = find_message(state.messages, payload.id)
    if message and message.blocks then
      for _, block in ipairs(message.blocks) do
        if block.type == "tool_use" and block.tool_use_id == payload.tool_use_id then
          block.streaming = false
          break
        end
      end
    end
    return state
  end)
end

function Actions.tool_result(store, payload)
  store:update(function(state)
    -- Find the message with the matching tool_use
    for i = #state.messages, 1, -1 do
      local message = state.messages[i]
      if message.blocks then
        for _, block in ipairs(message.blocks) do
          if block.type == "tool_use" and block.tool_use_id == payload.tool_use_id then
            block.result = payload.content
            block.is_error = payload.is_error
            return state
          end
        end
      end
    end
    return state
  end)
end

function Actions.update_todos(store, todos)
  store:update(function(state)
    state.todos = vim.deepcopy(todos or {})
    table.insert(state.messages, {
      id = next_message_id("todo", state.messages),
      kind = "todo_updated",
      role = "system",
      content = string.format("Todo list updated (%d items).", #state.todos),
      created_at = timestamp(),
    })
    return state
  end)
end

function Actions.add_approval(store, approval)
  store:update(function(state)
    table.insert(state.approvals, vim.deepcopy(approval))
    table.insert(state.messages, {
      id = next_message_id("approval", state.messages),
      kind = "approval_requested",
      role = "system",
      content = approval.title or "Approval requested.",
      created_at = timestamp(),
    })
    state.status = "waiting_approval"
    return state
  end)
end

function Actions.add_review(store, review)
  store:update(function(state)
    table.insert(state.reviews, vim.deepcopy(review))
    table.insert(state.messages, {
      id = next_message_id("review", state.messages),
      kind = "review_ready",
      role = "system",
      content = review.title or "Review is ready.",
      created_at = timestamp(),
    })
    state.status = "reviewing"
    return state
  end)
end

function Actions.set_draft(store, lines)
  store:update(function(state)
    state.draft = {
      lines = vim.deepcopy(lines or {}),
    }
    return state
  end)
end

function Actions.reset_status(store)
  store:update(function(state)
    state.status = "idle"
    return state
  end)
end

function Actions.set_transport_meta(store, payload)
  store:update(function(state)
    state.meta = vim.tbl_extend("force", state.meta or {}, payload or {})
    return state
  end)
end

function Actions.set_error(store, payload)
  store:update(function(state)
    local error_message = (payload and payload.message) or "Unknown error."

    state.status = "error"
    state.meta.last_error = payload or { message = error_message }

    table.insert(state.messages, {
      id = next_message_id("error", state.messages),
      kind = "error",
      role = "system",
      content = error_message,
      created_at = timestamp(),
    })

    return state
  end)
end

-- Approval 交互
function Actions.resolve_approval(store, approval_id, decision)
  store:update(function(state)
    local found_index = nil
    local found_approval = nil

    for i, approval in ipairs(state.approvals) do
      if approval.id == approval_id then
        found_index = i
        found_approval = approval
        break
      end
    end

    if not found_approval then
      return state
    end

    found_approval.resolved = true
    found_approval.decision = decision
    found_approval.resolved_at = timestamp()

    table.insert(state.messages, {
      id = next_message_id("approval_resolved", state.messages),
      kind = "approval_resolved",
      role = "system",
      content = string.format(
        "Approval '%s' was %s.",
        found_approval.title or "Untitled",
        decision == "accept" and "accepted" or "rejected"
      ),
      created_at = timestamp(),
    })

    -- 移动到已解决列表
    table.remove(state.approvals, found_index)
    state.resolved_approvals = state.resolved_approvals or {}
    table.insert(state.resolved_approvals, found_approval)

    -- 如果没有更多待处理的 approval，恢复状态
    if #state.approvals == 0 and state.status == "waiting_approval" then
      state.status = "idle"
    end

    return state
  end)
end

function Actions.get_pending_approval(store)
  local state = store:get_state()
  for _, approval in ipairs(state.approvals or {}) do
    if not approval.resolved then
      return approval
    end
  end
  return nil
end

-- Review 交互
function Actions.mark_review_seen(store, review_id)
  store:update(function(state)
    for _, review in ipairs(state.reviews) do
      if review.id == review_id then
        review.seen = true
        review.seen_at = timestamp()
        break
      end
    end

    -- 检查是否所有 review 都已读
    local all_seen = true
    for _, review in ipairs(state.reviews) do
      if not review.seen then
        all_seen = false
        break
      end
    end

    if all_seen and state.status == "reviewing" then
      state.status = "idle"
    end

    return state
  end)
end

function Actions.mark_all_reviews_seen(store)
  store:update(function(state)
    for _, review in ipairs(state.reviews) do
      if not review.seen then
        review.seen = true
        review.seen_at = timestamp()
      end
    end

    if state.status == "reviewing" then
      state.status = "idle"
    end

    return state
  end)
end

function Actions.get_unseen_reviews(store)
  local state = store:get_state()
  local unseen = {}
  for _, review in ipairs(state.reviews or {}) do
    if not review.seen then
      table.insert(unseen, review)
    end
  end
  return unseen
end

-- 错误恢复
function Actions.retry_last(store)
  store:update(function(state)
    if state.status == "error" then
      state.status = "idle"
      state.meta.last_error = nil
    end
    return state
  end)
end

return Actions
