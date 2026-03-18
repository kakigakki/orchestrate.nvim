# orchestrate.nvim 项目计划书

本文档定义 `orchestrate.nvim` 的开发路线图、阶段目标、任务分解和优先级排序。

---

## 1. 项目现状评估

### 1.1 已完成功能

| 模块 | 状态 | 说明 |
|------|------|------|
| 核心架构 | **完成** | ACP → Store → Renderer → UI 架构已建立 |
| Store/Actions | **完成** | Flux 风格状态管理，支持订阅 |
| Mock Transport | **完成** | 用于开发测试的模拟传输 |
| Claude Code Transport | **完成** | 支持 CLI 调用、流式输出、会话恢复 |
| 三栏布局 | **完成** | Browse/Todo/Input 三面板工作区 |
| 基础命令 | **完成** | Open/Close/Send/Resume/Continue |
| Health Check | **完成** | `:checkhealth orchestrate` |
| 基础测试 | **完成** | Store/Actions/Transport 测试 |
| CI 流水线 | **完成** | StyLua + 测试 + 加载验证 |

### 1.2 已知限制

| 限制 | 严重程度 | 说明 |
|------|----------|------|
| Approval/Review 无交互 | **高** | 只展示，无法 accept/reject |
| Session 不持久化 | **高** | 关闭后丢失会话历史 |
| 无多会话切换 | **中** | 只支持单一会话 |
| 无项目上下文采集 | **中** | 不能自动注入 buffer/diff 等上下文 |
| 无日志系统 | **低** | 调试困难 |
| 无窗口恢复机制 | **低** | buffer/window 丢失后无法恢复 |
| 测试覆盖率低 | **低** | 缺少 renderer/UI 测试 |

---

## 2. 开发阶段规划

### Phase 1: 可用化 (v0.2.x)

**目标**：让插件适合日常本地使用，补齐稳定性与交互能力

**预估工作量**：3-4 周

#### 1.1 Approval 交互 (高优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 添加 resolve_approval action | `core/actions.lua` | 处理 accept/reject 决策 |
| 添加 Approval 面板渲染 | `renderers/todo.lua` | 在 Todo 面板显示待审批项 |
| 实现 vim.ui.select 交互 | `ui/approval.lua` (新) | 弹窗选择 accept/reject |
| 透传审批结果到 transport | `acp/client.lua` | 调用 transport 的 respond 方法 |
| 添加 :OrchestrateApprove 命令 | `commands/init.lua` | 用户命令入口 |
| 添加 :OrchestrateReject 命令 | `commands/init.lua` | 用户命令入口 |

**验收标准**：
- [ ] 审批请求在 Todo 面板可见
- [ ] 可通过命令或快捷键 accept/reject
- [ ] 结果正确透传给 transport

#### 1.2 Review 交互 (高优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 添加 mark_review_seen action | `core/actions.lua` | 标记已读 |
| 添加 Review 面板渲染 | `renderers/todo.lua` | 显示 review 项与状态 |
| 实现跳转到代码位置 | `ui/review.lua` (新) | 打开文件并跳转到行号 |
| 集成 quickfix | `ui/review.lua` | 将 review 项同步到 quickfix |
| 添加 :OrchestrateReview 命令 | `commands/init.lua` | 用户命令入口 |

**验收标准**：
- [ ] Review 项在 Todo 面板可见
- [ ] 可跳转到相关代码位置
- [ ] 可同步到 quickfix list

#### 1.3 错误处理增强 (中优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 添加错误恢复 action | `core/actions.lua` | clear_error + retry 逻辑 |
| Transport 断开重连 | `acp/client.lua` | 自动重连机制 |
| 错误状态 UI 展示 | `renderers/browse.lua` | 错误信息高亮显示 |
| 添加重试命令 | `commands/init.lua` | :OrchestrateRetry |

**验收标准**：
- [ ] Transport 断开时 UI 不崩溃
- [ ] 错误信息清晰可见
- [ ] 可手动重试失败操作

#### 1.4 日志系统 (低优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 创建 Logger 模块 | `utils/logger.lua` (新) | 支持 debug/info/warn/error 级别 |
| 配置日志级别 | `config.lua` | debug.log_level 选项 |
| 关键路径添加日志 | 各模块 | transport/actions/renderer |
| 日志面板(可选) | `ui/log.lua` (新) | 浮窗显示日志 |

**验收标准**：
- [ ] 可通过配置开启调试日志
- [ ] 日志输出到文件或 :messages

---

### Phase 2: 工作流化 (v0.3.x)

**目标**：从"能显示"进化为"能组织工作流"

**预估工作量**：4-5 周

#### 2.1 Session 持久化 (高优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 设计持久化格式 | `core/persistence.lua` (新) | JSON 或 MessagePack |
| 实现 save_session | `core/persistence.lua` | 保存到 ~/.local/share/nvim/orchestrate/ |
| 实现 load_session | `core/persistence.lua` | 从文件恢复 |
| 自动保存触发 | `setup.lua` | 状态变更时自动保存 |
| 恢复历史浏览 | `commands/init.lua` | :OrchestrateSessions |

