# orchestrate.nvim

`orchestrate.nvim` 是一个面向 Neovim 的 Agent Orchestration Workspace。

它不是聊天 UI，也不是终端包装器，而是一个围绕 Agent 工作流组织出来的多缓冲区工作区：

`ACP -> Store -> Renderer -> Buffers/Windows`

## 特性

- 三栏工作区
- 左侧 `Browse` 只读事件流
- 右上 `Todo` 结构化任务列表（含审批和审查状态）
- 右下 `Input` 可编辑输入区，`:w` 直接发送
- 所有状态更新统一走 actions
- renderer 与 ACP 解耦
- 内置 Claude Code transport，支持会话恢复
- 内置 mock transport，用于开发测试
- Approval 交互支持（accept/reject）
- Review 交互支持（跳转到代码位置/quickfix 集成）
- 错误恢复与重试
- 可通过 `lazy.nvim` 直接导入

## 目录结构

```text
plugin/orchestrate.lua
doc/orchestrate.txt
lua/orchestrate/
  init.lua
  setup.lua
  config.lua
  acp/
    client.lua
    events.lua
    registry.lua
    transports/
      claude_code.lua
      mock.lua
  core/
    store.lua
    actions.lua
  renderers/
    browse.lua
    todo.lua
    input.lua
  ui/
    layout.lua
    buffers.lua
    approval.lua
    review.lua
  utils/
    logger.lua
  commands/
    init.lua
```

## 安装

远程仓库：

```lua
{
  "kakigakki/orchestrate.nvim",
  main = "orchestrate",
  opts = {},
}
```

本地开发：

```lua
{
  dir = "~/code/orchestrate.nvim",
  name = "orchestrate.nvim",
  main = "orchestrate",
  opts = {},
}
```

懒加载配置：

```lua
{
  "kakigakki/orchestrate.nvim",
  main = "orchestrate",
  cmd = {
    "OrchestrateOpen",
    "OrchestrateClose",
    "OrchestrateToggle",
    "OrchestrateSend",
    "OrchestrateResume",
    "OrchestrateContinue",
    "OrchestrateApprove",
    "OrchestrateReject",
    "OrchestrateReviewJump",
    "OrchestrateReviewQuickfix",
    "OrchestrateRetry",
  },
  opts = {},
}
```

## 默认配置

```lua
require("orchestrate").setup({
  layout = {
    browse_width = 0.7,
    todo_height = 0.5,
    min_browse_width = 40,
    min_sidebar_height = 6,
  },
  ui = {
    input_filetype = "markdown",
  },
  transport = {
    name = "claude_code",
    claude_code = {
      command = "claude",
      resume_strategy = "session_id",
      fallback_to_mock = false,
      model = nil,
      max_turns = nil,
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
})
```

## 使用

### 基础工作流

1. 执行 `:OrchestrateOpen`
2. 在 `Input` buffer 输入内容
3. 执行 `:w` 发送
4. 在 `Browse` 查看用户提交与助手流式事件
5. 在 `Todo` 查看任务更新

也可以直接执行：

```vim
:OrchestrateSend 为当前项目拆分下一步任务
```

### 审批工作流

当 Agent 请求审批时：
1. `Todo` 面板会显示待审批项
2. 使用 `:OrchestrateApprove` 批准第一个待审批项
3. 使用 `:OrchestrateReject` 拒绝第一个待审批项
4. 使用 `:OrchestrateApprovalSelect` 选择特定审批项处理

### 代码审查工作流

当 Agent 产生代码审查时：
1. `Todo` 面板会显示审查项
2. 使用 `:OrchestrateReviewJump` 跳转到第一个未读审查
3. 使用 `:OrchestrateReviewSelect` 选择特定审查跳转
4. 使用 `:OrchestrateReviewQuickfix` 将所有审查项添加到 quickfix

### 错误恢复

当发生错误时：
1. `Todo` 面板会显示错误信息
2. 使用 `:OrchestrateRetry` 重试上一条消息

## 命令

### 基础命令

| 命令 | 说明 |
|------|------|
| `:OrchestrateOpen` | 打开工作区 |
| `:OrchestrateClose` | 关闭工作区 |
| `:OrchestrateToggle` | 切换工作区 |
| `:OrchestrateSend [text]` | 发送消息 |
| `:OrchestrateResume [text]` | 通过 session ID 恢复 |
| `:OrchestrateContinue [text]` | 继续上一个任务 |

### 审批命令

| 命令 | 说明 |
|------|------|
| `:OrchestrateApprove` | 批准第一个待审批项 |
| `:OrchestrateReject` | 拒绝第一个待审批项 |
| `:OrchestrateApprovalSelect` | 选择并处理审批 |

### 审查命令

| 命令 | 说明 |
|------|------|
| `:OrchestrateReviewJump` | 跳转到第一个未读审查 |
| `:OrchestrateReviewSelect` | 选择审查项跳转 |
| `:OrchestrateReviewQuickfix` | 添加审查到 quickfix |

### 错误恢复

| 命令 | 说明 |
|------|------|
| `:OrchestrateRetry` | 重试上一条消息 |

## Lua API

```lua
local orchestrate = require("orchestrate")

orchestrate.setup(opts)           -- 初始化配置
orchestrate.open()                -- 打开工作区
orchestrate.close()               -- 关闭工作区
orchestrate.send(text)            -- 发送消息
orchestrate.resume(text)          -- 恢复会话
orchestrate.continue_last(text)   -- 继续任务
orchestrate.get_session()         -- 获取当前会话状态
orchestrate.is_open()             -- 检查工作区是否打开

-- Approval 相关
orchestrate.approve()             -- 批准第一个待审批
orchestrate.reject()              -- 拒绝第一个待审批
orchestrate.select_approval()     -- 选择并处理审批

-- Review 相关
orchestrate.review_jump()         -- 跳转到未读审查
orchestrate.review_select()       -- 选择审查跳转
orchestrate.review_quickfix()     -- 添加到 quickfix

-- 错误恢复
orchestrate.retry()               -- 重试上一条消息
```

## 健康检查

```vim
:checkhealth orchestrate
```

## 开发说明

- `plugin/orchestrate.lua` 提供标准插件入口
- `setup()` 是幂等的，适合 `lazy.nvim` 的 `opts` 调用
- `doc/orchestrate.txt` 提供 `:h orchestrate` 帮助文档
- `doc/future-spec.md` 记录后续功能式样与阶段规划
- `ROADMAP.md` 记录开发路线图
- 当前默认 transport 为 Claude Code CLI，并保留 mock transport 作为开发测试用途

## 开源协作

- CI 工作流见 `.github/workflows/ci.yml`
- issue 模板与 PR 模板已添加
- 贡献说明见 `CONTRIBUTING.md`
- 变更记录见 `CHANGELOG.md`

## 许可证

[MIT](./LICENSE)
