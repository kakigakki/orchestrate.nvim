local Actions = {}

local function timestamp()
  return os.date("%H:%M:%S")
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
    state.status = "streaming"
    state.draft = { lines = {} }
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
      created_at = timestamp(),
      streaming = true,
    })
    state.status = "streaming"
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

function Actions.stream_end(store)
  store:update(function(state)
    for index = #state.messages, 1, -1 do
      local message = state.messages[index]
      if message.kind == "assistant_stream" and message.streaming then
        message.streaming = false
        break
      end
    end
    state.status = "idle"
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
      content = string.format("任务列表已更新，共 %d 项。", #state.todos),
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
      content = approval.title or "收到审批请求。",
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
      content = review.title or "收到审查结果。",
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

return Actions
