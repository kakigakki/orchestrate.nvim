if vim.g.loaded_orchestrate_nvim == 1 then
  return
end

vim.g.loaded_orchestrate_nvim = 1

require("orchestrate").setup()
