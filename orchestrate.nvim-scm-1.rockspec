package = "orchestrate.nvim"
version = "scm-1"
source = {
  url = "https://github.com/kakigakki/orchestrate.nvim",
}
description = {
  summary = "Agent orchestration workspace for Neovim",
  homepage = "https://github.com/kakigakki/orchestrate.nvim",
  license = "MIT",
}
build = {
  type = "builtin",
  modules = {
    ["orchestrate"] = "lua/orchestrate/init.lua",
    ["orchestrate.setup"] = "lua/orchestrate/setup.lua",
    ["orchestrate.config"] = "lua/orchestrate/config.lua",
    ["orchestrate.acp.registry"] = "lua/orchestrate/acp/registry.lua",
    ["orchestrate.acp.builtins"] = "lua/orchestrate/acp/builtins.lua",
    ["orchestrate.acp.client"] = "lua/orchestrate/acp/client.lua",
    ["orchestrate.acp.events"] = "lua/orchestrate/acp/events.lua",
    ["orchestrate.acp.transports.mock"] = "lua/orchestrate/acp/transports/mock.lua",
    ["orchestrate.acp.transports.claude_code"] = "lua/orchestrate/acp/transports/claude_code.lua",
    ["orchestrate.core.store"] = "lua/orchestrate/core/store.lua",
    ["orchestrate.core.actions"] = "lua/orchestrate/core/actions.lua",
    ["orchestrate.renderers.browse"] = "lua/orchestrate/renderers/browse.lua",
    ["orchestrate.renderers.todo"] = "lua/orchestrate/renderers/todo.lua",
    ["orchestrate.renderers.input"] = "lua/orchestrate/renderers/input.lua",
    ["orchestrate.ui.layout"] = "lua/orchestrate/ui/layout.lua",
    ["orchestrate.ui.buffers"] = "lua/orchestrate/ui/buffers.lua",
    ["orchestrate.commands"] = "lua/orchestrate/commands/init.lua",
  },
}
