local M = {}

-- 记录已经 allow all 的工具
local allowed_all_tools = {}

local function get_pending_approvals(session)
  local pending = {}
  for _, approval in ipairs(session.approvals or {}) do
    if not approval.resolved then
      table.insert(pending, approval)
    end
  end
  return pending
end

function M.select_and_resolve(session, on_resolve)
  local pending = get_pending_approvals(session)

  if #pending == 0 then
    vim.notify("orchestrate.nvim: No pending approvals", vim.log.levels.INFO)
    return
  end

  -- 如果只有一个待审批项，直接显示决策选项
  if #pending == 1 then
    M.show_decision(pending[1], on_resolve)
    return
  end

  -- 多个待审批项，先选择哪一个
  vim.ui.select(pending, {
    prompt = "Select approval to review:",
    format_item = function(approval)
      local title = approval.title or "Untitled"
      local desc = approval.description and (" - " .. approval.description:sub(1, 40)) or ""
      return title .. desc
    end,
  }, function(selected)
    if not selected then
      return
    end
    M.show_decision(selected, on_resolve)
  end)
end

function M.show_decision(approval, on_resolve)
  local title = approval.title or "Untitled"
  local prompt_lines = { "Approval: " .. title }

  if approval.description then
    table.insert(prompt_lines, "")
    table.insert(prompt_lines, approval.description)
  end

  if approval.command then
    table.insert(prompt_lines, "")
    table.insert(prompt_lines, "Command: " .. approval.command)
  end

  local prompt = table.concat(prompt_lines, "\n")

  vim.ui.select({ "Accept", "Reject", "Cancel" }, {
    prompt = prompt .. "\n\nDecision:",
  }, function(choice)
    if not choice or choice == "Cancel" then
      return
    end

    local decision = choice == "Accept" and "accept" or "reject"
    if on_resolve then
      on_resolve(approval.id, decision)
    end
  end)
end

function M.approve_first(session, on_resolve)
  local pending = get_pending_approvals(session)

  if #pending == 0 then
    vim.notify("orchestrate.nvim: No pending approvals", vim.log.levels.INFO)
    return
  end

  local first = pending[1]
  if on_resolve then
    on_resolve(first.id, "accept")
  end
  vim.notify(
    string.format("orchestrate.nvim: Approved '%s'", first.title or "Untitled"),
    vim.log.levels.INFO
  )
end

function M.reject_first(session, on_resolve)
  local pending = get_pending_approvals(session)

  if #pending == 0 then
    vim.notify("orchestrate.nvim: No pending approvals", vim.log.levels.INFO)
    return
  end

  local first = pending[1]
  if on_resolve then
    on_resolve(first.id, "reject")
  end
  vim.notify(
    string.format("orchestrate.nvim: Rejected '%s'", first.title or "Untitled"),
    vim.log.levels.INFO
  )
end

-- 检查工具是否已被 allow all
function M.is_tool_allowed_all(tool_name)
  return allowed_all_tools[tool_name] == true
end

-- 重置 allow all 状态
function M.reset_allowed_all()
  allowed_all_tools = {}
end

