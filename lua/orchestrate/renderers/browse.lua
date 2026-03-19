-- Browse renderer - displays chat history with tool calls
-- Inspired by Agentic.nvim's message_writer.lua

local ExtmarkBlock = require("orchestrate.utils.extmark_block")

local M = {}

-- Namespaces for different types of highlights
local NS_CONTENT = vim.api.nvim_create_namespace("orchestrate_content")
local NS_DECORATIONS = vim.api.nvim_create_namespace("orchestrate_decorations")
local NS_STATUS = vim.api.nvim_create_namespace("orchestrate_status")

-- Highlight groups (similar to Agentic's Theme)
local HL_GROUPS = {
  -- Message headers
  USER_HEADER = "OrchestrateUserHeader",
  USER_TIMESTAMP = "OrchestrateUserTimestamp",
  ASSISTANT_HEADER = "OrchestrateAssistantHeader",
  ASSISTANT_TIMESTAMP = "OrchestrateAssistantTimestamp",
  -- Tool type headers (different colors per tool type)
  TOOL_READ = "OrchestrateToolRead",
  TOOL_EDIT = "OrchestrateToolEdit",
  TOOL_WRITE = "OrchestrateToolWrite",
  TOOL_EXECUTE = "OrchestrateToolExecute",
  TOOL_SEARCH = "OrchestrateToolSearch",
  TOOL_TASK = "OrchestrateToolTask",
  TOOL_DEFAULT = "OrchestrateToolDefault",
  -- Tool body by status
  BODY_PENDING = "OrchestrateBodyPending",
  BODY_COMPLETED = "OrchestrateBodyCompleted",
  BODY_FAILED = "OrchestrateBodyFailed",
  -- Status badges
  STATUS_PENDING = "OrchestrateStatusPending",
  STATUS_COMPLETED = "OrchestrateStatusCompleted",
  STATUS_FAILED = "OrchestrateStatusFailed",
  -- Block decorations by status
  FENCE_PENDING = "OrchestrateFencePending",
  FENCE_COMPLETED = "OrchestrateFenceCompleted",
  FENCE_FAILED = "OrchestrateFenceFailed",
  -- TODO highlights
  TODO_HEADER = "OrchestrateTodoHeader",
  TODO_PENDING = "OrchestrateTodoPending",
  TODO_IN_PROGRESS = "OrchestrateTodoInProgress",
  TODO_COMPLETED = "OrchestrateTodoCompleted",
}

-- Setup highlight groups
local function setup_highlights()
  -- Message headers
  vim.api.nvim_set_hl(0, HL_GROUPS.USER_HEADER, { fg = "#74c7ec", bold = true }) -- Sapphire - You
  vim.api.nvim_set_hl(0, HL_GROUPS.USER_TIMESTAMP, { fg = "#6c7086" }) -- Overlay0 - muted
  vim.api.nvim_set_hl(0, HL_GROUPS.ASSISTANT_HEADER, { fg = "#cba6f7", bold = true }) -- Mauve - Claude
  vim.api.nvim_set_hl(0, HL_GROUPS.ASSISTANT_TIMESTAMP, { fg = "#6c7086" }) -- Overlay0 - muted

  -- Tool type headers (different colors per tool type)
  vim.api.nvim_set_hl(0, HL_GROUPS.TOOL_READ, { fg = "#89b4fa", bold = true }) -- Blue - read operations
  vim.api.nvim_set_hl(0, HL_GROUPS.TOOL_EDIT, { fg = "#f9e2af", bold = true }) -- Yellow - edit operations
  vim.api.nvim_set_hl(0, HL_GROUPS.TOOL_WRITE, { fg = "#fab387", bold = true }) -- Orange - write operations
  vim.api.nvim_set_hl(0, HL_GROUPS.TOOL_EXECUTE, { fg = "#cba6f7", bold = true }) -- Purple - execute/bash
  vim.api.nvim_set_hl(0, HL_GROUPS.TOOL_SEARCH, { fg = "#94e2d5", bold = true }) -- Teal - search operations
  vim.api.nvim_set_hl(0, HL_GROUPS.TOOL_TASK, { fg = "#f5c2e7", bold = true }) -- Pink - task/agent
  vim.api.nvim_set_hl(0, HL_GROUPS.TOOL_DEFAULT, { fg = "#cdd6f4", bold = true }) -- White - default

  -- Tool body by status (muted colors)
  vim.api.nvim_set_hl(0, HL_GROUPS.BODY_PENDING, { fg = "#9399b2" }) -- Gray - pending
  vim.api.nvim_set_hl(0, HL_GROUPS.BODY_COMPLETED, { fg = "#6c7086" }) -- Darker gray - completed
  vim.api.nvim_set_hl(0, HL_GROUPS.BODY_FAILED, { fg = "#f38ba8" }) -- Red tint - failed

  -- Status badges with backgrounds
  vim.api.nvim_set_hl(0, HL_GROUPS.STATUS_PENDING, { bg = "#45475a", fg = "#cdd6f4" }) -- Gray bg
  vim.api.nvim_set_hl(0, HL_GROUPS.STATUS_COMPLETED, { bg = "#2d5a3d", fg = "#a6e3a1" }) -- Green bg
  vim.api.nvim_set_hl(0, HL_GROUPS.STATUS_FAILED, { bg = "#7a2d2d", fg = "#f38ba8" }) -- Red bg

  -- Block decorations (╭│╰) by status
  vim.api.nvim_set_hl(0, HL_GROUPS.FENCE_PENDING, { fg = "#585b70" }) -- Gray
  vim.api.nvim_set_hl(0, HL_GROUPS.FENCE_COMPLETED, { fg = "#a6e3a1" }) -- Green
  vim.api.nvim_set_hl(0, HL_GROUPS.FENCE_FAILED, { fg = "#f38ba8" }) -- Red

  -- TODO highlights
  vim.api.nvim_set_hl(0, HL_GROUPS.TODO_HEADER, { fg = "#fab387", bold = true })
  vim.api.nvim_set_hl(0, HL_GROUPS.TODO_PENDING, { fg = "#9399b2" })
  vim.api.nvim_set_hl(0, HL_GROUPS.TODO_IN_PROGRESS, { fg = "#f9e2af", bold = true })
  vim.api.nvim_set_hl(0, HL_GROUPS.TODO_COMPLETED, { fg = "#a6e3a1" })
end

-- Truncate text to max lines
local function truncate_text(text, max_lines)
  max_lines = max_lines or 10
  local text_lines = vim.split(text or "", "\n", { plain = true })
  if #text_lines <= max_lines then
    return text_lines, false
  end
  local truncated = {}
  for i = 1, max_lines do
    table.insert(truncated, text_lines[i])
  end
  return truncated, true
end

-- Tool type categories
local TOOL_CATEGORIES = {
  -- Read operations
  Read = "read",
  Glob = "read",
  -- Edit operations
  Edit = "edit",
  -- Write operations
  Write = "write",
  NotebookEdit = "write",
  -- Execute operations
  Bash = "execute",
  -- Search operations
  Grep = "search",
  WebFetch = "search",
  WebSearch = "search",
  -- Task/Agent operations
  Task = "task",
  TodoWrite = "task",
}

-- Get highlight group for tool type
local function get_tool_header_hl(tool_name)
  local category = TOOL_CATEGORIES[tool_name]
  if category == "read" then
    return HL_GROUPS.TOOL_READ
  elseif category == "edit" then
    return HL_GROUPS.TOOL_EDIT
  elseif category == "write" then
    return HL_GROUPS.TOOL_WRITE
  elseif category == "execute" then
    return HL_GROUPS.TOOL_EXECUTE
  elseif category == "search" then
    return HL_GROUPS.TOOL_SEARCH
  elseif category == "task" then
    return HL_GROUPS.TOOL_TASK
  else
    return HL_GROUPS.TOOL_DEFAULT
  end
end

-- Get highlight groups for status
local function get_status_highlights(status)
  if status == "completed" then
    return HL_GROUPS.BODY_COMPLETED, HL_GROUPS.FENCE_COMPLETED, HL_GROUPS.STATUS_COMPLETED
  elseif status == "failed" then
    return HL_GROUPS.BODY_FAILED, HL_GROUPS.FENCE_FAILED, HL_GROUPS.STATUS_FAILED
  else
    return HL_GROUPS.BODY_PENDING, HL_GROUPS.FENCE_PENDING, HL_GROUPS.STATUS_PENDING
  end
end

-- Format tool name for display
local function format_tool_name(name)
  local mapping = {
    Read = "read",
    Bash = "execute",
    Edit = "edit",
    Write = "write",
    Glob = "glob",
    Grep = "grep",
    WebFetch = "fetch",
    WebSearch = "search",
    Task = "task",
    TodoWrite = "todo",
  }
  return mapping[name] or string.lower(name or "tool")
end

-- Format timestamp (handles both number and string formats)
local function format_timestamp(ts)
  if not ts then
    return ""
  end
  -- If already a string (legacy format), return as-is
  if type(ts) == "string" then
    return ts
  end
  -- If number, format it
  if type(ts) == "number" then
    return os.date("%H:%M:%S", ts)
  end
  return ""
end

-- Format tool parameter
local function format_tool_param(input)
  if type(input) == "string" then
    local param = input:gsub("\n", " ")
    if #param > 50 then
      return param:sub(1, 47) .. "..."
    end
    return param
  elseif type(input) == "table" then
    if input.file_path then
      return input.file_path
    elseif input.command then
      local cmd = input.command:gsub("\n", " ")
      if #cmd > 50 then
        return cmd:sub(1, 47) .. "..."
      end
      return cmd
    elseif input.pattern then
      return input.pattern
    elseif input.query then
      return input.query
    end
  end
  return ""
end

function M.render(session, bufnr)
  setup_highlights()

  -- Clear all namespaces first
  vim.api.nvim_buf_clear_namespace(bufnr, NS_CONTENT, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, NS_DECORATIONS, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, NS_STATUS, 0, -1)

  local lines = {}
  local tool_blocks = {} -- Track tool blocks for highlighting
  local message_headers = {} -- Track message headers for highlighting

  -- Status header
  local status_text = session.status or "idle"
  table.insert(lines, status_text)
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "")

  -- Messages
  for _, message in ipairs(session.messages) do
    if message.kind == "user_submit" then
      -- User message with timestamp
      local msg_header_line = #lines
      local ts = format_timestamp(message.created_at)
      local header_text = "You"
      if ts ~= "" then
        header_text = header_text .. " · " .. ts
      end
      table.insert(lines, header_text)
      table.insert(message_headers, {
        line = msg_header_line,
        kind = "user",
        name_len = 3, -- "You"
        timestamp_start = ts ~= "" and 4 or nil, -- after "You"
      })

      if message.content and message.content ~= "" then
        for _, line in ipairs(vim.split(message.content, "\n", { plain = true })) do
          table.insert(lines, line)
        end
      end
      table.insert(lines, "")

    elseif message.kind == "assistant_stream" then
      -- Assistant message with timestamp
      local msg_header_line = #lines
      local ts = format_timestamp(message.created_at)
      local header_text = "Claude"
      if ts ~= "" then
        header_text = header_text .. " · " .. ts
      end
      table.insert(lines, header_text)
      table.insert(message_headers, {
        line = msg_header_line,
        kind = "assistant",
        name_len = 6, -- "Claude"
        timestamp_start = ts ~= "" and 7 or nil, -- after "Claude"
      })

      -- Tool calls
      if message.blocks and #message.blocks > 0 then
        for _, block in ipairs(message.blocks) do
          if block.type == "thinking" then
            if block.streaming then
              table.insert(lines, "thinking...")
            elseif block.content and block.content ~= "" then
              local preview = block.content:gsub("\n", " "):sub(1, 60)
              if #block.content > 60 then
                preview = preview .. "..."
              end
              table.insert(lines, "thought: " .. preview)
            end
          elseif block.type == "tool_use" then
            local tool_name = format_tool_name(block.tool_name)
            local tool_param = format_tool_param(block.input)

            -- Record block start (0-based line number)
            local header_line = #lines

            -- Tool header
            table.insert(lines, string.format("%s(%s)", tool_name, tool_param))

            -- Tool result
            local body_start = #lines
            local has_body = false
            if block.result then
              local result_lines, was_truncated = truncate_text(block.result, 8)
              for _, rline in ipairs(result_lines) do
                table.insert(lines, rline)
                has_body = true
              end
              if was_truncated then
                table.insert(lines, "... (truncated)")
              end
            elseif block.streaming then
              table.insert(lines, "running...")
              has_body = true
            end
            local body_end = #lines - 1

            -- Status
            local status = "pending"
            if block.result then
              status = block.is_error and "failed" or "completed"
            elseif block.streaming then
              status = "running"
            end

            -- Footer line for status
            local footer_line = #lines
            table.insert(lines, status)

            -- Track this tool block
            table.insert(tool_blocks, {
              header_line = header_line,
              body_start = has_body and body_start or nil,
              body_end = has_body and body_end or nil,
              footer_line = footer_line,
              status = status,
              tool_name = block.tool_name, -- Keep original tool name for coloring
            })

            -- Empty line after block
            table.insert(lines, "")
          end
        end
      end

      -- Main text content (markdown - highlighted by treesitter)
      if message.content and message.content ~= "" then
        for _, line in ipairs(vim.split(message.content, "\n", { plain = true })) do
          table.insert(lines, line)
        end
      end

      if message.streaming then
        table.insert(lines, "▌")
      end

      -- Stats
      if message.cost_usd or message.duration_ms then
        local stats = {}
        if message.cost_usd then
          table.insert(stats, string.format("$%.4f", message.cost_usd))
        end
        if message.duration_ms then
          table.insert(stats, string.format("%.1fs", message.duration_ms / 1000))
        end
        if #stats > 0 then
          table.insert(lines, "(" .. table.concat(stats, " · ") .. ")")
        end
      end
      table.insert(lines, "")

    elseif message.kind == "error" then
      table.insert(lines, "Error: " .. (message.content or "Unknown error"))
      table.insert(lines, "")
    end
  end

  if #session.messages == 0 then
    table.insert(lines, "")
    table.insert(lines, "No messages yet. Type in the Input buffer and press :w to send.")
  end

  -- TODO section
  local todo_header_line = nil
  if session.todos and #session.todos > 0 then
    table.insert(lines, "")
    table.insert(lines, string.rep("═", 50))
    todo_header_line = #lines
    table.insert(lines, string.format("Tasks (%d)", #session.todos))
    table.insert(lines, "")

    for i, todo in ipairs(session.todos) do
      local icon = "○"
      if todo.status == "completed" then
        icon = "●"
      elseif todo.status == "in_progress" then
        icon = "◐"
      end
      table.insert(lines, string.format("%s %d. %s", icon, i, todo.content or todo.activeForm or ""))
    end
  end

  -- Update buffer
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply highlights for tool blocks with high priority to override treesitter
  local HIGH_PRIORITY = 200 -- Higher than treesitter's default (100)

  -- Message headers (You/Claude with timestamps)
  for _, header in ipairs(message_headers) do
    local line_content = lines[header.line + 1] or ""
    if header.kind == "user" then
      -- "You" part
      pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, header.line, 0, {
        end_col = header.name_len,
        hl_group = HL_GROUPS.USER_HEADER,
        priority = HIGH_PRIORITY,
      })
      -- Timestamp part (if exists)
      if header.timestamp_start and #line_content > header.timestamp_start then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, header.line, header.timestamp_start, {
          end_col = #line_content,
          hl_group = HL_GROUPS.USER_TIMESTAMP,
          priority = HIGH_PRIORITY,
        })
      end
    else
      -- "Claude" part
      pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, header.line, 0, {
        end_col = header.name_len,
        hl_group = HL_GROUPS.ASSISTANT_HEADER,
        priority = HIGH_PRIORITY,
      })
      -- Timestamp part (if exists)
      if header.timestamp_start and #line_content > header.timestamp_start then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, header.line, header.timestamp_start, {
          end_col = #line_content,
          hl_group = HL_GROUPS.ASSISTANT_TIMESTAMP,
          priority = HIGH_PRIORITY,
        })
      end
    end
  end

  -- Tool blocks
  for _, block in ipairs(tool_blocks) do
    -- Get colors based on tool type and status
    local header_hl = get_tool_header_hl(block.tool_name)
    local body_hl, fence_hl, status_hl = get_status_highlights(block.status)

    -- Header highlight (colored by tool type)
    local header_content = lines[block.header_line + 1] or ""
    if #header_content > 0 then
      pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, block.header_line, 0, {
        end_col = #header_content,
        hl_group = header_hl,
        priority = HIGH_PRIORITY,
      })
    end

    -- Body content highlight (colored by status)
    if block.body_start and block.body_end then
      for line_num = block.body_start, block.body_end do
        local line_content = lines[line_num + 1] or ""
        if #line_content > 0 then
          pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, line_num, 0, {
            end_col = #line_content,
            hl_group = body_hl,
            priority = HIGH_PRIORITY,
          })
        end
      end
    end

    -- Footer line highlight (same as body)
    local footer_content = lines[block.footer_line + 1] or ""
    if #footer_content > 0 then
      pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, block.footer_line, 0, {
        end_col = #footer_content,
        hl_group = body_hl,
        priority = HIGH_PRIORITY,
      })
    end

    -- Block decorations (╭─, │, ╰─) colored by status
    ExtmarkBlock.render_block(bufnr, NS_DECORATIONS, {
      header_line = block.header_line,
      body_start = block.body_start,
      body_end = block.body_end,
      footer_line = block.footer_line,
      hl_group = fence_hl,
    })

    -- Status overlay with badge
    local status_icons = {
      pending = "⟳",
      running = "⟳",
      completed = "✓",
      failed = "✗",
    }
    local status_icon = status_icons[block.status] or "?"
    pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_STATUS, block.footer_line, 0, {
      virt_text = { { string.format(" %s %s ", status_icon, block.status), status_hl } },
      virt_text_pos = "overlay",
      priority = HIGH_PRIORITY + 10,
    })
  end

  -- TODO highlights (also with high priority)
  local HIGH_PRIORITY = 200
  if todo_header_line and session.todos then
    -- Separator line
    pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, todo_header_line - 1, 0, {
      end_col = #lines[todo_header_line],
      hl_group = "Comment",
      priority = HIGH_PRIORITY,
    })
    -- Header
    pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, todo_header_line, 0, {
      end_col = #lines[todo_header_line + 1],
      hl_group = HL_GROUPS.TODO_HEADER,
      priority = HIGH_PRIORITY,
    })
    -- Items
    for i, todo in ipairs(session.todos) do
      local line_num = todo_header_line + 1 + i
      local hl_group = HL_GROUPS.TODO_PENDING
      if todo.status == "completed" then
        hl_group = HL_GROUPS.TODO_COMPLETED
      elseif todo.status == "in_progress" then
        hl_group = HL_GROUPS.TODO_IN_PROGRESS
      end
      local line_content = lines[line_num + 1] or ""
      if #line_content > 0 then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, NS_CONTENT, line_num, 0, {
          end_col = #line_content,
          hl_group = hl_group,
          priority = HIGH_PRIORITY,
        })
      end
    end
  end

  vim.bo[bufnr].modifiable = false

  -- Auto scroll to bottom
  local line_count = #lines
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
    end
  end
end

return M
