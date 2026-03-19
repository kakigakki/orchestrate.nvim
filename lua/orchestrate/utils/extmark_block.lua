-- ExtmarkBlock utility for rendering tool call blocks with decorations
-- Inspired by Agentic.nvim's ExtmarkBlock

local M = {}

local GLYPHS = {
  TOP_LEFT = "╭",
  BOTTOM_LEFT = "╰",
  HORIZONTAL = "─",
  VERTICAL = "│",
}

--- Renders a complete block with header, optional body, and optional footer
--- @param bufnr integer
--- @param ns_id integer
--- @param opts table {header_line, body_start?, body_end?, footer_line?, hl_group}
--- @return integer[] decoration_ids
function M.render_block(bufnr, ns_id, opts)
  local decoration_ids = {}

  -- Header decoration: ╭─
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, opts.header_line, 0, {
    virt_text = {
      { GLYPHS.TOP_LEFT .. GLYPHS.HORIZONTAL .. " ", opts.hl_group },
    },
    virt_text_pos = "inline",
    hl_mode = "combine",
  })
  if ok then
    table.insert(decoration_ids, id)
  end

  -- Body pipe padding: │
  if opts.body_start and opts.body_end then
    for line_num = opts.body_start, opts.body_end do
      ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_num, 0, {
        virt_text = { { GLYPHS.VERTICAL .. " ", opts.hl_group } },
        virt_text_pos = "inline",
        hl_mode = "combine",
      })
      if ok then
        table.insert(decoration_ids, id)
      end
    end
  end

  -- Footer decoration: ╰─
  if opts.footer_line then
    ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, opts.footer_line, 0, {
      virt_text = {
        { GLYPHS.BOTTOM_LEFT .. GLYPHS.HORIZONTAL .. " ", opts.hl_group },
      },
      virt_text_pos = "inline",
      hl_mode = "combine",
    })
    if ok then
      table.insert(decoration_ids, id)
    end
  end

  return decoration_ids
end

return M
