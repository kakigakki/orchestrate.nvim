# 实现功能

根据 ROADMAP.md 中的规划实现一个功能。

## 输入参数

$ARGUMENTS = 功能名称 (例如: "approval-interaction", "session-persistence", "context-management")

## 任务

1. 阅读 ROADMAP.md 找到对应功能的任务列表
2. 按照任务列表逐项实现
3. 确保符合架构原则
4. 添加测试
5. 更新文档

## 实现流程

### 1. 理解需求
- 阅读 ROADMAP.md 中的功能描述
- 阅读 doc/future-spec.md 中的详细规格
- 确认验收标准

### 2. 设计方案
- 确定需要修改/新建的文件
- 确定状态结构变化
- 确定事件/Action 流程
- 考虑边界情况

### 3. 实现顺序
1. **State** - 在 `core/store.lua` 添加新状态字段
2. **Actions** - 在 `core/actions.lua` 添加状态变更函数
3. **Events** - 如需要，在 `acp/events.lua` 添加新事件类型
4. **Transport** - 如需要，更新 transport 处理新事件
5. **Renderer** - 添加或更新渲染逻辑
6. **UI** - 添加窗口/缓冲区/快捷键
7. **Commands** - 添加用户命令
8. **Tests** - 添加测试覆盖
9. **Docs** - 更新文档

### 4. 验证
- 运行测试 `nvim --headless --clean -u NONE +"set rtp+=." +"luafile tests/run.lua" +q`
- 运行格式检查 `stylua --check lua plugin`
- 手动测试功能

## 常见功能实现参考

### 添加新的用户交互

```
State: 添加 pending_xxx 队列
Action: add_xxx / resolve_xxx / reject_xxx
UI: vim.ui.select() 或浮窗
Command: :OrchestrateXxx
```

### 添加数据持久化

```
State: 添加需要持久化的字段
Module: 创建 core/persistence.lua
Functions: save() / load() / get_path()
Trigger: 在 setup.lua 中 subscribe 变化时自动保存
```

### 添加外部集成

```
Module: 创建 integrations/xxx.lua
Check: 检测外部插件是否存在
Lazy: 延迟加载，只在需要时 require
Config: 在 config.lua 添加开关选项
```

## ROADMAP 功能索引

### Phase 1: 可用化
- `approval-interaction` - Approval 交互
- `review-interaction` - Review 交互
- `error-handling` - 错误处理增强
- `logging` - 日志系统

### Phase 2: 工作流化
- `session-persistence` - Session 持久化
- `multi-session` - 多会话管理
- `todo-interaction` - Todo 交互增强
- `draft-recovery` - 草稿恢复

### Phase 3: 项目集成化
- `context-management` - 上下文管理
- `command-execution` - 审批命令执行
- `review-code-linking` - Review 代码联动
- `external-integrations` - 外部集成

### Phase 4: 生态化
- `transport-plugin` - Transport 插件化
- `custom-renderer` - 自定义 Renderer
- `event-hooks` - 事件 Hook 机制
- `custom-workflow` - 自定义工作流
