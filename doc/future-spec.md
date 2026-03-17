# orchestrate.nvim 后续开发式样书

## 1. 文档目的

本文档定义 `orchestrate.nvim` 后续版本的目标、范围、架构边界、功能规格、非功能需求与阶段计划。

目的有三点：

- 为后续开发提供统一判断标准
- 为 issue / milestone 拆分提供依据
- 保证插件持续遵守当前核心设计原则

## 2. 产品定位

`orchestrate.nvim` 是一个运行在 Neovim 内部的 Agent Orchestration Workspace。

它的定位不是：

- 聊天窗口插件
- 终端包装器
- 纯日志查看器

它的定位是：

- 面向 agent 工作流的多面板操作空间
- 面向 ACP 事件流的状态驱动界面
- 面向任务编排、审批、审查、上下文组织的工作台

## 3. 核心设计原则

后续所有功能必须继续遵守以下原则：

1. `ACP -> Store -> Renderer -> Neovim UI`
2. 不允许 ACP 事件直接写入 buffer
3. 不允许在 actions 之外直接修改会话状态
4. renderer 只负责把 session 渲染到 bufnr
5. UI 层不承担业务逻辑
6. 可替换 transport，不绑定单一后端
7. 默认能力可用，扩展能力按模块叠加

## 4. 当前 MVP 的已知限制

当前版本已完成基础链路，但仍有以下限制：

- ACP 仍为 mock 实现
- approval / review 只有展示，没有交互
- session 不持久化
- 没有多会话切换
- 没有项目上下文采集能力
- 没有测试体系
- 没有 health check
- 没有日志与调试面板
- 没有针对错误状态的完整恢复机制

## 5. 后续目标版本

建议以后续 4 个阶段推进：

### Phase 1: 可用化

目标：

- 让插件适合日常本地使用
- 补齐基础稳定性与交互能力

范围：

- 真实 ACP client 抽象
- 更稳定的命令注册与窗口恢复
- session 生命周期管理
- approval / review 基础交互
- 错误提示与日志
- `:checkhealth orchestrate`
- 基础自动化测试

### Phase 2: 工作流化

目标：

- 让插件从“能显示”进化为“能组织工作流”

范围：

- 多会话管理
- todo 状态切换与手动编辑动作
- 会话标签、标题、项目归属
- session 持久化
- 可恢复历史浏览
- 上下文来源管理

### Phase 3: 项目集成化

目标：

- 让插件能真正服务项目级开发流程

范围：

- 文件、git diff、quickfix、diagnostics 作为上下文来源
- 审批操作与命令执行桥接
- review 结果与代码位置联动
- 与 Telescope / Snacks / fzf-lua 的集成入口

### Phase 4: 生态化

目标：

- 形成可扩展平台

范围：

- adapter 机制
- provider / transport 插件化
- 自定义 renderer 扩展点
- 事件 hook 机制
- 用户自定义 action / workflow

## 6. 功能式样

### 6.1 ACP 传输层

#### 目标

将 mock client 升级为可替换 transport 层。

#### 必要能力

- `connect()`
- `disconnect()`
- `send_message(text, context)`
- `cancel(request_id)`
- `on_event(callback)`

#### 事件要求

至少支持：

- `user_submit`
- `assistant_stream_start`
- `assistant_stream_delta`
- `assistant_stream_end`
- `todo_updated`
- `approval_requested`
- `review_ready`
- `error`
- `session_updated`

#### 设计要求

- transport 层不直接访问 UI
- transport 层只产出标准事件
- 标准事件统一进入 actions
- mock transport 保留，作为 fallback 与测试桩

### 6.2 Session / Store

#### 目标

把当前单 session store 扩展为支持 session 生命周期管理的状态中心。

#### 建议状态结构

```lua
SessionState = {
  id = string,
  title = string,
  project_root = string?,
  status = "idle" | "streaming" | "waiting_approval" | "reviewing" | "error",
  messages = {},
  todos = {},
  approvals = {},
  reviews = {},
  draft = {},
  context = {},
  meta = {
    created_at = number,
    updated_at = number,
    transport = string,
  },
}
```

#### 后续动作建议

- `create_session(opts)`
- `switch_session(id)`
- `close_session(id)`
- `restore_session(id)`
- `set_draft(lines)`
- `submit_prompt(text)`
- `cancel_stream()`
- `resolve_approval(id, decision)`
- `mark_review_seen(id)`
- `set_error(err)`

### 6.3 Browse 面板

#### 目标

让 Browse 成为工作流事件浏览器，而不是聊天记录窗口。

#### 必要能力

- 时间顺序展示事件
- 区分用户、assistant、system、approval、review
- 对 stream 中状态进行可视标记
- 支持跳转到相关 todo / review 项

#### 可选增强

- 事件折叠
- 按类型过滤
- 按 session 内阶段分组
- 显示事件来源与 request id

### 6.4 Todo 面板

#### 目标

把 todo 从“只读文本”升级为“可操作任务列表”。

#### 必要能力

- 展示状态、标题、详情
- 支持选中当前任务
- 支持更新任务状态
- 支持将 review / approval 关联到任务

