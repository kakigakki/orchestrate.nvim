local Events = require("orchestrate.acp.events")

local Client = {}
Client.__index = Client

local function build_mock_reply(prompt)
  return {
    "已收到你的编排请求。",
    "",
    "当前 MVP 采用 Store 驱动渲染，事件不会直接写入窗口。",
    "",
    "下一步建议：",
    "1. 检查 Browse 面板里的流式内容。",
    "2. 根据 Todo 面板继续拆分任务。",
    "3. 如需审批或评审，再扩展对应事件处理。",
    "",
    "你的输入摘要：",
    prompt,
  }
end

local function build_mock_todos(prompt)
  return {
    { title = "整理用户目标", status = "done", detail = "已解析输入内容" },
    { title = "生成 MVP 响应", status = "doing", detail = "模拟 ACP 流式输出" },
    { title = "等待下一步编排", status = "todo", detail = vim.trim(prompt) ~= "" and "可继续细化任务" or "等待更多输入" },
  }
end

function Client.new(opts)
  return setmetatable({
    opts = opts or {},
    dispatch = nil,
  }, Client)
end

function Client:set_dispatch(dispatch)
  self.dispatch = dispatch
end

function Client:emit(event_name, payload)
  if self.dispatch then
    self.dispatch(event_name, payload or {})
  end
end

function Client:send_message(text)
  if self.opts.mock and self.opts.mock.enabled == false then
    vim.notify("orchestrate.nvim: 当前仅内置 mock ACP，请先接入真实客户端。", vim.log.levels.WARN)
    return false
  end

  local assistant_id = string.format("assistant-%d", vim.loop.hrtime())
  local reply_chunks = build_mock_reply(text)
  local chunk_delay = (self.opts.mock and self.opts.mock.chunk_delay) or 160

  self:emit(Events.ASSISTANT_STREAM_START, {
    id = assistant_id,
    title = "Orchestrator",
  })

  for index, chunk in ipairs(reply_chunks) do
    vim.defer_fn(function()
      self:emit(Events.ASSISTANT_STREAM_DELTA, {
        id = assistant_id,
        delta = chunk .. "\n",
      })

      if index == math.ceil(#reply_chunks / 2) then
        self:emit(Events.TODO_UPDATED, build_mock_todos(text))
      end

      if index == #reply_chunks then
        self:emit(Events.APPROVAL_REQUESTED, {
          id = string.format("approval-%d", vim.loop.hrtime()),
          title = "可选审批：是否继续执行下一阶段任务",
        })
        self:emit(Events.REVIEW_READY, {
          id = string.format("review-%d", vim.loop.hrtime()),
          title = "可选审查：MVP 响应已生成，可进一步校验",
        })
        self:emit(Events.ASSISTANT_STREAM_END, {
          id = assistant_id,
        })
      end
    end, index * chunk_delay)
  end

  return true
end

return Client
