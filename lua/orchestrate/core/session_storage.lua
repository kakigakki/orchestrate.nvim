local M = {}

local Config = require("orchestrate.config")
local Logger = require("orchestrate.utils.logger")

--- 获取项目文件夹名称（基于 cwd）
--- @return string
local function get_project_folder()
  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  -- 规范化路径：替换斜杠、空格、冒号为下划线
  local normalized = cwd:gsub("[/\\%s:]", "_"):gsub("^_+", "")
  -- 添加 hash 防止冲突
  local hash = vim.fn.sha256(cwd):sub(1, 8)
  return normalized .. "_" .. hash
end

--- 获取会话存储目录
--- @return string
function M.get_sessions_folder()
  local options = Config.get()
  local base = (options.session or {}).storage_path
    or vim.fs.joinpath(vim.fn.stdpath("cache"), "orchestrate", "sessions")
  local project_folder = get_project_folder()
  return vim.fs.joinpath(base, project_folder)
end

--- 获取会话文件路径
--- @param session_id string
--- @return string
function M.get_session_file(session_id)
  return vim.fs.joinpath(M.get_sessions_folder(), session_id .. ".json")
end

--- 确保目录存在
--- @param dir string
--- @return boolean, string|nil
local function ensure_dir(dir)
  if vim.fn.isdirectory(dir) == 1 then
    return true
  end

  local ok = vim.fn.mkdir(dir, "p")
  if ok == 0 then
    return false, "Failed to create directory: " .. dir
  end
  return true
end

--- 保存会话状态
--- @param state table
--- @param callback fun(err: string|nil)|nil
function M.save(state, callback)
  if not state then
    if callback then
      callback("No state to save")
    end
    return
  end

  -- 使用 transport_session_id 或 store 的 id 作为会话 ID
  local session_id = (state.meta and state.meta.transport_session_id) or state.id
  if not session_id then
    if callback then
      callback("No session_id to save")
    end
    return
  end

  -- 如果没有消息，不保存
  if not state.messages or #state.messages == 0 then
    if callback then
      callback("No messages to save")
    end
    return
  end
  local folder = M.get_sessions_folder()

  local dir_ok, dir_err = ensure_dir(folder)
  if not dir_ok then
    Logger.debug("Failed to create session folder: %s", dir_err)
    if callback then
      callback(dir_err)
    end
    return
  end

  -- 准备要保存的数据
  local data = {
    version = 1,
    session_id = session_id,
    timestamp = os.time(),
    cwd = vim.uv.cwd() or vim.fn.getcwd(),
    messages = state.messages,
    todos = state.todos,
    meta = {
      transport = state.meta and state.meta.transport,
      transport_session_id = state.meta and state.meta.transport_session_id,
      store_id = state.id,
    },
  }

  local ok, json = pcall(vim.json.encode, data)
  if not ok then
    Logger.debug("Failed to encode session data: %s", json)
    if callback then
      callback("JSON encode error")
    end
    return
  end

  local path = M.get_session_file(session_id)

  -- 异步写入
  vim.schedule(function()
    local file = io.open(path, "w")
    if not file then
      if callback then
        callback("Failed to open file for writing: " .. path)
      end
      return
    end

    file:write(json)
    file:close()

    Logger.debug("Session saved: %s", session_id)
    if callback then
      callback(nil)
    end
  end)
end

--- 加载会话状态
--- @param session_id string
--- @param callback fun(data: table|nil, err: string|nil)
function M.load(session_id, callback)
  local path = M.get_session_file(session_id)

  if vim.fn.filereadable(path) ~= 1 then
    callback(nil, "Session file not found: " .. path)
    return
  end

  vim.schedule(function()
    local file = io.open(path, "r")
    if not file then
      callback(nil, "Failed to open session file")
      return
    end

    local content = file:read("*all")
    file:close()

    local ok, data = pcall(vim.json.decode, content)
    if not ok then
      callback(nil, "Failed to decode session JSON")
      return
    end

    Logger.debug("Session loaded: %s", session_id)
    callback(data, nil)
  end)
end

--- 列出当前项目的所有会话
--- @param callback fun(sessions: table[])
function M.list_sessions(callback)
  local folder = M.get_sessions_folder()
  local sessions = {}

  if vim.fn.isdirectory(folder) == 0 then
    callback(sessions)
    return
  end

  for filename, file_type in vim.fs.dir(folder) do
    if file_type == "file" and filename:match("%.json$") then
      local file_path = vim.fs.joinpath(folder, filename)
      local content = vim.fn.readfile(file_path)
      if #content > 0 then
        local ok, parsed = pcall(vim.json.decode, table.concat(content, "\n"))
        if ok and parsed then
          table.insert(sessions, {
            session_id = filename:gsub("%.json$", ""),
            timestamp = parsed.timestamp or 0,
            message_count = parsed.messages and #parsed.messages or 0,
            cwd = parsed.cwd,
          })
        end
      end
    end
  end

  -- 按时间戳降序排序
  table.sort(sessions, function(a, b)
    return a.timestamp > b.timestamp
  end)

  callback(sessions)
end

--- 获取最近的会话
--- @param callback fun(session: table|nil)
function M.get_latest_session(callback)
  M.list_sessions(function(sessions)
    if #sessions > 0 then
      callback(sessions[1])
    else
      callback(nil)
    end
  end)
end

--- 删除会话
--- @param session_id string
--- @return boolean
function M.delete(session_id)
  local path = M.get_session_file(session_id)
  if vim.fn.filereadable(path) == 1 then
    local ok = vim.fn.delete(path)
    return ok == 0
  end
  return false
end

return M
