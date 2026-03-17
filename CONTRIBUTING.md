# Contributing

Thanks for contributing to `orchestrate.nvim`.

## Development

1. Clone the repository.
2. Add the plugin to your `lazy.nvim` config with `dir = "/path/to/orchestrate.nvim"`.
3. Open Neovim and run `:OrchestrateOpen`.

## Style

- Format Lua with `stylua`.
- Keep ACP transport, state updates, and rendering separated.
- Prefer extending the actions/store flow instead of mutating UI state directly.

## Local Checks

```sh
stylua lua plugin
nvim --headless --clean -u NONE +"set rtp+=." +"lua require('orchestrate').setup({})" +q
```

## Pull Requests

- Keep the scope focused.
- Include reproduction steps for bug fixes.
- Update `README.md` or `doc/orchestrate.txt` when behavior changes.
