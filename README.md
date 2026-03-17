# orchestrate.nvim

`orchestrate.nvim` 是一个面向 Neovim 的 Agent Orchestration Workspace。

它不是聊天 UI，也不是终端包装器，而是一个围绕 Agent 工作流组织出来的多缓冲区工作区：

`ACP -> Store -> Renderer -> Buffers/Windows`

## 特性

- 三栏工作区
- 左侧 `Browse` 只读事件流
- 右上 `Todo` 只读结构化任务
- 右下 `Input` 可编辑输入区，`:w` 直接发送
- 所有状态更新统一走 actions
- renderer 与 ACP 解耦
- 内置 mock ACP，可直接演示完整链路
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
  dir = "C:/orchestrate",
  name = "orchestrate.nvim",
  main = "orchestrate",
  opts = {},
}
```

如果你想按命令懒加载，也可以这样写：

```lua
{
  "kakigakki/orchestrate.nvim",
  main = "orchestrate",
  cmd = { "OrchestrateOpen", "OrchestrateClose", "OrchestrateSend" },
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
  mock = {
    enabled = true,
    chunk_delay = 160,
  },
})
```

## 使用

1. 执行 `:OrchestrateOpen`
2. 在 `Input` buffer 输入内容
3. 执行 `:w`
4. 在 `Browse` 查看用户提交与助手流式事件
5. 在 `Todo` 查看任务更新

也可以直接执行：

```vim
:OrchestrateSend 为当前项目拆分下一步任务
```

## 命令

- `:OrchestrateOpen`
- `:OrchestrateClose`
- `:OrchestrateSend [text]`

## 开发说明

- `plugin/orchestrate.lua` 提供标准插件入口
- `setup()` 是幂等的，适合 `lazy.nvim` 的 `opts` 调用
- `doc/orchestrate.txt` 提供 `:h orchestrate` 帮助文档
- 当前 ACP 为 mock 实现，后续可以无缝替换真实传输层

## 开源协作

- CI 工作流见 `.github/workflows/ci.yml`
- issue 模板与 PR 模板已添加
- 贡献说明见 `CONTRIBUTING.md`
- 变更记录见 `CHANGELOG.md`

## 许可证

[MIT](./LICENSE)
