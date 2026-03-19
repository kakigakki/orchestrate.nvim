local M = {}

local LEVELS = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

local level_names = {
  [1] = "DEBUG",
  [2] = "INFO",
  [3] = "WARN",
  [4] = "ERROR",
}

local config = {
  enabled = false,
  level = LEVELS.INFO,
  to_file = false,
  file_path = nil,
}

-- 敏感数据模式列表 (用于过滤)
local SENSITIVE_PATTERNS = {
  -- API keys
  { pattern = "sk%-[a-zA-Z0-9%-_]+", replacement = "[REDACTED_API_KEY]" },
  { pattern = "api[_%-]?key[=:\"'%s]+[a-zA-Z0-9%-_]+", replacement = "api_key=[REDACTED]" },
  -- Tokens
  { pattern = "token[=:\"'%s]+[a-zA-Z0-9%-_%.]+", replacement = "token=[REDACTED]" },
  { pattern = "bearer%s+[a-zA-Z0-9%-_%.]+", replacement = "bearer [REDACTED]" },
  -- Passwords
  { pattern = "password[=:\"'%s]+[^%s\"']+", replacement = "password=[REDACTED]" },
  { pattern = "secret[=:\"'%s]+[^%s\"']+", replacement = "secret=[REDACTED]" },
  -- Session IDs (保留前几个字符用于调试)
  {
    pattern = "(session[_%-]?id[=:\"'%s]+)([a-zA-Z0-9%-_]+)",
    replacement = "%1[REDACTED_SESSION]",
  },
}

local function sanitize_message(msg)
  if type(msg) ~= "string" then
    return msg
  end
  local sanitized = msg
  for _, item in ipairs(SENSITIVE_PATTERNS) do
    sanitized = sanitized:gsub(item.pattern, item.replacement)
  end
  return sanitized
end

local function get_log_path()
  if config.file_path then
    return config.file_path
  end
  local cache_dir = vim.fn.stdpath("cache")
  return cache_dir .. "/orchestrate.log"
end

local function format_message(level, msg, ...)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local level_name = level_names[level] or "UNKNOWN"
  local formatted = string.format(msg, ...)
  -- 过滤敏感数据
  formatted = sanitize_message(formatted)
  return string.format("[%s] [%s] %s", timestamp, level_name, formatted)
end

local function write_log(level, msg, ...)
  if not config.enabled then
    return
  end

  if level < config.level then
    return
  end

  local formatted = format_message(level, msg, ...)

  if config.to_file then
    local file = io.open(get_log_path(), "a")
    if file then
      file:write(formatted .. "\n")
      file:close()
    end
  else
    local vim_level = vim.log.levels.INFO
    if level == LEVELS.DEBUG then
      vim_level = vim.log.levels.DEBUG
    elseif level == LEVELS.WARN then
      vim_level = vim.log.levels.WARN
    elseif level == LEVELS.ERROR then
      vim_level = vim.log.levels.ERROR
    end
    -- 使用 vim.schedule 确保在主线程调用 vim.notify
    -- 避免在 libuv callback 中调用时报错
    vim.schedule(function()
      vim.notify(formatted, vim_level)
    end)
  end
end

function M.setup(opts)
  opts = opts or {}
  config.enabled = opts.enabled or false
  config.to_file = opts.to_file or false
  config.file_path = opts.file_path

  if opts.level then
    if type(opts.level) == "string" then
      config.level = LEVELS[opts.level:upper()] or LEVELS.INFO
    else
      config.level = opts.level
    end
  end
end

function M.debug(msg, ...)
  write_log(LEVELS.DEBUG, msg, ...)
end

function M.info(msg, ...)
  write_log(LEVELS.INFO, msg, ...)
end

function M.warn(msg, ...)
  write_log(LEVELS.WARN, msg, ...)
end

function M.error(msg, ...)
  write_log(LEVELS.ERROR, msg, ...)
end

function M.is_enabled()
  return config.enabled
end

function M.get_log_path()
  return get_log_path()
end

-- 导出 sanitize 函数供外部使用/测试
function M.sanitize(msg)
  return sanitize_message(msg)
end

M.LEVELS = LEVELS

return M
