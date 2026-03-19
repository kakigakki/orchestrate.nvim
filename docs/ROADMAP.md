# orchestrate.nvim 开发计划

## 当前状态

### 已完成功能
- [x] 基础架构：Store/Actions/Renderers 模式
- [x] Claude Code CLI 集成（`-p` 模式，stream-json 输出）
- [x] 三面板 UI（Browse/Todo/Input）
- [x] 会话管理（自动保存/恢复）
- [x] 权限模式支持（acceptEdits/bypassPermissions 等）
- [x] 实验性交互式权限弹窗（PreToolUse hook）
- [x] Claude CLI 自动检测（PATH/Homebrew Cask）
- [x] 连续消息发送支持

### 已知问题
- [ ] 交互式权限弹窗依赖 `--settings` CLI 参数，可能与用户现有 hooks 冲突
- [ ] Todo 面板渲染未完全实现
- [ ] 长消息/代码块的显示优化

---

## Phase 1: 核心体验优化

### 1.1 Browse 面板增强
- [ ] 代码块语法高亮（使用 treesitter）
- [ ] 折叠长内容（tool results、thinking blocks）
- [ ] 消息间分隔线/时间戳
- [ ] 滚动到最新消息

### 1.2 Input 面板增强
- [ ] 多行输入支持优化
- [ ] 输入历史（上下箭头浏览）
- [ ] 快捷键提示（底部状态栏）
- [ ] 支持粘贴图片路径自动附加

### 1.3 Todo 面板实现
- [ ] 解析 Claude 的 TodoWrite 工具调用
- [ ] 实时显示任务状态（pending/in_progress/completed）
- [ ] 任务进度百分比
- [ ] 支持点击跳转到相关消息

---

## Phase 2: 工具集成

### 2.1 文件操作可视化
- [ ] Edit/Write 工具显示 diff 预览
- [ ] 支持在 Browse 面板中展开查看完整文件内容
- [ ] Read 工具结果折叠显示

### 2.2 Bash 命令可视化
- [ ] 命令输出语法高亮
- [ ] 长输出折叠
- [ ] 错误输出红色高亮

### 2.3 代码审查集成
- [ ] Review 面板优化
- [ ] 支持跳转到文件具体行号
- [ ] Quickfix 列表集成

---

## Phase 3: 会话管理增强

### 3.1 会话浏览器
- [ ] `:OrchestrateSessionList` 命令
- [ ] Telescope/fzf 集成
- [ ] 按项目/日期筛选
- [ ] 会话预览

### 3.2 会话导出
- [ ] 导出为 Markdown
- [ ] 导出为 JSON（完整对话）
- [ ] 分享链接生成（可选）

### 3.3 多会话支持
- [ ] 同时打开多个会话（不同 tab）
- [ ] 会话间切换
- [ ] 会话合并

---

## Phase 4: 高级功能

### 4.1 Context 管理
- [ ] 手动添加文件到 context
- [ ] Context 预览面板
- [ ] 自动 context 建议（基于当前 buffer）

### 4.2 快捷操作
- [ ] 预设 prompt 模板
- [ ] 快速命令（/fix、/explain、/refactor）
- [ ] 选中代码直接发送

### 4.3 通知与状态
- [ ] 系统通知（长任务完成时）
- [ ] 状态栏组件（显示当前会话状态）
- [ ] Cost 追踪显示

---

## Phase 5: 其他 Transport 支持

### 5.1 Anthropic API 直连
- [ ] 不依赖 Claude CLI
- [ ] 支持自定义 API endpoint
- [ ] 流式响应

### 5.2 其他 LLM 支持
- [ ] OpenAI API
- [ ] Ollama 本地模型
- [ ] 通用 OpenAI 兼容接口

---

## 技术债务

### 代码质量
- [ ] 添加更多单元测试
- [ ] 集成测试覆盖主要流程
- [ ] API 文档生成
- [ ] 性能分析和优化

### 用户体验
- [ ] `:checkhealth` 完善
- [ ] 错误消息友好化
- [ ] 帮助文档（`:help orchestrate`）

---

## 优先级排序

### 高优先级（下一步）
1. Browse 面板代码块语法高亮
2. Todo 面板基础实现
3. 会话列表命令

### 中优先级
1. 文件操作 diff 预览
2. 输入历史
3. 快捷操作

### 低优先级
1. 其他 Transport 支持
2. 多会话
3. Context 管理面板

---

## 备注

- 当前主要依赖 Claude Code CLI，需关注其版本更新
- 交互式权限弹窗功能受 CLI 限制，建议用户使用 `permission_mode` 配置
- 考虑添加配置迁移机制，应对未来配置结构变化