-- 强制弹出的授权弹窗 (用于权限请求时立即显示)
function M.show_forced_popup(approval, on_resolve)
  local tool_name = approval.tool_name or "Unknown"

  -- 如果该工具已经被 allow all，直接通过
  if allowed_all_tools[tool_name] then
    if on_resolve then
      on_resolve(approval.id, "accept")
    end
    return
  end

  -- 构建显示内容
  local content_lines = {}

  -- 命令或输入内容
  local detail = ""
  if approval.command then
    detail = approval.command
  elseif approval.input then
    if type(approval.input) == "string" then
      detail = approval.input
    elseif type(approval.input) == "table" then
      -- 尝试提取常见字段
      detail = approval.input.command
        or approval.input.file_path
        or approval.input.pattern
        or (vim.json and vim.json.encode(approval.input))
        or vim.inspect(approval.input)
    end
  end

  -- 截断过长的内容并分行显示
  local max_width = 56
  if detail and #detail > 0 then
    -- 分行处理长内容
    local remaining = detail
    while #remaining > 0 do
      local line = remaining:sub(1, max_width)
      remaining = remaining:sub(max_width + 1)
      table.insert(content_lines, line)
      if #content_lines >= 6 then
        -- 最多显示 6 行
        if #remaining > 0 then
          content_lines[#content_lines] = content_lines[#content_lines]:sub(1, max_width - 3) .. "..."
        end
        break
      end
    end
  end

  -- 构建 UI 行
  local lines = {}
  local hl_ranges = {} -- 存储高亮信息 {line, col_start, col_end, hl_group}

  -- 标题
  table.insert(lines, "")
  table.insert(lines, "  ╭─────────────────────────────────────────────────────────────╮")
  table.insert(lines, "  │                    🔐 Permission Request                    │")
  table.insert(lines, "  ├─────────────────────────────────────────────────────────────┤")

  -- 工具名称
  local tool_display = string.format("  │  Tool: %-54s │", tool_name)
  table.insert(lines, tool_display)
  table.insert(hl_ranges, { #lines, 10, 10 + #tool_name, "OrchestrateToolName" })

  -- 分隔线
  table.insert(lines, "  │                                                             │")

  -- 内容
  if #content_lines > 0 then
    for _, content_line in ipairs(content_lines) do
      local padded = string.format("  │  %-59s │", content_line)
      table.insert(lines, padded)
    end
  else
    table.insert(lines, "  │  (no details)                                              │")
  end

  -- 选项区域
  table.insert(lines, "  │                                                             │")
  table.insert(lines, "  ├─────────────────────────────────────────────────────────────┤")
  table.insert(lines, "  │                                                             │")

  -- 选项
  local opt1_line = #lines + 1
  table.insert(lines, "  │    [1]  Allow                                               │")
  table.insert(hl_ranges, { opt1_line, 6, 9, "OrchestrateOptionKey" })
  table.insert(hl_ranges, { opt1_line, 11, 16, "OrchestrateOptionAllow" })

  local opt2_line = #lines + 1
  table.insert(lines, "  │    [2]  Allow All (this tool)                               │")
  table.insert(hl_ranges, { opt2_line, 6, 9, "OrchestrateOptionKey" })
  table.insert(hl_ranges, { opt2_line, 11, 31, "OrchestrateOptionAllowAll" })

  local opt3_line = #lines + 1
  table.insert(lines, "  │    [3]  Reject                                              │")
  table.insert(hl_ranges, { opt3_line, 6, 9, "OrchestrateOptionKey" })
  table.insert(hl_ranges, { opt3_line, 11, 17, "OrchestrateOptionReject" })

  table.insert(lines, "  │                                                             │")
  table.insert(lines, "  ╰─────────────────────────────────────────────────────────────╯")
  table.insert(lines, "")

  -- 计算窗口尺寸和位置
  local width = 67
  local height = #lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- 创建 buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"

  -- 创建浮动窗口
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "none",
    zindex = 100,
  })

  -- 设置高亮组
  vim.api.nvim_set_hl(0, "OrchestrateApprovalNormal", { fg = "#cdd6f4", bg = "#1e1e2e" })
  vim.api.nvim_set_hl(0, "OrchestrateApprovalBorder", { fg = "#89b4fa", bg = "#1e1e2e" })
  vim.api.nvim_set_hl(0, "OrchestrateToolName", { fg = "#f9e2af", bg = "#1e1e2e", bold = true })
  vim.api.nvim_set_hl(0, "OrchestrateOptionKey", { fg = "#89b4fa", bg = "#1e1e2e", bold = true })
  vim.api.nvim_set_hl(0, "OrchestrateOptionAllow", { fg = "#a6e3a1", bg = "#1e1e2e", bold = true })
  vim.api.nvim_set_hl(0, "OrchestrateOptionAllowAll", { fg = "#94e2d5", bg = "#1e1e2e", bold = true })
  vim.api.nvim_set_hl(0, "OrchestrateOptionReject", { fg = "#f38ba8", bg = "#1e1e2e", bold = true })

  vim.wo[win].winhl = "Normal:OrchestrateApprovalNormal"

  -- 应用高亮
  local ns = vim.api.nvim_create_namespace("orchestrate_approval")
  for _, hl in ipairs(hl_ranges) do
    local line_num, col_start, col_end, hl_group = hl[1], hl[2], hl[3], hl[4]
    vim.api.nvim_buf_add_highlight(buf, ns, hl_group, line_num - 1, col_start, col_end)
  end

  -- 关闭并返回结果的函数
  local function close_and_resolve(decision, allow_all)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end

    -- 如果选择了 allow all，记录该工具
    if allow_all and tool_name then
      allowed_all_tools[tool_name] = true
    end

    if on_resolve and decision then
      on_resolve(approval.id, decision)
    end
  end

  -- 设置按键映射 (直接响应，不需要进入 insert 模式)
  local opts = { buffer = buf, nowait = true, noremap = true, silent = true }

  -- 数字键选择
  vim.keymap.set({ "n", "i" }, "1", function()
    close_and_resolve("accept", false)
  end, opts)

  vim.keymap.set({ "n", "i" }, "2", function()
    close_and_resolve("accept", true) -- allow all
  end, opts)

  vim.keymap.set({ "n", "i" }, "3", function()
    close_and_resolve("reject", false)
  end, opts)

  -- 兼容旧的 y/n 快捷键
  vim.keymap.set({ "n", "i" }, "y", function()
    close_and_resolve("accept", false)
  end, opts)

  vim.keymap.set({ "n", "i" }, "Y", function()
    close_and_resolve("accept", true) -- Y = allow all
  end, opts)

  vim.keymap.set({ "n", "i" }, "n", function()
    close_and_resolve("reject", false)
  end, opts)

  vim.keymap.set({ "n", "i" }, "N", function()
    close_and_resolve("reject", false)
  end, opts)

  -- 取消/关闭
  vim.keymap.set({ "n", "i" }, "<Esc>", function()
    close_and_resolve("reject", false) -- Esc = reject
  end, opts)

  vim.keymap.set({ "n", "i" }, "q", function()
    close_and_resolve("reject", false)
  end, opts)

  -- 禁用其他按键，防止误操作
  vim.keymap.set({ "n", "i" }, "<CR>", function() end, opts)

  -- 聚焦到弹窗
  vim.api.nvim_set_current_win(win)
end

return M
