-- Plugin loader for godoc-swagger
-- This file is automatically loaded by Neovim

if vim.g.loaded_godoc_swagger == 1 then
  return
end
vim.g.loaded_godoc_swagger = 1

-- Set up the plugin with default configuration
require('godoc-swagger').setup()