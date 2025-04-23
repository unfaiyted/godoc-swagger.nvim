# godoc-swagger.nvim Development Guidelines

## Development Commands
- No build commands (Neovim plugin)
- No specific test framework
- Manual testing: Open a Go file with Swagger annotations after loading the plugin
- Verify highlighting: `:GodocHighlight` to manually apply highlighting
- Local development with lazy.nvim: Add to your config:
  ```lua
  { 
    dir = "~/codebase/godoc-swagger.nvim",
    config = true,
    event = { "BufReadPre *.go", "BufNewFile *.go" }
  }
  ```

## Code Style Guidelines
- **Formatting**: 2-space indentation for Lua
- **Naming**:
  - Module table: `M` for exports
  - Functions: `snake_case` (e.g., `apply_highlighting`)
  - Variables: `snake_case` (e.g., `default_colors`, `highlight_cmds`)
  - Highlight groups: CamelCase prefixed with `GodocSwagger` (e.g., `GodocSwaggerTag`)
- **Module Structure**:
  - Main functionality in `lua/godoc-swagger/init.lua`
  - Plugin loader in `plugin/godoc-swagger.lua`
  - Documentation in `doc/godoc-swagger.txt`
- **Error Handling**: Minimal (UI plugin)
- **Comments**: Document function purpose and key sections
- **Color Definitions**: Use hexadecimal format for colors
- **API**: Provide a `setup()` function with configurable options
- **AutoCmds**: Group related autocommands with `vim.api.nvim_create_augroup`
- **User Commands**: Use `vim.api.nvim_create_user_command` for plugin commands