**验收标准**：
- [ ] 关闭 Neovim 后会话不丢失
- [ ] 可浏览和恢复历史会话
- [ ] 会话与项目关联

#### 2.2 多会话管理 (高优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| Store 支持多会话 | `core/store.lua` | sessions 数组 + active_session_id |
| 添加 create_session action | `core/actions.lua` | 创建新会话 |
| 添加 switch_session action | `core/actions.lua` | 切换活动会话 |
| 添加 close_session action | `core/actions.lua` | 关闭并归档会话 |
| 会话列表 UI | `ui/sessions.lua` (新) | Telescope/浮窗选择器 |
| 更新 API | `init.lua` | list_sessions / switch_session |

**验收标准**：
- [ ] 可同时存在多个会话
- [ ] 可在会话间切换
- [ ] 会话有标题和项目归属

#### 2.3 Todo 交互增强 (中优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| Todo 状态切换 | `core/actions.lua` | toggle_todo_status |
| Todo 面板快捷键 | `ui/buffers.lua` | `<CR>` 详情 / `dd` done / `pp` in_progress |
| Todo 详情浮窗 | `ui/todo_detail.lua` (新) | 显示完整任务信息 |
| 手动添加 Todo | `core/actions.lua` | add_manual_todo |

**验收标准**：
- [ ] 可通过快捷键切换任务状态
- [ ] 可查看任务详情
- [ ] 可手动添加任务

#### 2.4 草稿恢复 (低优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 草稿持久化 | `core/persistence.lua` | 与 session 一起保存 |
| Input 恢复草稿 | `renderers/input.lua` | 打开时恢复上次草稿 |
| 草稿历史(可选) | `ui/drafts.lua` (新) | 浏览草稿历史 |

**验收标准**：
- [ ] 未发送的草稿不丢失
- [ ] 打开工作区时自动恢复草稿

---

### Phase 3: 项目集成化 (v0.4.x)

**目标**：让插件能真正服务项目级开发流程

**预估工作量**：5-6 周

#### 3.1 上下文管理 (高优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 设计 Context 数据结构 | `core/context.lua` (新) | 来源类型/内容/元数据 |
| 当前 buffer 上下文 | `core/context.lua` | 采集当前文件内容 |
| 可视选择区域上下文 | `core/context.lua` | 采集选中文本 |
| Git diff 上下文 | `core/context.lua` | 采集未提交变更 |
| Quickfix/Diagnostics 上下文 | `core/context.lua` | 采集错误列表 |
| 上下文面板 UI | `ui/context.lua` (新) | 显示/编辑/删除上下文 |
| 上下文大小估算 | `core/context.lua` | Token 估算与截断 |
| 添加 :OrchestrateContextAdd | `commands/init.lua` | 用户命令 |
| 添加 :OrchestrateContextClear | `commands/init.lua` | 用户命令 |

**验收标准**：
- [ ] 可从多种来源添加上下文
- [ ] 上下文可视化可管理
- [ ] 支持大小估算和自动截断

#### 3.2 审批命令执行桥接 (中优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 命令执行沙箱 | `core/executor.lua` (新) | 安全执行 shell 命令 |
| 审批后自动执行 | `ui/approval.lua` | accept 后执行关联命令 |
| 执行结果反馈 | `core/actions.lua` | 将结果写入 messages |
| 危险命令警告 | `core/executor.lua` | 检测并警告危险操作 |

**验收标准**：
- [ ] 审批后可自动执行命令
- [ ] 执行结果反馈到工作区
- [ ] 危险命令有额外确认

#### 3.3 Review 代码联动 (中优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 虚拟文本显示 | `ui/review.lua` | 在源码中显示 review 标记 |
| Sign column 标记 | `ui/review.lua` | 边栏显示 review 图标 |
| 批量跳转 | `ui/review.lua` | :OrchestrateNextReview |
| 与 Trouble.nvim 集成(可选) | `integrations/trouble.lua` (新) | 集成诊断插件 |

**验收标准**：
- [ ] Review 项在源码中可见
- [ ] 可批量跳转 review 位置

#### 3.4 外部集成 (低优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| Telescope 集成 | `integrations/telescope.lua` (新) | 会话/上下文选择器 |
| fzf-lua 集成 | `integrations/fzf.lua` (新) | 会话/上下文选择器 |
| Snacks.nvim 集成(可选) | `integrations/snacks.lua` (新) | 通知/面板集成 |

**验收标准**：
- [ ] 可通过 Telescope 搜索会话
- [ ] 可通过 fzf 快速选择上下文

---

### Phase 4: 生态化 (v1.0.x)

**目标**：形成可扩展平台

**预估工作量**：6-8 周