#### 后续交互建议

- `<CR>` 打开详情
- `dd` 标记 done
- `pp` 标记 in_progress
- `rr` 标记 blocked / needs_review

### 6.5 Input 面板

#### 目标

让 Input 成为工作流输入入口，而不是普通文本区。

#### 必要能力

- `:w` 发送
- 保留草稿
- 支持插入上下文引用
- 支持模板片段

#### 后续增强

- prompt preset
- slash commands
- 当前 session 上下文摘要
- 发送前预览

### 6.6 Approval 交互

#### 目标

让审批请求可执行，而不是只展示。

#### 必要能力

- 查看审批标题与说明
- 选择 accept / reject
- 将结果作为 action 写回 store
- 可把审批结果透传给 transport

#### UI 方案候选

- 在 Todo 面板显示待审批区块
- 使用浮窗确认
- 使用 `vim.ui.select()` 做最小实现

### 6.7 Review 交互

#### 目标

让 review 能和项目代码发生联动。

#### 必要能力

- 展示 review 标题、摘要、严重度
- 能跳转到对应文件与位置
- 能标记已读 / 已处理

#### 后续增强

- review 列表面板
- 与 quickfix/location list 同步
- 支持批量跳转

### 6.8 Context 管理

#### 目标

支持把项目上下文安全、可控地注入到 agent 工作流中。

#### 上下文来源

- 当前 buffer
- 可视选择区域
- 文件路径列表
- quickfix / diagnostics
- git diff
- 用户手动输入的说明

#### 设计要求

- 上下文进入 session 前要可视化
- 支持增删与排序
- 支持估算大小与截断策略

## 7. 命令与 API 式样

### 7.1 用户命令

后续建议支持：

- `:OrchestrateOpen`
- `:OrchestrateClose`
- `:OrchestrateToggle`
- `:OrchestrateSend [text]`
- `:OrchestrateSessions`
- `:OrchestrateResume`
- `:OrchestrateApprove`
- `:OrchestrateReject`
- `:OrchestrateReview`
- `:OrchestrateContextAdd`
- `:OrchestrateContextClear`

### 7.2 Lua API

后续建议公开：

```lua
require("orchestrate").setup(opts)
require("orchestrate").open()
require("orchestrate").close()
require("orchestrate").send(text)
require("orchestrate").get_session()
require("orchestrate").list_sessions()
require("orchestrate").switch_session(id)
require("orchestrate").register_transport(name, transport)
```

## 8. 非功能需求

### 8.1 性能

- 打开工作区应在可感知范围内快速完成
- 流式渲染不能阻塞普通编辑
- 大型事件流渲染需要考虑增量更新

### 8.2 稳定性

- transport 断开时 UI 不应崩溃
- buffer / window 丢失时可恢复
- 重复执行 `setup()` 不报错
- 重复打开关闭工作区不泄漏 autocmd

### 8.3 可维护性

- 模块边界清晰
- 每个模块职责单一
- 文档与代码同步更新
- 新事件类型加入时无需大规模改写 UI

### 8.4 可测试性

- actions 可单测
- store 可单测
- renderer 输出可快照测试
- transport 可用 mock 驱动集成测试

## 9. 测试式样

建议至少建立以下测试：

### 单元测试

- store 状态更新
- actions 对各事件的处理
- renderer 输出是否符合预期

### 集成测试

- `:OrchestrateOpen` 是否正确生成三栏
- input `:w` 是否触发 submit
- mock stream 是否正确更新 browse / todo

### 回归测试

- 重复 `setup()`
- 重复 `open/close`
- transport 关闭时的错误处理

## 10. 发布式样

### 发布前最低要求

- headless load test 通过
- stylua check 通过
- 至少有基础单元测试
- README 与 help doc 同步

### 版本建议

- `0.1.x`：MVP 稳定化
- `0.2.x`：真实 transport 与 session 管理
- `0.3.x`：approval / review / context 完整交互
- `0.4.x`：多 session 与项目集成
- `1.0.0`：核心 API 与行为稳定

## 11. 建议的 GitHub Milestones

### Milestone 1: Foundation Hardening

- 真实 ACP transport 接口
- health check
- 基础测试
- 错误处理
- 日志系统

### Milestone 2: Session Workflow

- 多 session
- session 持久化
- todo 交互
- draft 恢复

### Milestone 3: Approval and Review

- approval accept / reject
- review 跳转
- quickfix 联动

### Milestone 4: Project Context

- buffer / visual / diff context
- context 面板
- 大小控制与裁剪

## 12. 明确不做的内容

以下内容默认不作为主线方向：

- 做成聊天气泡 UI
- 把所有事件直接混写到 terminal
- 把 transport、store、renderer 合并到同一层
- 为了“看起来像 AI 插件”而牺牲工作流结构

## 13. 下一个建议执行顺序

如果只选最重要的后续 5 项，建议按这个顺序做：

1. 真实 ACP transport 抽象
2. 自动化测试与 `:checkhealth`
3. approval / review 交互
4. session 持久化与多会话
5. 项目上下文管理
