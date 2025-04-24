# godoc-swagger.nvim

A Neovim plugin that provides syntax highlighting for Swagger annotations in Go files. Perfect for developers working with Go's Swagger API documentation.

![godoc-swagger screenshot](https://github.com/yourusername/godoc-swagger.nvim/raw/main/screenshots/godoc-swagger-demo.png)

## Features

- Intelligently highlights only genuine godoc Swagger annotations in Go files
- Only applies to comment blocks starting with `// godoc` and containing `@` annotations
- Preserves normal syntax highlighting for all non-Swagger code
- Real-time highlighting that updates as you type
- Works with default Rose Pine inspired color scheme out of the box
- Fully customizable colors to match your theme
- Highlights specific parts of Swagger annotations with detailed component-level coloring:
  - Tags (`@Summary`, `@Description`, etc.)
  - Parameters (`@Param`) with distinct highlighting for:
    - Parameter name
    - Location (path, query, etc.)
    - Data type
    - Required flag
    - Description
  - Success definitions (`@Success`) with distinct highlighting for:
    - Status code
    - Object type
    - Model name
    - Description
  - Failure definitions (`@Failure`) with the same detailed breakdown
  - Router paths (`@Router`) with separated highlighting for:
    - Path components
    - Path variables (like `{clientID}`) highlighted with a distinct color
    - HTTP methods
  - Security definitions (`@Security`)
  - Description text (in quotes)
- Automatic highlighting when opening Go files
- Manual re-highlighting with `:GodocHighlight` command
- Consistent highlighting that persists after colorscheme changes
- Folding support to collapse godoc blocks to their first line
- **NEW!** Navigate to model definitions from godoc comments:
  - Model references in `@Success` and `@Failure` annotations are highlighted and navigable
  - Use `:GodocGotoDefinition` or `<leader>gd` to jump to the definition of the referenced type
  - Visual underlines show which model references can be navigated

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/godoc-swagger.nvim",
  event = { "BufReadPre *.go", "BufNewFile *.go" },
  config = true, -- Uses the default configuration
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/godoc-swagger.nvim",
  config = function()
    require("godoc-swagger").setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'yourusername/godoc-swagger.nvim'

" In your init.vim, after plug#end():
lua require('godoc-swagger').setup()
```

## Configuration

The plugin works with zero configuration, but you can customize it to your preferences:

```lua
require('godoc-swagger').setup({
  -- Customize colors (optional)
  colors = {
    -- Basic annotation colors
    comment = '#585273',       -- Base color for comment lines in godoc blocks
    tag = '#a794c7',           -- Tags like @Summary, @Description
    param = '#c9a5a3',         -- Base color for @Param
    success = '#87b3ba',       -- Base color for @Success
    failure = '#c26580',       -- Base color for @Failure
    router = '#d1a86a',        -- Base color for @Router
    description = '#7d7a93',   -- Description tag
    security = '#c78d8b',      -- Base color for @Security
    status_code = '#87b3ba',   -- HTTP status codes
    type_keyword = '#656380',  -- Type keywords like {object}
    type_object = '#2e647c',   -- Type identifiers
    description_text = '#6e6a86', -- Text in descriptions
    
    -- Detailed component colors
    param_name = '#b3a5d3',    -- Parameter name 
    param_location = '#c9a5a3', -- Parameter location (path, query, etc)
    param_type = '#9abbc7',    -- Parameter type (string, int, etc)
    param_required = '#e09a8c', -- Parameter required flag (true/false)
    
    router_path = '#c19557',   -- Router path (more muted than main router color)
    router_path_var = '#c2a37b', -- Router path variables in curly braces {varName}
    router_method = '#bfa36a', -- Router method ([get], [post], etc)
    
    security_scheme = '#dda3a1', -- Security scheme name
    
    -- LSP navigation features - Response models (Success/Failure)
    model_reference = '#6d8a82', -- Response model references (root level)
    model_reference_l1 = '#5e7870', -- Level 1 nested generic 
    model_reference_l2 = '#50655f', -- Level 2 nested generic
    model_reference_l3 = '#41534e', -- Level 3+ nested generic
    
    -- Request models (@Param models)
    request_model_reference = '#7a8775', -- Request model references (root level)
    request_model_reference_l1 = '#697466', -- Level 1 nested generic
    request_model_reference_l2 = '#5a6458', -- Level 2 nested generic
    request_model_reference_l3 = '#4a534a' -- Level 3+ nested generic
  },
  
  -- File patterns to apply highlighting to (optional)
  patterns = {'*.go'}, -- Default is Go files only
  
  -- Enable debug mode for troubleshooting highlighting issues
  debug_mode = false, -- Set to true to see detailed information about detected blocks
  
  -- Enable folding support (default: true)
  enable_folding = true, -- Set to false to disable godoc block folding
  
  -- Enable LSP-like features for godoc model navigation (default: true)
  enable_lsp = true, -- Set to false to disable model reference navigation
  
  -- Navigation style for going to definitions (default: "snacks")
  -- "snacks" = Use Snacks picker UI specifically (recommended)
  -- "picker" = Use Telescope or Snap picker UI
  -- "direct" = Go directly to definition when possible 
  -- "hover" = Attempt to use a hover-style window that closes after selection
  lsp_navigation_style = "snacks", -- Choose your preferred navigation style
  
  -- Custom keybinding for going to definitions (default: nil which maps to <leader>gd)
  -- Set to false to disable automatic keybinding completely
  -- Example: goto_definition_key = "gZ" for a custom mapping
  goto_definition_key = nil,
})
```

## Usage

The plugin automatically applies highlighting when you open `.go` files. If you need to reapply highlighting manually, use:

```
:GodocHighlight
```

### Model Navigation

The plugin adds navigation capabilities for model types referenced in godoc comments:

```
:GodocGotoDefinition  - Jump to the definition of the model under cursor
:GodocHighlightModels - Re-highlight model references in the current buffer
```

When your cursor is on a model name like `models.User` in a `@Success`, `@Failure`, or `@Param` annotation,
you can press `<leader>gd` to jump to its definition in your code (or your custom keybinding if configured).

Model references are automatically underlined to show they are navigable, with different colors for response models 
(`@Success`/`@Failure`) and request models (`@Param`). There are four navigation styles:

1. **Snacks (default)** - Uses the Snacks picker which automatically closes after selection
2. **Picker** - Uses Telescope to show all matching symbols in a dropdown list
3. **Direct** - Jumps directly to the definition when possible
4. **Hover** - Attempts to use a hover-style window that closes after selection

You can configure your preferred style in your Neovim config:

```lua
require('godoc-swagger').setup({
  lsp_navigation_style = "picker" -- Set to "direct", "picker", or "hover"
})
```

This feature helps you:

1. Quickly check the structure of models used in your API responses
2. Ensure consistency between documentation and code
3. Navigate between API endpoints and their related models
4. Handle complex generic types with multiple component parts

### Folding

The plugin provides folding support for godoc comment blocks using one of two approaches:

#### Hiding Godoc Blocks

The plugin provides four approaches to hide godoc blocks, with increasing levels of compatibility with other folding systems:

**1. Extmark-Based Approach (RECOMMENDED, fully compatible with UFO):**
- `zgd` - Toggle godoc blocks using extmarks (won't affect folding)

Commands:
```
:GodocToggle      - Toggle godoc blocks using extmarks (UFO compatible)
```

This approach uses Neovim's extmark feature to visually hide the content without changing the buffer or interfering with folding systems. It's the most compatible option for use with nvim-ufo or other folding plugins.

**2. Conceal-Based Approach (fairly compatible with UFO):**
- `zC` - Toggle concealment of godoc blocks

Commands:
```
:GodocToggleConceal - Toggle concealment of all godoc blocks
```

This approach doesn't use the folding system but relies on Vim's concealment feature.

**3. Traditional Folding with Auto-Registration (NEW! Most intuitive):**
- Automatically registers godoc blocks as foldable regions but keeps them open by default
- Use normal Vim fold commands (`za`, `zc`, `zo`) to interact with the godoc blocks
- `zgR` - Re-register all godoc blocks if folding gets disrupted
- `zgO` - Unfold all godoc blocks in the file

Commands:
```
:GodocRegisterFolds - Register all godoc blocks as foldable regions (without folding them)
:GodocUnfold - Unfold all godoc blocks in the file
```

This approach now automatically marks godoc blocks as foldable regions without actually folding them, allowing you to use standard Vim fold commands to open and close them. This gives the most natural folding experience while preserving compatibility with other folding systems.

**4. Manual Fold Creation (compatible with other folding plugins):**
- `zG` - Create folds for all godoc blocks in the file and collapse them

Commands:
```
:GodocFold        - Create folds for all godoc blocks in the current file and fold them
:GodocFoldDebug   - Attempt to fold the block under cursor with detailed debugging output
```

This approach uses Vim's manual folding to create folds for godoc blocks, but has been improved to work alongside other folding systems like nvim-ufo without disrupting them.

**Troubleshooting:**
If you're having trouble with folding godoc blocks:
1. Try using the standard Vim fold commands (`za`, `zc`, `zo`) after opening a Go file, as the plugin now automatically registers godoc blocks as foldable regions
2. If standard fold commands don't work, use `zgR` or `:GodocRegisterFolds` to force re-registration of godoc blocks
3. Try the extmark-based approach with `zgd` or `:GodocToggle` if you prefer hiding blocks completely
4. If those don't work, try the conceal approach with `zC` or `:GodocToggleConceal`

#### Integration with nvim-ufo

For users of [nvim-ufo](https://github.com/kevinhwang91/nvim-ufo), the plugin provides a folding provider to integrate with UFO's advanced folding system:

```lua
-- In your UFO setup configuration
require('ufo').setup({
  provider_selector = function(bufnr, filetype, buftype)
    if filetype == 'go' then
      -- Use godoc-swagger's fold provider for Go files
      return {'godoc-swagger', 'treesitter', 'indent'}
    end
    return {'treesitter', 'indent'}
  end,
  -- Register the provider
  providers = {
    ['godoc-swagger'] = function(bufnr)
      return require('godoc-swagger').folds.get_folding_ranges(bufnr)
    end
  }
})
```

This integration works seamlessly with UFO's other folding features, enabling you to use godoc block folding alongside your existing folding setup.

Each godoc block will fold to a single line showing the initial godoc comment and a count of swagger annotations, helping clean up the display while still making the API documentation accessible when needed.

### Comment Format Requirements

For comments to be detected and highlighted as Swagger annotations, they must:

1. Start with a line that includes the word "godoc" (typically `// FunctionName godoc`)
2. Include subsequent lines with Swagger annotations starting with "@"
3. Each annotation line should start with `// @` 

The highlighting only applies to properly formatted godoc blocks, preserving normal syntax highlighting for all other code and comments.

### Troubleshooting

If your godoc blocks aren't being highlighted:

1. Make sure your first comment line contains "godoc" (e.g., `// GetUserByID godoc`)
2. Verify your annotation lines start with `// @` 
3. Try enabling debug mode in your configuration:

```lua
require('godoc-swagger').setup({
  debug_mode = true
})
```

This will show notification messages with details about detected godoc blocks.

## Example

Here's how your Go Swagger annotations will look with this plugin:

```go
// GetUserByID godoc
// @Summary Get user by ID
// @Description Retrieves a user's information by their unique identifier
// @Tags users
// @Accept json
// @Produce json
// @Param id path int true "User ID"
// @Success 200 {object} models.User
// @Failure 404 {object} models.ErrorResponse
// @Failure 500 {object} models.ErrorResponse
// @Router /users/{id} [get]
// @Security Bearer
func GetUserByID(c *gin.Context) {
    // Implementation
    // This comment won't get highlighted since it's not part of the godoc block
}

// Regular comments like this won't be affected
// Only comments that start with // [function name] godoc
// And have @ annotations will be highlighted
```

## Planned Features

Here are some features that could be added in future versions:

- [ ] Integration with LSP for popup documentation of Swagger annotations
- [ ] Auto-completion of Swagger annotation tags
- [ ] Preview of generated Swagger documentation
- [ ] Support for additional Swagger annotation syntaxes (like those used in other languages)
- [ ] Linting and validation of Swagger annotations
- [ ] Code folding specific to Swagger comment blocks
- [ ] Quick jumping between annotation blocks with navigation commands

## Contributing

Contributions are welcome! Feel free to open issues or pull requests.

## License

MIT

## Acknowledgements

- Inspired by the beautiful [Rose Pine](https://github.com/rose-pine/neovim) color scheme
- Thanks to the Neovim community for their support and feedback