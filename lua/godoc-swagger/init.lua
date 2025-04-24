-- Godoc Swagger highlighting plugin for Neovim
-- This module is loaded by require('godoc-swagger')

local M = {}
local M_folds = {}

-- Function to find godoc swagger blocks in the buffer
local function find_godoc_blocks(bufnr)
  -- Get buffer content
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local current_block = nil
  local in_potential_godoc_block = false
  local found_godoc_marker = false
  
  for i, line in ipairs(lines) do
    local is_comment = line:match("^%s*//")
    
    if is_comment then
      -- Check if this is a godoc marker line
      if line:match("//.*godoc") then
        -- This is definitely a godoc block
        found_godoc_marker = true
        current_block = current_block or {start_line = i, end_line = i}
        in_potential_godoc_block = true
      elseif line:match("^%s*// @%w+") then
        -- Line with @ annotation 
        if in_potential_godoc_block or found_godoc_marker then
          -- Either this is a continuation of a godoc block
          -- or we found an @ line right after a godoc marker
          current_block = current_block or {start_line = i, end_line = i}
          current_block.end_line = i
          
          -- If we didn't have a block before but have an @ line, 
          -- make sure to include any previous comment lines that might be part of this block
          if not found_godoc_marker and in_potential_godoc_block and i > 1 then
            -- Look back for connected comment lines
            local j = i - 1
            while j >= 1 and lines[j]:match("^%s*//") do
              current_block.start_line = j
              j = j - 1
            end
          end
        end
      elseif in_potential_godoc_block and current_block then
        -- Regular comment line following a godoc block or @ line
        -- We'll include it as part of the block for now
        current_block.end_line = i
      end
    else
      -- Not a comment line
      if current_block then
        -- End of a comment block - add it to our blocks if it had @ lines
        if found_godoc_marker then
          table.insert(blocks, current_block)
        end
        current_block = nil
        found_godoc_marker = false
      end
      in_potential_godoc_block = false
    end
  end
  
  -- Add the last block if we had one
  if current_block and found_godoc_marker then
    table.insert(blocks, current_block)
  end
  
  return blocks
end

