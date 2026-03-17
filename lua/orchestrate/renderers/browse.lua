local M = {}

local function append_wrapped(lines, text)
  local chunks = vim.split(text or "", "\n", { plain = true })
  if #chunks == 0 then
    table.insert(lines, "")
    return
  end

  for _, chunk in ipairs(chunks) do
    table.insert(lines, chunk)
  end
end

function M.render(session, bufnr)
  local lines = {
    "ORCHESTRATE / BROWSE",
    string.rep("=", 32),
    string.format("session: %s", session.id),
    string.format("status: %s", session.status),
    string.format("transport: %s", (session.meta and session.meta.transport) or "unknown"),
    string.format("transport_session_id: %s", (session.meta and session.meta.transport_session_id) or "-"),
    "",
  }

  for _, message in ipairs(session.messages) do
    local header = string.format("[%s] %s", message.created_at or "--:--:--", message.kind)
    table.insert(lines, header)

    if message.title and message.title ~= "" then
      table.insert(lines, "title: " .. message.title)
    end

    append_wrapped(lines, message.content or "")

    if message.streaming then
      table.insert(lines, "[streaming]")
    end

    table.insert(lines, "")
  end

  if #session.messages == 0 then
    table.insert(lines, "No events yet. Type into the Input buffer and use :w to send.")
  end

  if session.meta and session.meta.last_error and session.meta.last_error.message then
    table.insert(lines, "")
    table.insert(lines, "LAST ERROR")
    table.insert(lines, session.meta.last_error.message)
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

return M
