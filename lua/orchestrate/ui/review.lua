local M = {}

local function get_unseen_reviews(session)
  local unseen = {}
  for _, review in ipairs(session.reviews or {}) do
    if not review.seen then
      table.insert(unseen, review)
    end
  end
  return unseen
end

local function get_all_reviews(session)
  return session.reviews or {}
end

function M.jump_to_review(review, on_seen)
  if not review.file then
    vim.notify("orchestrate.nvim: Review has no file location", vim.log.levels.WARN)
    return false
  end

  local file_path = review.file
  local line = review.line or 1
  local col = review.col or 0

  -- 检查文件是否存在
  if vim.fn.filereadable(file_path) ~= 1 then
    -- 尝试相对路径
    local cwd = vim.fn.getcwd()
    local full_path = cwd .. "/" .. file_path
    if vim.fn.filereadable(full_path) == 1 then
      file_path = full_path
    else
      vim.notify(
        string.format("orchestrate.nvim: File not found: %s", review.file),
        vim.log.levels.ERROR
      )
      return false
    end
  end

  -- 打开文件 (使用安全的 API 而非 vim.cmd)
  local bufnr = vim.fn.bufadd(file_path)
  vim.fn.bufload(bufnr)
  vim.api.nvim_set_current_buf(bufnr)

  -- 跳转到行号
  local ok = pcall(vim.api.nvim_win_set_cursor, 0, { line, col })
  if not ok then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end

  -- 居中显示 (使用 API 替代 normal! zz)
  local win_height = vim.api.nvim_win_get_height(0)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local top_line = math.max(1, cursor_line - math.floor(win_height / 2))
  pcall(vim.fn.winrestview, { topline = top_line })

  -- 标记为已读
  if on_seen and review.id then
    on_seen(review.id)
  end

  return true
end

function M.select_and_jump(session, on_seen)
  local reviews = get_all_reviews(session)

  if #reviews == 0 then
    vim.notify("orchestrate.nvim: No reviews available", vim.log.levels.INFO)
    return
  end

  vim.ui.select(reviews, {
    prompt = "Select review to jump to:",
    format_item = function(review)
      local status = review.seen and "[seen]" or "[new]"
      local title = review.title or "Untitled"
      local location = ""
      if review.file then
        location = string.format(" @ %s", review.file)
        if review.line then
          location = location .. ":" .. tostring(review.line)
        end
      end
      return string.format("%s %s%s", status, title, location)
    end,
  }, function(selected)
    if not selected then
      return
    end
    M.jump_to_review(selected, on_seen)
  end)
end

function M.jump_to_first_unseen(session, on_seen)
  local unseen = get_unseen_reviews(session)

  if #unseen == 0 then
    vim.notify("orchestrate.nvim: No unseen reviews", vim.log.levels.INFO)
    return false
  end

  return M.jump_to_review(unseen[1], on_seen)
end

function M.to_quickfix(session, on_seen_all)
  local reviews = get_all_reviews(session)

  if #reviews == 0 then
    vim.notify("orchestrate.nvim: No reviews to add to quickfix", vim.log.levels.INFO)
    return
  end

  local qf_items = {}
  for _, review in ipairs(reviews) do
    if review.file then
      table.insert(qf_items, {
        filename = review.file,
        lnum = review.line or 1,
        col = review.col or 0,
        text = string.format(
          "[%s] %s",
          review.severity or "info",
          review.title or review.message or "Review item"
        ),
        type = review.severity == "error" and "E" or review.severity == "warning" and "W" or "I",
      })
    end
  end

  if #qf_items == 0 then
    vim.notify("orchestrate.nvim: No reviews with file locations", vim.log.levels.WARN)
    return
  end

  vim.fn.setqflist(qf_items, "r")
  vim.fn.setqflist({}, "a", { title = "Orchestrate Reviews" })
  vim.cmd("copen")

  -- 标记所有为已读
  if on_seen_all then
    on_seen_all()
  end

  vim.notify(
    string.format("orchestrate.nvim: Added %d reviews to quickfix", #qf_items),
    vim.log.levels.INFO
  )
end

return M