-- Define highlighting function
function M.apply_highlighting()
  vim.fn.clearmatches() -- Clear existing matches to avoid duplicates
  
  -- Find godoc blocks in the document
  local blocks = find_godoc_blocks()
  if #blocks == 0 then
    -- Only show warning in debug mode
    if M.debug_mode then
      vim.api.nvim_echo({ { 'No godoc blocks found', 'WarningMsg' } }, true, {})
    end
    return
  end
  
  -- Debug info
  if M.debug_mode then
    vim.notify("Found " .. #blocks .. " godoc blocks", vim.log.levels.INFO)
    for i, block in ipairs(blocks) do
      local block_content = table.concat(vim.api.nvim_buf_get_lines(0, block.start_line - 1, block.end_line, false), "\n")
      vim.notify(string.format("Block %d (lines %d-%d):\n%s", i, block.start_line, block.end_line, block_content), vim.log.levels.INFO)
    end
  end
  
  -- Define a single function for creating regex patterns with line constraints
  local function line_constrained_pattern(pattern, start_line, end_line)
    return '\\%>' .. (start_line-1) .. 'l\\%<' .. (end_line+1) .. 'l' .. pattern
  end
  
  -- Instead of using complex line range patterns, we'll iterate through each block
  -- and apply highlighting specifically for that range
  for _, block in ipairs(blocks) do
    local start_line = block.start_line
    local end_line = block.end_line
    
    -- First, highlight the godoc comment line itself (special emphasis)
    vim.fn.matchadd('GodocSwaggerGodocLine', line_constrained_pattern('//.*godoc', start_line, start_line), 101)
    
    -- Create a highlight for the whole comment block for debugging
    if M.debug_mode then
      vim.fn.matchadd('GodocSwaggerDebugBlock', line_constrained_pattern('//.*', start_line, end_line), 10)
    end
    
    -- First highlight all comment lines in the godoc block to establish a base color
    vim.fn.matchadd('GodocSwaggerComment', line_constrained_pattern('//', start_line, end_line), 90)
    
    -- Completely different approach: use very specific matches for each component type
    -- regardless of context
    
    -- Tag annotations - highest priority
    vim.fn.matchadd('GodocSwaggerParam', line_constrained_pattern('@Param', start_line, end_line), 105)
    vim.fn.matchadd('GodocSwaggerSuccess', line_constrained_pattern('@Success', start_line, end_line), 105)
    vim.fn.matchadd('GodocSwaggerFailure', line_constrained_pattern('@Failure', start_line, end_line), 105)
    vim.fn.matchadd('GodocSwaggerRouter', line_constrained_pattern('@Router', start_line, end_line), 105)
    vim.fn.matchadd('GodocSwaggerSecurity', line_constrained_pattern('@Security', start_line, end_line), 105)
    vim.fn.matchadd('GodocSwaggerTag', line_constrained_pattern('@\\(Summary\\|Description\\|Tags\\|Accept\\|Produce\\)', start_line, end_line), 105)
    
    -- Status codes - match any HTTP status code regardless of context
    vim.fn.matchadd('GodocSwaggerStatusCode', line_constrained_pattern('\\s\\+\\(\\d\\{3}\\)\\s\\+', start_line, end_line), 103)
    
    -- Type keywords - match anything in braces regardless of context
    vim.fn.matchadd('GodocSwaggerTypeKeyword', line_constrained_pattern('{[^}]*}', start_line, end_line), 103)
    
    -- Path components - match URL paths, but specifically for @Router lines
    -- First highlight the entire path (from @Router to the opening bracket)
    vim.fn.matchadd('GodocSwaggerRouterPath', line_constrained_pattern('@Router\\s\\+/[^\\[]*', start_line, end_line), 103)
    
    -- Then highlight variables in curly braces with higher priority
    vim.fn.matchadd('GodocSwaggerRouterPathVar', line_constrained_pattern('{[^}]*}', start_line, end_line), 104)
    
    -- Methods in brackets - match anything in square brackets
    vim.fn.matchadd('GodocSwaggerRouterMethod', line_constrained_pattern('\\s\\+\\[[^\\]]*\\]', start_line, end_line), 103)
    
    -- Model types - match model names (word with possible dots and brackets)
    -- Only apply if LSP features are disabled, otherwise the LSP module will handle this with graduated colors
    if not M.enable_lsp then
      -- This is challenging but try to match common patterns
      vim.fn.matchadd('GodocSwaggerTypeObject', line_constrained_pattern('\\s\\+[A-Za-z]\\w*\\.[A-Za-z]\\w*\\(\\[[^\\]]*\\]\\)*', start_line, end_line), 103)
    end
    
    -- Required flags - match true/false
    vim.fn.matchadd('GodocSwaggerParamRequired', line_constrained_pattern('\\s\\+\\(true\\|false\\)\\s\\+', start_line, end_line), 103)
    
    -- Descriptions - match quoted text anywhere
    vim.fn.matchadd('GodocSwaggerDescriptionText', line_constrained_pattern('"[^"]*"', start_line, end_line), 103)
    
    -- Parameter names - match first word after @Param
    vim.fn.matchadd('GodocSwaggerParamName', line_constrained_pattern('@Param\\s\\+\\(\\w\\+\\)', start_line, end_line), 103)
    
    -- Parameter locations - common location types
    vim.fn.matchadd('GodocSwaggerParamLocation', line_constrained_pattern('\\s\\+\\(path\\|query\\|body\\|header\\|formData\\)\\s\\+', start_line, end_line), 103)
    
    -- Parameter types - common type names
    vim.fn.matchadd('GodocSwaggerParamType', line_constrained_pattern('\\s\\+\\(string\\|integer\\|number\\|boolean\\|array\\|object\\|int\\|float\\)\\s\\+', start_line, end_line), 103)
    
    -- Security schemes - match words after @Security
    vim.fn.matchadd('GodocSwaggerSecurityScheme', line_constrained_pattern('@Security\\s\\+\\(\\w\\+\\)', start_line, end_line), 103)
    
    -- Special highlight for the first godoc line
    vim.fn.matchadd('GodocSwaggerGodocLine', line_constrained_pattern('//.*godoc.*$', start_line, start_line), 110)
  end
  
  -- Print a message only in debug mode
  if M.debug_mode then
    vim.api.nvim_echo({ { 'Godoc Swagger highlighting applied to ' .. #blocks .. ' block(s)', 'Normal' } }, true, {})
  end
end

-- Expose find_godoc_blocks for use by other modules
M.find_godoc_blocks = find_godoc_blocks

-- Function to find the boundaries of a godoc block starting at a line
local function find_godoc_block(bufnr, start_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, start_line + 100, false)
  local end_line = start_line
  
  -- Check if the current line is a godoc header
  if not lines[1] or not lines[1]:match("//.*godoc") then
    return nil
  end
  
  -- Find where the godoc block ends
  for i, line in ipairs(lines) do
    if i > 1 then -- Skip the first line as we've already processed it
      if line:match("^%s*// @%w+") then
        -- This is a swagger annotation, include it in the block
        end_line = start_line + i - 1
      elseif not line:match("^%s*//") then
        -- Not a comment line, block ends
        break
      end
    end
  end
  
  if end_line > start_line then
    return {
      startRow = start_line,
      endRow = end_line,
      kind = "godoc_swagger"
    }
  end
  
  return nil
end

-- Fold provider function for UFO compatibility
function M_folds.get_folding_ranges(bufnr)
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    return {}
  end
  
  local ranges = {}
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- Look through the buffer for godoc blocks
  for i = 0, line_count - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    
    -- If this is a godoc header line
    if line and line:match("//.*godoc") then
      local block_range = find_godoc_block(bufnr, i)
      if block_range then
        table.insert(ranges, block_range)
        -- Skip to end of this block to avoid processing it again
        i = block_range.endRow
      end
    end
  end
  
  return ranges
end

-- Fold text handler for UFO compatibility  
function M_folds.fold_virt_text_handler(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local suffix = (' 󰏫 %d swagger annotations'):format(endLnum - lnum)
  local sufWidth = vim.fn.strdisplaywidth(suffix)
  local targetWidth = width - sufWidth
  local curWidth = 0
  
  for _, chunk in ipairs(virtText) do
    local chunkText = chunk[1]
    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
    
    if targetWidth > curWidth + chunkWidth then
      table.insert(newVirtText, chunk)
    else
      chunkText = truncate(chunkText, targetWidth - curWidth)
      local hlGroup = chunk[2]
      table.insert(newVirtText, {chunkText, hlGroup})
      chunkWidth = vim.fn.strdisplaywidth(chunkText)
      -- str width returned from truncate() may less than 2nd argument, need padding
      if curWidth + chunkWidth < targetWidth then
        suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
      end
      break
    end
    
    curWidth = curWidth + chunkWidth
  end
  
  table.insert(newVirtText, {'', 'MoreMsg'})
  table.insert(newVirtText, {suffix, 'MoreMsg'})
  
  return newVirtText
end

-- Direct fold command implementation
-- UFO-compatible extmark-based solution for hiding godoc blocks
-- This doesn't use folding or concealing so it won't interfere with UFO
function M_folds.toggle_godoc_blocks()
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    if M.debug_mode then
      vim.notify('Not a Go file', vim.log.levels.WARN)
    end
    return
  end
  
  -- Create a namespace for our virtual text if it doesn't exist yet
  if not vim._godoc_ns then
    vim._godoc_ns = vim.api.nvim_create_namespace('godoc_swagger')
  end
  
  -- Check if we have hidden blocks in this buffer
  if vim.b[bufnr].godoc_hidden then
    -- Clear all virtual text and extmarks
    vim.api.nvim_buf_clear_namespace(bufnr, vim._godoc_ns, 0, -1)
    vim.b[bufnr].godoc_hidden = false
    if M.debug_mode then
      vim.notify('Godoc blocks revealed', vim.log.levels.INFO)
    end
    return
  end
  
  -- Get all godoc blocks
  local ranges = M_folds.get_folding_ranges(bufnr)
  local hidden_count = 0
  
  -- Process each block - hide all but the first line
  for _, range in ipairs(ranges) do
    if range.endRow > range.startRow then
      -- Calculate how many lines to hide
      local hidden_lines = range.endRow - range.startRow
      
      -- First line is the header, leave it visible
      local header_line = vim.api.nvim_buf_get_lines(bufnr, range.startRow, range.startRow + 1, false)[1]
      
      -- Replace all lines except the first with virtual text
      for i = range.startRow + 1, range.endRow do
        -- Hide the line by replacing it with empty virtual text,
        -- after the first line, add a marker showing how many lines are hidden
        if i == range.startRow + 1 then
          -- Add virtual text for the first hidden line
          vim.api.nvim_buf_set_extmark(bufnr, vim._godoc_ns, i, 0, {
            virt_lines = {{{" [" .. hidden_lines .. " swagger annotations hidden]", "Comment"}}},
            virt_lines_above = true  -- Show it above the line
          })
        end
        
        -- Hide this line's contents
        vim.api.nvim_buf_set_extmark(bufnr, vim._godoc_ns, i, 0, {
          hl_mode = "replace",         -- Replace entire line
          end_col = 0,                 -- End at the end of line
          hl_group = "Conceal",        -- Use Conceal highlighting
          ephemeral = false,           -- Persist this marking
          priority = 101               -- High priority to override other highlights
        })
      end
      
      hidden_count = hidden_count + 1
    end
  end
  
  vim.b[bufnr].godoc_hidden = true
  if M.debug_mode then
    vim.notify('Hidden ' .. hidden_count .. ' godoc blocks', vim.log.levels.INFO)
  end
end

-- Traditional conceal method as backup
function M_folds.toggle_conceal_godoc_blocks()
  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()
  
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    if M.debug_mode then
      vim.notify('Not a Go file', vim.log.levels.WARN)
    end
    return
  end
  
  -- Initialize buffer variable if it doesn't exist
  if vim.b[bufnr].godoc_concealed == nil then
    vim.b[bufnr].godoc_concealed = {}
  end
  
  -- Check if we already have matches for this buffer
  if #vim.b[bufnr].godoc_concealed > 0 then
    -- Remove existing conceals
    for _, match_id in ipairs(vim.b[bufnr].godoc_concealed) do
      pcall(vim.fn.matchdelete, match_id)
    end
    vim.b[bufnr].godoc_concealed = {}
    if M.debug_mode then
      vim.notify('Godoc blocks revealed (conceal method)', vim.log.levels.INFO)
    end
    
    -- Also reset conceal settings for current window
    vim.wo[winnr].conceallevel = 0
    return
  end
  
  -- Get all godoc blocks
  local ranges = M_folds.get_folding_ranges(bufnr)
  local conceal_count = 0
  
  -- Set up concealment for current window
  vim.wo[winnr].conceallevel = 2
  
  -- Conceal all godoc blocks except their first line
  for _, range in ipairs(ranges) do
    -- Skip blocks with just one line
    if range.endRow > range.startRow then
      -- Count lines being concealed
      local concealed_lines = range.endRow - range.startRow
      
      -- Create a conceal for the block from line 2 to end
      local pattern = '\\%>' .. range.startRow .. 'l\\%<' .. (range.endRow + 1) .. 'l.*'
      
      -- Add the conceal match
      local match_id = vim.fn.matchadd('Conceal', pattern, 100, -1, { conceal = '⋯' })
      table.insert(vim.b[bufnr].godoc_concealed, match_id)
      
      conceal_count = conceal_count + 1
    end
  end
  
  if M.debug_mode then
    vim.notify('Concealed ' .. conceal_count .. ' godoc blocks', vim.log.levels.INFO)
  end
end

-- Register godoc blocks as foldable regions but keep them open
function M_folds.register_godoc_folds()
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    if M.debug_mode then
      vim.notify('Not a Go file', vim.log.levels.WARN)
    end
    return
  end
  
  -- Get all godoc blocks without changing folding method
  local ranges = M_folds.get_folding_ranges(bufnr)
  local fold_count = 0
  
  -- We'll use a more sophisticated approach to register folds
  -- Store the current fold settings to restore them later
  local old_fdm = vim.wo.foldmethod
  local old_foldminlines = vim.wo.foldminlines
  local old_foldlevel = vim.wo.foldlevel
  
  -- Create folds in a way that keeps them open
  if #ranges > 0 then
    -- Set foldmethod to manual temporarily
    vim.wo.foldmethod = 'manual'
    
    -- Create all folds but keep them open
    for _, range in ipairs(ranges) do
      local start_line = range.startRow + 1  -- Convert to 1-indexed for Vim commands
      local end_line = range.endRow + 1      -- Convert to 1-indexed for Vim commands
      
      -- Create the fold
      pcall(function() 
        vim.cmd(start_line .. ',' .. end_line .. 'fold')
      end)
      fold_count = fold_count + 1
    end
    
    -- Open all folds to make them initially expanded
    pcall(function() vim.cmd('normal! zR') end)
    
    -- Restore original fold settings
    vim.wo.foldmethod = old_fdm
    vim.wo.foldminlines = old_foldminlines
    vim.wo.foldlevel = old_foldlevel
  end
  
  if M.debug_mode then
    vim.notify('Registered ' .. fold_count .. ' godoc blocks as foldable (but kept expanded)', vim.log.levels.INFO)
  end
  
  -- Store the folds in a buffer variable so we know they're registered
  vim.b.godoc_folds_registered = true
end

-- Unfold all godoc blocks in the buffer
function M_folds.unfold_godoc_blocks()
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    if M.debug_mode then
      vim.notify('Not a Go file', vim.log.levels.WARN)
    end
    return
  end
  
  -- Get all godoc blocks
  local ranges = M_folds.get_folding_ranges(bufnr)
  local unfold_count = 0
  
  -- Unfold each godoc block
  for _, range in ipairs(ranges) do
    local start_line = range.startRow + 1  -- Convert to 1-indexed for Vim commands
    local end_line = range.endRow + 1      -- Convert to 1-indexed for Vim commands
    
    -- Open the fold for this range
    pcall(function() vim.cmd(start_line .. ',' .. end_line .. 'foldopen') end)
    unfold_count = unfold_count + 1
  end
  
  if M.debug_mode then
    vim.notify('Unfolded ' .. unfold_count .. ' godoc blocks', vim.log.levels.INFO)
  else if unfold_count > 0 then
    vim.notify('Unfolded ' .. unfold_count .. ' godoc blocks', vim.log.levels.INFO)
  end
  end
end

-- Standard fold implementation - compatible with other folding systems
function M_folds.fold_godoc_blocks()
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    if M.debug_mode then
      vim.notify('Not a Go file', vim.log.levels.WARN)
    end
    return
  end
  
  -- Get all godoc blocks without changing folding method
  local ranges = M_folds.get_folding_ranges(bufnr)
  local fold_count = 0
  
  -- Create folds for all godoc blocks without disturbing existing fold settings
  for _, range in ipairs(ranges) do
    local start_line = range.startRow + 1  -- Convert to 1-indexed for Vim commands
    local end_line = range.endRow + 1      -- Convert to 1-indexed for Vim commands
    
    -- Create the fold using native Vim commands but preserve existing folds
    pcall(function() vim.cmd(start_line .. ',' .. end_line .. 'fold') end)
    fold_count = fold_count + 1
  end
  
  if M.debug_mode then
    vim.notify('Folded ' .. fold_count .. ' godoc blocks', vim.log.levels.INFO)
  end
end

-- Function specifically to fold the block under cursor with enhanced debugging
function M_folds.fold_under_cursor(debug_output)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1  -- 0-indexed
  
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    if debug_output then
      vim.notify('Not a Go file', vim.log.levels.WARN)
    end
    return false
  end
  
  -- Debug information
  if debug_output then
    vim.notify("Checking cursor line " .. (cursor_line + 1), vim.log.levels.INFO)
  end
  
  -- Get the current line
  local line = vim.api.nvim_buf_get_lines(bufnr, cursor_line, cursor_line + 1, false)[1]
  
  -- Debug 
  if debug_output and line then
    vim.notify("Current line: " .. line, vim.log.levels.INFO)
  end
  
  -- Check if this is part of a godoc block
  if line and (line:match("//.*godoc") or line:match("^%s*// @%w+")) then
    -- Find the block boundaries
    local in_block = false
    local start_line = cursor_line
    local end_line = cursor_line
    
    -- First, find the start of the block by going up
    for i = cursor_line, 0, -1 do
      local prev_line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
      if prev_line:match("//.*godoc") then
        start_line = i
        in_block = true
        break
      elseif prev_line:match("^%s*// @%w+") then
        start_line = i
        in_block = true
      elseif not prev_line:match("^%s*//") then
        -- If not a comment, we've gone beyond the block
        break
      end
    end
    
    -- Then find the end of the block by going down
    if in_block then
      for i = cursor_line, vim.api.nvim_buf_line_count(bufnr) - 1 do
        local next_line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
        if next_line:match("^%s*// @%w+") or next_line:match("//.*godoc") then
          end_line = i
        elseif not next_line:match("^%s*//") then
          -- If not a comment, we've reached the end of the block
          break
        end
      end
      
      if debug_output then
        vim.notify("Found godoc block from line " .. (start_line + 1) .. " to " .. (end_line + 1), vim.log.levels.INFO)
      end
      
      -- Create the fold without changing folding method or clearing existing folds
      pcall(function()
        -- Create the fold directly without changing fold method
        vim.cmd((start_line + 1) .. ',' .. (end_line + 1) .. 'fold')
      end)
      
      if debug_output then
        -- Check if fold was created
        local fold_closed = vim.fn.foldclosed(start_line + 1)
        if fold_closed ~= -1 then
          vim.notify("Fold created successfully!", vim.log.levels.INFO)
        else
          vim.notify("Failed to create fold", vim.log.levels.ERROR)
        end
      end
      
      return true
    end
  end
  
  if debug_output then
    vim.notify("No godoc block found at cursor", vim.log.levels.WARN)
  end
  
  return false
end

function M.setup(opts)
  opts = opts or {}
  
  -- Default color scheme (Rose Pine Muted)
  local default_colors = {
    comment = '#585273',       -- Base color for comment lines in godoc blocks
    tag = '#a794c7',           -- Muted Iris (purple)
    param = '#c9a5a3',         -- Muted Rose (pink/salmon)
    success = '#87b3ba',       -- Muted Foam (teal)
    failure = '#c26580',       -- Muted Love (red)
    router = '#d1a86a',        -- Muted Gold (amber)
    description = '#7d7a93',   -- More muted text
    security = '#c78d8b',      -- Muted Pine (red/pink)
    status_code = '#87b3ba',   -- Muted Foam for status codes
    type_keyword = '#656380',  -- Very muted for type keywords
    type_object = '#2e647c',   -- Muted Pine (blue) for type objects
    description_text = '#6e6a86', -- Muted text for description comments
    
    -- New detailed component colors
    param_name = '#b3a5d3',    -- Parameter name 
    param_location = '#c9a5a3', -- Parameter location
    param_type = '#9abbc7',    -- Parameter type
    param_required = '#e09a8c', -- Parameter required flag
    
    router_path = '#c19557',   -- Router path (20% more muted than router)
    router_path_var = '#c2a37b', -- Router path variables (lighter than path)
    router_method = '#bfa36a', -- Router method
    
    security_scheme = '#dda3a1', -- Security scheme name
    
    -- LSP navigation features - Response models (Success/Failure)
    model_reference = '#6d8a82', -- Clickable model references (primary/root level) - more gray-green base
    model_reference_l1 = '#5e7870', -- Level 1 nested generic (more gray)
    model_reference_l2 = '#50655f', -- Level 2 nested generic (more gray)
    model_reference_l3 = '#41534e', -- Level 3+ nested generic (very gray)
    
    -- Request models (@Param models)
    request_model_reference = '#7a8775', -- Clickable request model references (primary) - similar but distinct color
    request_model_reference_l1 = '#697466', -- Level 1 nested generic
    request_model_reference_l2 = '#5a6458', -- Level 2 nested generic
    request_model_reference_l3 = '#4a534a' -- Level 3+ nested generic
  }
  
  -- Debug mode for troubleshooting
  M.debug_mode = opts.debug_mode or false
  -- Expose debug mode globally so other modules can check it
  vim.g.godoc_swagger_debug_mode = M.debug_mode
  
  -- Folding option (enabled by default)
  M.enable_folding = opts.enable_folding
  if M.enable_folding == nil then
    M.enable_folding = true
  end
  
  -- LSP features option (enabled by default)
  M.enable_lsp = opts.enable_lsp
  if M.enable_lsp == nil then
    M.enable_lsp = true
  end
  
  -- LSP navigation style (default: "picker")
  -- "direct" = Go directly to definition when possible
  -- "picker" = Always use Telescope/Snacks/picker UI
  -- "hover" = Use a hover-style window that closes after selection
  -- "snacks" = Specifically use Snacks picker if available
  M.lsp_navigation_style = opts.lsp_navigation_style or "snacks"
  
  -- Custom keybinding for Godoc goto definition (default: nil, which maps to <leader>gd)
  -- Set to false to disable automatic keybinding
  M.goto_definition_key = opts.goto_definition_key
  
  -- Merge user colors with defaults
  local colors = vim.tbl_deep_extend('force', default_colors, opts.colors or {})
  
  -- Define highlighting groups
  local highlight_cmds = {
    -- Base comment highlighting for all godoc blocks
    'highlight default GodocSwaggerComment ctermfg=243 guifg=' .. colors.comment,
    
    -- Basic tag highlighting
    'highlight default GodocSwaggerTag ctermfg=176 guifg=' .. colors.tag .. ' gui=italic',
    'highlight default GodocSwaggerParam ctermfg=180 guifg=' .. colors.param .. ' gui=italic',
    'highlight default GodocSwaggerSuccess ctermfg=107 guifg=' .. colors.success .. ' gui=italic',
    'highlight default GodocSwaggerFailure ctermfg=203 guifg=' .. colors.failure .. ' gui=italic',
    'highlight default GodocSwaggerRouter ctermfg=107 guifg=' .. colors.router .. ' gui=italic',
    'highlight default GodocSwaggerDescription ctermfg=249 guifg=' .. colors.description,
    'highlight default GodocSwaggerSecurity ctermfg=215 guifg=' .. colors.security .. ' gui=italic',
    'highlight default GodocSwaggerStatusCode ctermfg=109 guifg=' .. colors.status_code,
    'highlight default GodocSwaggerTypeKeyword ctermfg=152 guifg=' .. colors.type_keyword .. ' gui=italic',
    'highlight default GodocSwaggerTypeObject ctermfg=152 guifg=' .. colors.type_object,
    'highlight default GodocSwaggerDescriptionText ctermfg=249 guifg=' .. colors.description_text,
    'highlight default GodocSwaggerGodocLine ctermfg=109 guifg=' .. colors.tag .. ' gui=bold,italic',
    
    -- Detailed parameter components
    'highlight default GodocSwaggerParamName ctermfg=183 guifg=' .. colors.param_name,
    'highlight default GodocSwaggerParamLocation ctermfg=181 guifg=' .. colors.param_location,
    'highlight default GodocSwaggerParamType ctermfg=110 guifg=' .. colors.param_type,
    'highlight default GodocSwaggerParamRequired ctermfg=174 guifg=' .. colors.param_required,
    
    -- Router components
    'highlight default GodocSwaggerRouterPath ctermfg=179 guifg=' .. colors.router_path,
    'highlight default GodocSwaggerRouterPathVar ctermfg=180 guifg=' .. colors.router_path_var,
    'highlight default GodocSwaggerRouterMethod ctermfg=178 guifg=' .. colors.router_method .. ' gui=italic',
    
    -- Security components
    'highlight default GodocSwaggerSecurityScheme ctermfg=174 guifg=' .. colors.security_scheme,
    
    -- LSP navigation features with graduated colors for different nesting levels
    -- Response model references (Success/Failure)
    'highlight default GodocSwaggerModelReference ctermfg=108 guifg=' .. colors.model_reference .. ' gui=underline',
    'highlight default GodocSwaggerModelReferenceL1 ctermfg=107 guifg=' .. colors.model_reference_l1 .. ' gui=underline',
    'highlight default GodocSwaggerModelReferenceL2 ctermfg=102 guifg=' .. colors.model_reference_l2 .. ' gui=none',
    'highlight default GodocSwaggerModelReferenceL3 ctermfg=101 guifg=' .. colors.model_reference_l3 .. ' gui=none',
    
    -- Request model references (@Param)
    'highlight default GodocSwaggerRequestModelReference ctermfg=107 guifg=' .. colors.request_model_reference .. ' gui=underline',
    'highlight default GodocSwaggerRequestModelReferenceL1 ctermfg=106 guifg=' .. colors.request_model_reference_l1 .. ' gui=underline',
    'highlight default GodocSwaggerRequestModelReferenceL2 ctermfg=101 guifg=' .. colors.request_model_reference_l2 .. ' gui=none',
    'highlight default GodocSwaggerRequestModelReferenceL3 ctermfg=100 guifg=' .. colors.request_model_reference_l3 .. ' gui=none',
    
    -- Debug highlighting
    'highlight default GodocSwaggerDebugBlock ctermfg=188 guifg=#FFFFFF guibg=#333333'
  }
  
  -- Apply highlights
  for _, cmd in ipairs(highlight_cmds) do
    vim.cmd(cmd)
  end
  
  -- Create an autocommand group for the plugin
  local augroup = vim.api.nvim_create_augroup('GodocSwagger', { clear = true })
  
  -- Pattern option (default to *.go)
  local patterns = opts.patterns or {'*.go'}
  
  -- Throttled update function to avoid excessive highlighting on each keystroke
  local update_timer = nil
  local function apply_highlighting_throttled()
    if update_timer then
      vim.fn.timer_stop(update_timer)
    end
    
    update_timer = vim.fn.timer_start(300, function()
      -- Only apply if buffer is still valid
      if vim.api.nvim_buf_is_valid(0) then
        M.apply_highlighting()
      end
      update_timer = nil
    end)
  end
  
  -- Add autocommand to apply highlighting for Go files
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'BufRead' }, {
    group = augroup,
    pattern = patterns,
    callback = function()
      -- Apply immediately for the current buffer
      M.apply_highlighting()
      
      -- Register folds if folding is enabled but don't fold them
      if M.enable_folding then
        -- Defer the fold registration to make sure we don't interfere with other fold settings
        vim.defer_fn(function()
          -- Only register if we haven't already
          if not vim.b.godoc_folds_registered then
            M_folds.register_godoc_folds()
          end
        end, 100) -- Short delay to let other fold settings take effect first
      end
      
      -- Set up TextChanged events for this buffer to update highlighting as user types
      vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
        buffer = 0,
        callback = apply_highlighting_throttled,
      })
      
      -- If LSP features are enabled, highlight model references
      if M.enable_lsp then
        -- Load the LSP module
        local lsp = require('godoc-swagger.lsp')
        
        -- Highlight model references in comments
        lsp.highlight_model_references(0)
        
        -- Update model references when text changes
        vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
          buffer = 0,
          callback = function()
            if update_timer then
              vim.fn.timer_stop(update_timer)
            end
            
            update_timer = vim.fn.timer_start(300, function()
              -- Only apply if buffer is still valid
              if vim.api.nvim_buf_is_valid(0) then
                lsp.highlight_model_references(0)
              end
              update_timer = nil
            end)
          end,
        })
      end
    end,
  })
  
  -- Create a command to manually apply highlighting
  vim.api.nvim_create_user_command('GodocHighlight', M.apply_highlighting, {})
  
  -- Ensure highlighting persists after colorscheme changes
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = augroup,
    callback = M.apply_highlighting,
  })
  
  -- Set up folding if enabled
  if M.enable_folding then
    -- Export folding module for UFO provider compatibility
    M.folds = M_folds
    
    -- Create commands for folding functionality (works with any folding system)
    -- Use pcall to avoid errors if commands already exist
    pcall(function()
      -- Legacy fold-based methods (may interfere with UFO)
      vim.api.nvim_create_user_command('GodocFold', function()
        M_folds.fold_godoc_blocks()
      end, {})
      
      vim.api.nvim_create_user_command('GodocFoldDebug', function()
        M_folds.fold_under_cursor(true)
      end, {})
      
      -- New command to register folds without folding them
      vim.api.nvim_create_user_command('GodocRegisterFolds', function()
        M_folds.register_godoc_folds()
      end, {})
      
      -- Command to unfold all godoc blocks
      vim.api.nvim_create_user_command('GodocUnfold', function()
        M_folds.unfold_godoc_blocks()
      end, {})
      
      -- UFO-compatible methods (won't interfere with folding)
      vim.api.nvim_create_user_command('GodocToggle', function()
        M_folds.toggle_godoc_blocks()
      end, {})
      
      vim.api.nvim_create_user_command('GodocToggleConceal', function()
        M_folds.toggle_conceal_godoc_blocks()
      end, {})
    end)
  end
  
  -- Set up LSP features if enabled
  if M.enable_lsp then
    -- Create commands for LSP functionality
    pcall(function()
      -- Load the LSP module
      local lsp = require('godoc-swagger.lsp')
      
      -- Command to jump to definition under cursor
      vim.api.nvim_create_user_command('GodocGotoDefinition', function()
        lsp.goto_definition_under_cursor()
      end, {})
      
      -- Command to highlight model references
      vim.api.nvim_create_user_command('GodocHighlightModels', function()
        lsp.highlight_model_references()
      end, {})
      
      -- Add keybinding for Go To Definition
      vim.api.nvim_create_autocmd('FileType', {
        group = augroup,
        pattern = 'go',
        callback = function()
          -- Set up keybindings based on user configuration
          local key = M.goto_definition_key
          
          -- If user explicitly set goto_definition_key to false, don't map any keys
          if key ~= false then
            -- If user provided a custom key, use it, otherwise default to <leader>gd
            if key then
              vim.keymap.set('n', key, function()
                lsp.goto_definition_under_cursor()
              end, { buffer = true, desc = "Godoc: Go to model definition" })
            else
              -- Default mapping
              vim.keymap.set('n', '<leader>gd', function()
                lsp.goto_definition_under_cursor()
              end, { buffer = true, desc = "Godoc: Go to model definition" })
            end
          end
        end
      })
    end)
  end
  
  -- Check if UFO is available - if so, provide instructions for integration
  local has_ufo = pcall(require, 'ufo')
  if has_ufo then
    -- Add a notification only when debug mode is active
    if M.debug_mode then
      vim.notify([[
UFO detected! To integrate godoc-swagger with nvim-ufo, add this to your UFO setup:

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
]], vim.log.levels.INFO)
    end
  else
    -- For non-UFO users, set up a basic folding approach using vim commands
    vim.api.nvim_create_autocmd('FileType', {
      group = augroup,
      pattern = patterns,
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        
        -- Add keybindings for godoc folding
        -- zgd - Toggle godoc blocks without affecting folding (recommended with UFO)
        vim.keymap.set('n', 'zgd', function()
          M_folds.toggle_godoc_blocks()
        end, { buffer = true, desc = "Toggle godoc blocks (UFO compatible)" })
        
        -- zC - Toggle conceal for godoc blocks (alternative method)
        vim.keymap.set('n', 'zC', function()
          M_folds.toggle_conceal_godoc_blocks()
        end, { buffer = true, desc = "Toggle conceal for godoc blocks" })
        
        -- zG - Fold method (now compatible with other folding systems)
        vim.keymap.set('n', 'zG', function()
          M_folds.fold_godoc_blocks()
        end, { buffer = true, desc = "Fold All Godoc Blocks" })
        
        -- zgR - Force re-register all godoc folds (helpful if folding gets disrupted)
        vim.keymap.set('n', 'zgR', function()
          vim.b.godoc_folds_registered = false  -- Reset the registration flag
          M_folds.register_godoc_folds()
        end, { buffer = true, desc = "Re-register godoc folds (without folding)" })
        
        -- zgO - Unfold all godoc blocks in the file
        vim.keymap.set('n', 'zgO', function()
          M_folds.unfold_godoc_blocks()
        end, { buffer = true, desc = "Unfold all godoc blocks" })
        
        -- Add diagnostic keybinding that bypasses za completely
        vim.keymap.set('n', '<Leader>z', function()
          -- Force debug output to see what's happening
          M_folds.fold_under_cursor(true)
        end, { buffer = true, desc = "Fold godoc block with debug info" })
        
        -- Override za behavior for godoc blocks
        vim.keymap.set('n', 'za', function()
          -- If we're on a godoc line or annotation, handle it specially
          -- Otherwise, fall back to default za behavior
          if not M_folds.fold_under_cursor(false) then
            -- Execute the original za command
            vim.cmd("normal! za")
          end
        end, { buffer = true, desc = "Toggle fold (godoc-aware)" })
        
        -- Add additional keybindings for debugging when in debug mode
        if M.debug_mode then
          vim.keymap.set('n', '<Leader>zz', function()
            M_folds.fold_under_cursor(true)
          end, { buffer = true, desc = "Debug fold godoc block under cursor" })
        end
        
        -- Ditto for zo and zc
        vim.keymap.set('n', 'zo', function()
          if not M_folds.fold_under_cursor(false) then
            vim.cmd("normal! zo")
          else
            -- If we just created a fold, open it
            vim.cmd("normal! zo")
          end
        end, { buffer = true, desc = "Open fold (godoc-aware)" })
        
        vim.keymap.set('n', 'zc', function()
          if not M_folds.fold_under_cursor(false) then
            vim.cmd("normal! zc")
          end
        end, { buffer = true, desc = "Close fold (godoc-aware)" })
      end,
    })
  end
  
  -- Don't return anything from setup()
end

return M