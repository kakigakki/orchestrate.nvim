# CLAUDE.md

本文件为 Claude Code 在 orchestrate.nvim 代码库中工作提供指导。

## 项目概述

**orchestrate.nvim** 是一个 Neovim 插件，提供 AI 代理编排工作区，通过结构化的多缓冲区界面管理 AI 代理交互（主要是 Claude Code）。

### 架构

```
ACP (代理通信协议) → Store (状态) → Renderers (渲染器) → Buffers/Windows (缓冲区/窗口)
```

- **左侧面板 (Browse)**：只读的事件流，显示消息和助手响应
- **右上面板 (Todo)**：带状态标记的结构化任务列表
- **右下面板 (Input)**：可编辑的 Markdown 提示区（`:w` 发送）

## 项目结构

```
lua/orchestrate/
├── init.lua              # 主 API 导出 (setup, open, close, send, resume)
├── setup.lua             # 应用生命周期管理
├── config.lua            # 配置默认值和合并逻辑
├── acp/                   # 代理通信协议
│   ├── client.lua        # 传输抽象层
│   ├── events.lua        # 事件常量
│   ├── registry.lua      # 传输工厂/注册表
│   ├── builtins.lua      # 内置传输注册
│   └── transports/
│       ├── claude_code.lua   # Claude CLI 传输
│       └── mock.lua          # 用于测试的模拟传输
├── core/                  # 状态管理
│   ├── store.lua         # 类 Flux 的带订阅功能的存储
│   └── actions.lua       # 纯状态变更
├── renderers/             # 缓冲区渲染（纯函数）
│   ├── browse.lua        # 事件流查看器
│   ├── todo.lua          # 任务列表显示
│   └── input.lua         # 用户输入区
├── ui/                    # Neovim UI 层
│   ├── layout.lua        # 窗口/标签页管理
│   └── buffers.lua       # 缓冲区创建
└── commands/
    └── init.lua          # Vim 用户命令

plugin/orchestrate.lua    # Neovim 插件入口点
health/orchestrate.lua    # :checkhealth 实现
tests/run.lua             # 集成测试
```

## 构建和测试命令

```bash
# 运行测试
nvim --headless --clean -u NONE \
  +"set rtp+=." \
  +"luafile tests/run.lua" \
  +q

# 使用 StyLua 格式化代码
stylua lua plugin

# 验证插件正确加载
nvim --headless --clean -u NONE \
  +"set rtp+=." \
  +"lua require('orchestrate').setup({})" \
  +q
```

## 编码规范

### 风格
- **缩进**：2 个空格（StyLua 强制执行）
- **列宽**：100 字符
- **引号**：优先使用双引号
- **命名**：函数使用 `snake_case`，模块表使用大写 `M`

### 模式
- 模块模式：`local M = {}; M.__index = M; return M`
- 通过 `actions.lua` 进行纯状态变更
- 事件分发用于传输层 → 存储层通信
- 订阅模式用于存储层 → 渲染器更新
- 私有函数以下划线开头：`_private_fn()`

### 架构原则
- 传输层与状态管理解耦
- 状态与渲染解耦
- 渲染器是纯函数（除缓冲区变更外无副作用）
- 每个传输可独立实例化
- 配置/载荷以表形式传递

## 核心模块

| 模块 | 职责 |
|------|------|
| `core/store.lua` | 带订阅功能的不可变状态容器 |
| `core/actions.lua` | 纯状态转换器 (submit_prompt, stream_delta 等) |
| `acp/client.lua` | 与传输无关的 AI 代理接口 |
| `acp/registry.lua` | 命名传输的工厂 |
| `transports/claude_code.lua` | Claude CLI 适配器 (jobstart, stream-json 解析) |
| `transports/mock.lua` | 确定性测试传输 |

## 依赖

- **Neovim**：需支持 Lua API
- **claude CLI**：用于 Claude Code 传输
- 认证方式：`ANTHROPIC_API_KEY` 环境变量或 `~/.config/claude-code/auth.json`

## 用户命令

- `:OrchestrateOpen` - 打开工作区
- `:OrchestrateClose` - 关闭工作区
- `:OrchestrateSend [text]` - 提交消息
- `:OrchestrateResume [text]` - 通过会话 ID 恢复会话
- `:OrchestrateContinue [text]` - 继续上一个任务

## 错误处理

- 使用 `pcall()` 进行安全的错误处理
- 可能失败的操作返回 `(ok, error_string)` 元组
- 传输错误通过 `ERROR` 事件发出
- 可通过 `:checkhealth orchestrate` 进行健康检查
