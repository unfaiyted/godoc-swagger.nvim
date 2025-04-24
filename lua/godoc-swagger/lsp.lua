-- LSP and navigation functionality for godoc-swagger
local M = {}

-- Function to determine nesting level in a complex generic type
local function determine_nesting_level(line, pos_start)
  -- Count the number of opening square brackets before this position
  -- that don't have a matching closing bracket yet
  local line_before = line:sub(1, pos_start)
  local open_count = 0
  local close_count = 0
  
  for c in line_before:gmatch(".") do
    if c == "[" then
      open_count = open_count + 1
    elseif c == "]" then
      close_count = close_count + 1
    end
  end
  
  -- The nesting level is the difference between open and close brackets
  local level = math.max(0, open_count - close_count)
  
  -- Add detailed debug logging if in debug mode
  if vim.g.godoc_swagger_debug_mode and level > 0 then
    -- Get the model reference text to show in debug info
    local model_text = line:sub(1, pos_start + 30):gsub("[\r\n]", " ") -- Get a snippet for debug
    if #model_text > 30 then model_text = model_text:sub(1, 30) .. "..." end
    
    -- Debug log with detailed nesting information
    vim.defer_fn(function()
      vim.notify(string.format(
        "Nesting level %d detected (open: %d, close: %d) at: %s", 
        level, open_count, close_count, model_text
      ), vim.log.levels.DEBUG)
    end, 10) -- Defer to avoid cluttering output
  end
  
  return level
end

