local M = {}

local defaults = {
  layout = {
    browse_width = 0.7,
    todo_height = 0.5,
    min_browse_width = 40,
    min_sidebar_height = 6,
  },
  ui = {
    input_filetype = "markdown",
  },
  session = {
    -- 是否自动保存会话
    auto_save = true,
    -- 是否在打开时自动恢复最近的会话
    auto_restore = false,
    -- 会话存储路径 (nil = 使用默认缓存目录)
    storage_path = nil,
  },
  transport = {
    name = "claude_code",
    claude_code = {
      -- command: path to claude CLI (nil = auto-detect)
      -- Auto-detection searches: PATH, Homebrew Cask, common locations
      command = nil,
      resume_strategy = "session_id",
      fallback_to_mock = false,
      model = nil,
      max_turns = nil,
      -- Permission settings
      -- allowed_tools: list of tools to auto-approve, e.g. {"Read", "Glob", "Grep", "Bash(git *)"}
      -- Use permission rule syntax: "Bash(git diff *)" allows commands starting with "git diff "
      allowed_tools = nil,
      -- permission_mode: "default" | "acceptEdits" | "bypassPermissions" | "auto" | "dontAsk"
      -- - default: tools not in allowed_tools will require approval
      -- - acceptEdits: auto-approve file edits (Edit, Write, mkdir, rm, etc.)
      -- - bypassPermissions: approve all tools (use with caution!)
      -- - auto: let Claude decide based on context
      -- - dontAsk: deny any tool not explicitly allowed
      permission_mode = "acceptEdits",
      -- interactive_permissions: enable interactive permission popup via hook
      -- When true, a popup will appear for each permission request (EXPERIMENTAL)
      -- When false, permissions are handled by permission_mode and allowed_tools
      -- Note: This feature is currently not working reliably due to Claude Code CLI
      -- limitations with --settings flag not merging hooks properly.
      -- Recommended to keep this false and use permission_mode instead.
      interactive_permissions = false,
    },
  },
  debug = {
    enabled = false,
    log_level = "INFO",
    to_file = false,
  },
  mock = {
    chunk_delay = 160,
  },
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