#### 4.1 Transport 插件化 (高优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| Transport 接口规范 | `acp/interface.lua` (新) | 定义标准接口文档 |
| 动态加载外部 transport | `acp/registry.lua` | 支持 require 外部模块 |
| Transport 配置 schema | `acp/registry.lua` | 验证 transport 配置 |
| 示例 transport 模板 | `doc/transport-template.lua` (新) | 开发者参考 |

**验收标准**：
- [ ] 可通过配置加载外部 transport
- [ ] 有完整的 transport 开发文档

#### 4.2 自定义 Renderer (中优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| Renderer 接口规范 | `renderers/interface.lua` (新) | 定义标准接口 |
| Renderer 注册机制 | `renderers/registry.lua` (新) | 支持自定义 renderer |
| 主题/样式配置 | `config.lua` | 颜色/图标/格式可配置 |

**验收标准**：
- [ ] 可注册自定义 renderer
- [ ] 样式可通过配置定制

#### 4.3 事件 Hook 机制 (中优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| 设计 Hook 系统 | `core/hooks.lua` (新) | pre/post hook 注册 |
| Store 变更 hook | `core/store.lua` | 状态变更前后触发 |
| Transport 事件 hook | `acp/client.lua` | 事件处理前后触发 |
| User action hook | `commands/init.lua` | 命令执行前后触发 |

**验收标准**：
- [ ] 可注册 hook 响应各种事件
- [ ] Hook 可用于自定义工作流

#### 4.4 自定义 Action/Workflow (低优先级)

| 任务 | 文件 | 说明 |
|------|------|------|
| Action 注册机制 | `core/actions.lua` | 支持自定义 action |
| Workflow 定义格式 | `workflows/schema.lua` (新) | YAML/Lua 工作流定义 |
| 内置 Workflow 模板 | `workflows/builtins.lua` (新) | 代码审查/重构等模板 |
| Workflow 执行引擎 | `workflows/runner.lua` (新) | 按步骤执行工作流 |

**验收标准**：
- [ ] 可定义和执行自定义工作流
- [ ] 有常用工作流模板

---

## 3. 技术债务清理

### 3.1 测试覆盖率提升

| 任务 | 优先级 | 说明 |
|------|--------|------|
| Renderer 快照测试 | 中 | 验证渲染输出 |
| UI 集成测试 | 中 | 验证窗口/buffer 行为 |
| Transport 集成测试 | 低 | 使用 mock 验证完整流程 |
| E2E 测试(可选) | 低 | 完整用户场景测试 |

### 3.2 代码质量

| 任务 | 优先级 | 说明 |
|------|--------|------|
| 添加类型注解 | 低 | LuaLS 类型注解 |
| 提取公共工具 | 低 | 创建 utils/ 目录 |
| 文档同步 | 中 | 更新 help doc 和 README |

---

## 4. 里程碑与版本规划

| 版本 | 里程碑 | 关键功能 | 目标日期 |
|------|--------|----------|----------|
| v0.2.0 | Foundation Hardening | Approval/Review 交互, 错误处理, 日志 | TBD |
| v0.3.0 | Session Workflow | Session 持久化, 多会话, Todo 交互 | TBD |
| v0.4.0 | Project Context | 上下文管理, 命令执行, 代码联动 | TBD |
| v0.5.0 | Integrations | Telescope/fzf/Trouble 集成 | TBD |
| v1.0.0 | Ecosystem | Transport 插件化, Hook 机制, 自定义工作流 | TBD |

---

## 5. 建议的下一步行动

按优先级排序，建议的前 5 项任务：

1. **Approval 交互** - 让审批请求可执行
2. **Review 交互** - 让 review 能跳转到代码
3. **Session 持久化** - 保证会话不丢失
4. **上下文管理** - 支持注入项目上下文
5. **多会话管理** - 支持并行多个工作流

---

## 6. 开发原则

在开发过程中必须遵守以下原则：

1. **架构边界** - `ACP → Store → Renderer → UI`
2. **单向数据流** - 不允许 ACP 直接写 buffer
3. **状态集中** - 不允许在 actions 外修改状态
4. **职责单一** - renderer 只负责渲染，UI 不承担业务逻辑
5. **可替换性** - transport 可替换，不绑定单一后端
6. **渐进增强** - 默认能力可用，扩展按模块叠加

---

## 7. 贡献指南

### 7.1 提交 PR 前

- 运行 `stylua lua plugin`
- 运行测试 `nvim --headless --clean -u NONE +"set rtp+=." +"luafile tests/run.lua" +q`
- 验证插件加载 `nvim --headless --clean -u NONE +"set rtp+=." +"lua require('orchestrate').setup({})" +q`

### 7.2 功能开发流程

1. 在对应 Phase 下认领任务
2. 创建 feature 分支
3. 实现功能 + 测试
4. 更新文档
5. 提交 PR

### 7.3 Issue 标签

- `phase-1` / `phase-2` / `phase-3` / `phase-4` - 开发阶段
- `high` / `medium` / `low` - 优先级
- `bug` / `feature` / `enhancement` - 类型
- `good-first-issue` - 适合新贡献者

---

*最后更新: 2026-03-18*