-- Parse models from godoc blocks in a buffer
function M.parse_model_references(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local references = {}
  local current_block = nil
  
  for i, line in ipairs(lines) do
    local is_comment = line:match("^%s*//")
    
    if is_comment then
      -- Start a new godoc block
      if line:match("//.*godoc") and not current_block then
        current_block = {
          start_line = i,
          end_line = i,
          models = {}
        }
      -- Check for Success/Failure with model references
      elseif current_block and line:match("^%s*// @Success") then
        -- Parse Success line: @Success 200 {object} models.User or complex generics
        
        -- First try to match the basic pattern
        local status, obj_type = line:match("@Success%s+(%d+)%s+{([^}]+)}")

        if status and obj_type then
          -- Now we need to handle complex generics like responses.APIResponse[models.MediaItem[mediatypes.Movie]]
          -- Extract the entire model part (after the {object} or {array} part)
          local model_part = line:match("{[^}]+}%s+(.+)")
          
          if model_part then
            -- Find the end of the description (everything after " is description)
            local model_only = model_part:match("^(.-)%s+\"") or model_part
            
            -- Now find all model references in format package.Type
            for package_name, type_name in model_only:gmatch("([%w_]+)%.([%w_]+)") do
              local full_model = package_name .. "." .. type_name
              local pos_start = line:find(full_model, 1, true)
              
              if pos_start then
                -- Determine nesting level for color differentiation
                local nesting_level = determine_nesting_level(line, pos_start)
                
                table.insert(current_block.models, {
                  line = i,
                  type = "success",
                  status = status,
                  obj_type = obj_type,
                  model = full_model,
                  -- Store the position information of the model name
                  pos_start = pos_start,
                  pos_end = pos_start + #full_model - 1,
                  -- Store nesting level for highlighting
                  nesting_level = nesting_level
                })
              end
            end
          end
        end
      elseif current_block and line:match("^%s*// @Failure") then
        -- Parse Failure line: @Failure 404 {object} models.ErrorResponse
        local status, obj_type = line:match("@Failure%s+(%d+)%s+{([^}]+)}")
        
        if status and obj_type then
          -- Extract the entire model part (after the {object} or {array} part)
          local model_part = line:match("{[^}]+}%s+(.+)")
          
          if model_part then
            -- Find the end of the description (everything after " is description)
            local model_only = model_part:match("^(.-)%s+\"") or model_part
            
            -- Now find all model references in format package.Type
            for package_name, type_name in model_only:gmatch("([%w_]+)%.([%w_]+)") do
              local full_model = package_name .. "." .. type_name
              local pos_start = line:find(full_model, 1, true)
              
              if pos_start then
                -- Determine nesting level for color differentiation
                local nesting_level = determine_nesting_level(line, pos_start)
                
                table.insert(current_block.models, {
                  line = i,
                  type = "failure",
                  status = status,
                  obj_type = obj_type,
                  model = full_model,
                  -- Store the position information of the model name
                  pos_start = pos_start,
                  pos_end = pos_start + #full_model - 1,
                  -- Store nesting level for highlighting
                  nesting_level = nesting_level
                })
              end
            end
          end
        end
      elseif current_block and line:match("^%s*// @Param") then
        -- Parse Param line: @Param request body requests.ClientTestRequest[client.ClientConfig] true "Updated client data"
        -- The model can be in any of the data type positions, and is typically in the form of package.Type

        -- Extract the entire Param line after @Param
        local param_line = line:match("@Param%s+(.+)")
        
        if param_line then
          -- Find the end of the description (everything after " is description)
          local param_only = param_line:match("^(.-)%s+\"") or param_line
          
          -- Now find all model references in format package.Type
          for package_name, type_name in param_only:gmatch("([%w_]+)%.([%w_]+)") do
            local full_model = package_name .. "." .. type_name
            local pos_start = line:find(full_model, 1, true)
            
            if pos_start then
              -- Determine nesting level for color differentiation
              local nesting_level = determine_nesting_level(line, pos_start)
              
              -- Try to extract param information
              local param_name = param_line:match("^(%S+)")
              local param_location = param_line:match("^%S+%s+(%S+)")
              
              table.insert(current_block.models, {
                line = i,
                type = "param", -- Mark it as a param type for different highlighting
                param_name = param_name or "",
                param_location = param_location or "",
                model = full_model,
                -- Store the position information of the model name
                pos_start = pos_start,
                pos_end = pos_start + #full_model - 1,
                -- Store nesting level for highlighting
                nesting_level = nesting_level
              })
            end
          end
        end
      elseif current_block and not line:match("^%s*//") then
        -- End of comment block
        if #current_block.models > 0 then
          table.insert(references, current_block)
        end
        current_block = nil
      elseif current_block then
        -- Continue current block
        current_block.end_line = i
      end
    elseif current_block then
      -- End of comment block
      if #current_block.models > 0 then
        table.insert(references, current_block)
      end
      current_block = nil
    end
  end
  
  -- Add the last block if we had one
  if current_block and #current_block.models > 0 then
    table.insert(references, current_block)
  end
  
  return references
end

-- Get the model reference at the given position
function M.get_model_at_position(bufnr, row, col)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local references = M.parse_model_references(bufnr)
  local closest_model = nil
  local min_distance = math.huge
  
  for _, block in ipairs(references) do
    if row >= block.start_line and row <= block.end_line then
      for _, model_ref in ipairs(block.models) do
        if model_ref.line == row + 1 then
          -- Check if cursor is within or close to model reference
          if col >= model_ref.pos_start and col <= model_ref.pos_end then
            -- If the cursor is directly over a reference, return it immediately
            return model_ref
          else
            -- Calculate distance to this model reference
            local distance = nil
            if col < model_ref.pos_start then
              distance = model_ref.pos_start - col
            else
              distance = col - model_ref.pos_end
            end
            
            -- Keep track of the closest model reference
            if distance < min_distance then
              min_distance = distance
              closest_model = model_ref
            end
          end
        end
      end
    end
  end
  
  -- If we found a close model reference within 10 characters, return it
  if closest_model and min_distance <= 10 then
    return closest_model
  end
  
  return nil
end

-- Find the definition of a model in the current buffer or workspace
function M.find_model_definition(bufnr, model_ref)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not model_ref or not model_ref.model then
    if vim.g.godoc_swagger_debug_mode then
      vim.notify("No model reference found", vim.log.levels.WARN)
    end
    return false
  end
  
  -- Extract the type name (handling packages)
  local original_type = model_ref.model
  -- First, strip any generic parts if present (e.g., models.MediaItem[mediatypes.Movie] -> models.MediaItem)
  local type_name = original_type:gsub("%[.*%]", "")
  
  -- Debug
  if vim.g.godoc_swagger_debug_mode then
    vim.notify("Processing type: " .. original_type .. " -> " .. type_name, vim.log.levels.INFO)
  end
  
  local package_name, base_type = type_name:match("^(.+)%.(.+)$")
  
  -- If there's no package prefix, just search for the type
  local search_pattern = base_type or type_name
  
  -- Try to determine the position in the file where this type might be defined
  -- 1. First try by checking type definition patterns in the current buffer
  local patterns = {
    "type%s+" .. search_pattern .. "%s+struct",
    "type%s+" .. search_pattern .. "%s+interface",
    "type%s+" .. search_pattern .. "%s+"
  }
  
  -- Check current buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local found = false
  local target_line = 0
  
  for i, line in ipairs(lines) do
    for _, pattern in ipairs(patterns) do
      if line:match(pattern) then
        found = true
        target_line = i
        break
      end
    end
    if found then break end
  end
  
  if found then
    -- Navigate to the definition
    vim.api.nvim_win_set_cursor(0, {target_line, 0})
    if vim.g.godoc_swagger_debug_mode then
      vim.notify("Found definition: " .. model_ref.model, vim.log.levels.INFO)
    end
    return true
  end
  
  -- 2. Get the navigation style configuration
  local navigation_style = require('godoc-swagger').lsp_navigation_style or "snacks"
  
  if vim.g.godoc_swagger_debug_mode then
    vim.notify("Using navigation style: " .. navigation_style, vim.log.levels.INFO)
  end
  
  -- Check if user specifically wants Snacks
  if navigation_style == "snacks" then
    -- Try Snacks first
    if vim.fn.exists(":Snacks") == 2 then
      if vim.g.godoc_swagger_debug_mode then
        vim.notify("Using Snacks picker for: " .. search_pattern, vim.log.levels.INFO)
      end
      
      local query = package_name and (package_name .. "." .. base_type) or search_pattern
      
      -- Try to use snacks picker that automatically closes
      vim.cmd("Snacks lsp-workspace-symbols " .. query)
      return true
    else
      -- Fall back to Telescope if Snacks isn't available
      navigation_style = "picker"
    end
  end
  
  -- Always use picker if that's the configured style or falling back from Snacks
  if navigation_style == "picker" then
    -- Check for telescope first
    if vim.fn.exists(":Telescope") == 2 then
      if vim.g.godoc_swagger_debug_mode then
        vim.notify("Using Telescope picker for: " .. search_pattern, vim.log.levels.INFO)
      end
      
      -- Use Telescope with proper options for auto-closing
      -- We need to use the Lua API directly to configure proper behavior
      local opts = {
        prompt_title = "Go To Definition: " .. search_pattern,
        initial_mode = "normal",
        theme = "dropdown",
        layout_config = {
          width = 0.6,
          height = 0.4,
        }
      }
      
      -- Try to use the direct Lua API first (preferred method)
      local telescope_loaded, telescope = pcall(require, 'telescope.builtin')
      if telescope_loaded then
        if package_name and base_type then
          telescope.lsp_workspace_symbols({
            query = package_name .. "." .. base_type,
            prompt_title = "Go To Definition: " .. package_name .. "." .. base_type,
            initial_mode = "normal",
            theme = "dropdown",
            attach_mappings = function(prompt_bufnr, map)
              -- Make Enter select and close the picker safely
              local actions = require('telescope.actions')
              map('i', '<CR>', function()
                actions.select_default(prompt_bufnr)
                -- Try safely closing with pcall to avoid errors
                pcall(function()
                  actions.close(prompt_bufnr)
                end)
                return true
              end)
              map('n', '<CR>', function()
                actions.select_default(prompt_bufnr)
                -- Try safely closing with pcall to avoid errors
                pcall(function()
                  actions.close(prompt_bufnr)
                end)
                return true
              end)
              return true
            end,
            layout_config = {
              width = 0.6,
              height = 0.4,
            }
          })
        else
          telescope.lsp_workspace_symbols({
            query = search_pattern,
            prompt_title = "Go To Definition: " .. search_pattern,
            initial_mode = "normal",
            theme = "dropdown",
            attach_mappings = function(prompt_bufnr, map)
              -- Make Enter select and close the picker safely
              local actions = require('telescope.actions')
              map('i', '<CR>', function()
                actions.select_default(prompt_bufnr)
                -- Try safely closing with pcall to avoid errors
                pcall(function()
                  actions.close(prompt_bufnr)
                end)
                return true
              end)
              map('n', '<CR>', function()
                actions.select_default(prompt_bufnr)
                -- Try safely closing with pcall to avoid errors
                pcall(function()
                  actions.close(prompt_bufnr)
                end)
                return true
              end)
              return true
            end,
            layout_config = {
              width = 0.6,
              height = 0.4,
            }
          })
        end
      else
        -- Fall back to command if Lua API isn't available
        if package_name and base_type then
          vim.cmd("Telescope lsp_workspace_symbols query=" .. package_name .. "." .. base_type)
        else
          vim.cmd("Telescope lsp_workspace_symbols query=" .. search_pattern)
        end
      end
      return true
    end
    
    -- Try Snap if available (alternative to Telescope)
    if vim.fn.exists(":Snap") == 2 then
      if package_name and base_type then
        vim.cmd("Snap lsp-workspace-symbols " .. package_name .. "." .. base_type)
      else
        vim.cmd("Snap lsp-workspace-symbols " .. search_pattern)
      end
      return true
    end
  end
  
  -- For hover style, use a custom window that we can close automatically
  if navigation_style == "hover" then
    if vim.g.godoc_swagger_debug_mode then
      vim.notify("Using hover-style for: " .. search_pattern, vim.log.levels.INFO)
    end
    
    -- Trigger a floating window LSP call directly (nvim-lsp-handler can use this)
    local query = package_name and (package_name .. "." .. base_type) or search_pattern
    vim.lsp.buf.workspace_symbol(query)
    return true
  end
  
  -- Direct style (default) or fallbacks if pickers aren't available
  if vim.g.godoc_swagger_debug_mode then
    vim.notify("Using direct workspace symbol search for: " .. search_pattern, vim.log.levels.INFO)
  end
  
  -- Using workspace/symbol request - more precise than grep
  if vim.lsp.buf.workspace_symbol and package_name and base_type then
    -- Use more specific symbol search when we have both package and type
    local full_pattern = package_name .. "." .. base_type
    vim.lsp.buf.workspace_symbol(full_pattern)
    return true
  elseif vim.lsp.buf.workspace_symbol then
    -- Fallback to just searching for the type name
    vim.lsp.buf.workspace_symbol(search_pattern)
    return true
  end
  
  -- Fallback to Telescope if direct methods aren't available
  if vim.fn.exists(":Telescope") == 2 then
    if vim.g.godoc_swagger_debug_mode then
      vim.notify("Falling back to Telescope for: " .. search_pattern, vim.log.levels.INFO)
    end
    
    -- Try the Lua API first for better customization
    local telescope_loaded, telescope = pcall(require, 'telescope.builtin')
    if telescope_loaded then
      local query = package_name and (package_name .. "." .. base_type) or search_pattern
      telescope.lsp_workspace_symbols({
        query = query,
        prompt_title = "Go To Definition: " .. query,
        initial_mode = "normal",
        theme = "dropdown",
        attach_mappings = function(prompt_bufnr, map)
          -- Make Enter select and close the picker safely
          local actions = require('telescope.actions')
          map('i', '<CR>', function()
            actions.select_default(prompt_bufnr)
            -- Try safely closing with pcall to avoid errors
            pcall(function()
              actions.close(prompt_bufnr)
            end)
            return true
          end)
          map('n', '<CR>', function()
            actions.select_default(prompt_bufnr)
            -- Try safely closing with pcall to avoid errors
            pcall(function()
              actions.close(prompt_bufnr)
            end)
            return true
          end)
          return true
        end,
        layout_config = {
          width = 0.6,
          height = 0.4, 
        }
      })
    else
      -- Fall back to command if Lua API isn't available
      if package_name and base_type then
        vim.cmd("Telescope lsp_workspace_symbols query=" .. package_name .. "." .. base_type)
      else
        vim.cmd("Telescope lsp_workspace_symbols query=" .. search_pattern)
      end
    end
    return true
  end
  
  -- 4. Last resort, use grep
  if vim.g.godoc_swagger_debug_mode then
    vim.notify("Using grep to find: " .. search_pattern, vim.log.levels.INFO)
  end
  
  -- Last resort: grep search
  if package_name and base_type then
    -- Try to find the type definition with package name for context
    vim.cmd("grep 'type\\s\\+" .. base_type .. "\\s\\+' " .. package_name)
  else
    vim.cmd("grep 'type\\s\\+" .. search_pattern .. "\\s\\+'")
  end
  
  return true
end

-- Jump to model definition under cursor
function M.goto_definition_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    if vim.g.godoc_swagger_debug_mode then
      vim.notify('Not a Go file', vim.log.levels.WARN)
    end
    return
  end
  
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1] - 1  -- Convert to 0-indexed
  local col = cursor_pos[2]
  
  -- Add a variable to enable debugging
  local debug = vim.g.godoc_swagger_debug_mode or false
  
  if debug then
    vim.notify("GodocGotoDefinition triggered at position row=" .. row .. ", col=" .. col, vim.log.levels.INFO)
  end
  
  -- Check if cursor is in godoc comments with model references
  local model_ref = M.get_model_at_position(bufnr, row, col)
  
  if model_ref then
    if debug then
      vim.notify("Found model reference: " .. model_ref.model, vim.log.levels.INFO)
    end
    
    -- Try our custom LSP integration
    local success = M.find_model_definition(bufnr, model_ref)
    
    if not success and debug then
      vim.notify("All model definition methods failed for " .. model_ref.model, vim.log.levels.WARN)
    end
  else
    if debug then
      -- Get the line content to help with debugging
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
      
      -- Check if this might be a go comment line but our parser didn't catch it
      if line:match("^%s*//") then
        vim.notify("In a comment line but no model reference detected. Checking for common type patterns...", vim.log.levels.INFO)
        
        -- Look for common type patterns (package.Type) in the line
        for package_name, type_name in line:gmatch("([%w_]+)%.([%w_]+)") do
          local full_model = package_name .. "." .. type_name
          vim.notify("Found potential type reference: " .. full_model, vim.log.levels.INFO)
          
          -- Create a synthetic model reference
          local synthetic_ref = {
            model = full_model,
            type = "synthetic"
          }
          
          -- Try to find its definition
          M.find_model_definition(bufnr, synthetic_ref)
          return
        end
      end
      
      vim.notify("No model reference found at cursor. Try using normal 'gd' command. Line content: " .. line, vim.log.levels.WARN)
    end
    -- No notification in non-debug mode - just fall back to standard LSP
    
    -- Fall back to regular go to definition as a last resort
    if vim.lsp.buf.definition then
      vim.lsp.buf.definition()
    end
  end
end

-- Create visual indicators for navigable model references
function M.highlight_model_references(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Only process Go files
  if vim.bo[bufnr].filetype ~= 'go' then
    return 0
  end
  
  -- Create a namespace if it doesn't exist
  if not vim._godoc_models_ns then
    vim._godoc_models_ns = vim.api.nvim_create_namespace('godoc_swagger_models')
  end
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, vim._godoc_models_ns, 0, -1)
  
  -- Get all model references
  local references = M.parse_model_references(bufnr)
  local ref_count = 0
  
  -- Apply extmarks to make them visually navigable
  for _, block in ipairs(references) do
    -- Sort model references by position to ensure we highlight from left to right
    -- This helps with visual clarity in complex generic types
    table.sort(block.models, function(a, b) 
      if a.line == b.line then
        return a.pos_start < b.pos_start
      end
      return a.line < b.line
    end)
    
    for _, model_ref in ipairs(block.models) do
      local line = model_ref.line - 1  -- Convert to 0-indexed
      local start_col = model_ref.pos_start - 1  -- Convert to 0-indexed
      local end_col = model_ref.pos_end
      
      -- Determine if this is a request model (from @Param) or response model (from @Success/@Failure)
      local is_request_model = model_ref.type == "param"
      
      -- Base highlight group prefix
      local hl_prefix = is_request_model and "GodocSwaggerRequestModelReference" or "GodocSwaggerModelReference"
      
      -- Determine highlight group based on nesting level
      local hl_group = hl_prefix
      if model_ref.nesting_level == 1 then
        hl_group = hl_prefix .. "L1"
      elseif model_ref.nesting_level == 2 then
        hl_group = hl_prefix .. "L2"
      elseif model_ref.nesting_level >= 3 then
        hl_group = hl_prefix .. "L3"
      end
      
      -- Add highlighting for the model reference with a higher priority to override other highlights
      vim.api.nvim_buf_set_extmark(bufnr, vim._godoc_models_ns, line, start_col, {
        end_col = end_col,
        hl_group = hl_group,
        priority = 200  -- Increased priority
      })
      
      ref_count = ref_count + 1
    end
  end
  
  if ref_count > 0 and vim.g.godoc_swagger_debug_mode then
    -- Count references by nesting level and type for more detailed debug info
    local response_count_by_level = {0, 0, 0, 0} -- level 0, 1, 2, 3+ for response models
    local request_count_by_level = {0, 0, 0, 0}  -- level 0, 1, 2, 3+ for request models
    
    for _, block in ipairs(references) do
      for _, model_ref in ipairs(block.models) do
        local level = math.min(3, model_ref.nesting_level or 0)
        if model_ref.type == "param" then
          request_count_by_level[level + 1] = request_count_by_level[level + 1] + 1
        else
          response_count_by_level[level + 1] = response_count_by_level[level + 1] + 1
        end
      end
    end
    
    local response_total = response_count_by_level[1] + response_count_by_level[2] + 
                          response_count_by_level[3] + response_count_by_level[4]
    local request_total = request_count_by_level[1] + request_count_by_level[2] + 
                         request_count_by_level[3] + request_count_by_level[4]
    
    vim.notify(string.format(
      "Highlighted %d model references (%d response, %d request) with graduated colors based on nesting level\n" ..
      "Response models (L0: %d, L1: %d, L2: %d, L3+: %d)\n" ..
      "Request models (L0: %d, L1: %d, L2: %d, L3+: %d)",
      ref_count, response_total, request_total,
      response_count_by_level[1], response_count_by_level[2], response_count_by_level[3], response_count_by_level[4],
      request_count_by_level[1], request_count_by_level[2], request_count_by_level[3], request_count_by_level[4]
    ), vim.log.levels.INFO)
  end
  
  return ref_count
end

return M