# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - Unreleased

### Added

- **Approval 交互**
  - `resolve_approval` action 处理 accept/reject 决策
  - `vim.ui.select` 交互界面
  - `:OrchestrateApprove` 命令批准待审批项
  - `:OrchestrateReject` 命令拒绝待审批项
  - `:OrchestrateApprovalSelect` 命令选择特定审批处理
  - Todo 面板显示待审批项详情

- **Review 交互**
  - `mark_review_seen` action 标记审查为已读
  - `mark_all_reviews_seen` action 标记所有审查为已读
  - `:OrchestrateReviewJump` 命令跳转到未读审查
  - `:OrchestrateReviewSelect` 命令选择审查跳转
  - `:OrchestrateReviewQuickfix` 命令添加审查到 quickfix
  - Todo 面板显示审查项（含文件位置和状态）

- **错误处理增强**
  - `retry_last` action 重置错误状态
  - `:OrchestrateRetry` 命令重试上一条消息
  - Todo 面板显示错误信息和重试提示

- **日志系统**
  - `utils/logger.lua` 模块支持 debug/info/warn/error 级别
  - 配置选项 `debug.enabled`, `debug.log_level`, `debug.to_file`
  - 关键路径添加日志记录

- **其他改进**
  - `:OrchestrateToggle` 命令切换工作区
  - Store 新增 `resolved_approvals` 字段
  - Todo 面板增强显示（状态图标、文件位置、命令提示）
  - 新增 Approval/Review 到达时的通知

### Changed

- Todo renderer 重构，支持更丰富的信息展示
- 测试覆盖率提升，新增 Approval/Review/Error 相关测试

## [0.1.0] - 2026-03-17

### Added

- Initial open-source plugin scaffold
- MVP orchestration workspace with three-panel layout
- Claude Code transport with CLI integration
- Mock transport for development and testing
- Basic commands: Open, Close, Send, Resume, Continue
- Health check support (`:checkhealth orchestrate`)
- CI workflow with StyLua and tests
