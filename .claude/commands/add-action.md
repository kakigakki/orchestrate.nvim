# 添加新 Action

为 orchestrate.nvim 的状态管理添加一个新的 Action。

## 输入参数

$ARGUMENTS = Action 名称和描述 (例如: "toggle_todo_status - 切换任务状态")

## 任务

1. 在 `lua/orchestrate/core/actions.lua` 中添加新的 action 函数
2. 确保 action 是纯函数，通过 `store:update()` 修改状态
3. 如果需要新的状态字段，更新 `lua/orchestrate/core/store.lua` 的初始状态
4. 添加对应的测试到 `tests/run.lua`

## 必须遵守的架构原则

- Action 是纯状态转换函数
- 不允许在 action 中直接访问 UI
- 通过 `store:update(reducer)` 修改状态
- reducer 函数接收当前状态，返回新状态

## Action 模板

```lua
-- 在 lua/orchestrate/core/actions.lua 中添加

function Actions.my_new_action(store, payload)
  store:update(function(state)
    -- 修改状态
    -- state.xxx = payload.xxx

    -- 可选：添加消息记录
    -- table.insert(state.messages, {
    --   id = next_message_id("action", state.messages),
    --   kind = "my_action",
    --   role = "system",
    --   content = "Action executed",
    --   created_at = timestamp(),
    -- })

    return state
  end)
end
```

## 测试模板

```lua
-- 在 tests/run.lua 中添加

-- Test my_new_action
local store = Store.new()
Actions.my_new_action(store, { xxx = "value" })
assert_equal(store:get_state().xxx, "value", "my_new_action should update xxx")
```

## 常见 Action 模式

### 简单状态更新
```lua
function Actions.set_title(store, title)
  store:update(function(state)
    state.title = title
    return state
  end)
end
```

### 列表操作
```lua
function Actions.add_item(store, item)
  store:update(function(state)
    table.insert(state.items, vim.deepcopy(item))
    return state
  end)
end

function Actions.remove_item(store, item_id)
  store:update(function(state)
    for i, item in ipairs(state.items) do
      if item.id == item_id then
        table.remove(state.items, i)
        break
      end
    end
    return state
  end)
end
```

### 状态机转换
```lua
function Actions.transition_status(store, new_status)
  store:update(function(state)
    -- 验证状态转换是否合法
    local valid_transitions = {
      idle = { "connecting", "error" },
      connecting = { "streaming", "error", "idle" },
      streaming = { "idle", "error", "waiting_approval" },
    }

    local allowed = valid_transitions[state.status] or {}
    for _, status in ipairs(allowed) do
      if status == new_status then
        state.status = new_status
        break
      end
    end

    return state
  end)
end
```

## 参考

- 现有 actions: `lua/orchestrate/core/actions.lua`
- Store 实现: `lua/orchestrate/core/store.lua`
