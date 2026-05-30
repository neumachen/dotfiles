-- Read a highlight group's bg colour at runtime, resolving links, returning hex or nil.
local function hl_bg(group)
  -- follow links up to 10 levels deep
  for _ = 1, 10 do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
    if not ok then return nil end
    if hl.bg then return string.format('#%06x', hl.bg) end
    if hl.link then
      group = hl.link
    else
      return nil
    end
  end
  return nil
end

-- Build a CursorLine bg that is a blend of two hex colours at `alpha` (0–1).
local function blend(fg_hex, bg_hex, alpha)
  local function parse(hex)
    hex = hex:gsub('#', '')
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
  end
  local fr, fg, fb = parse(fg_hex)
  local br, bg, bb = parse(bg_hex)
  local r = math.floor(fr * alpha + br * (1 - alpha))
  local g = math.floor(fg * alpha + bg * (1 - alpha))
  local b = math.floor(fb * alpha + bb * (1 - alpha))
  return string.format('#%02x%02x%02x', r, g, b)
end

local function build_preset()
  -- Base colours read from whatever theme is active at startup.
  local base_bg    = hl_bg('Normal')  or '#1a1b26'
  local visual_bg  = hl_bg('Visual')  or blend('#7aa2f7', base_bg, 0.60)
  local normal_bg  = blend('#3B4261', base_bg, 0.60)     -- #3B4261 more faded toward bg
  local insert_bg  = blend('#9ece6a', base_bg, 0.55)     -- green tint (String colour family)
  local replace_bg = blend('#e0af68', base_bg, 0.55)     -- amber tint (Constant colour family)

  return {
    name = 'theme-cursorline',
    modes = {
      -- Normal: use the theme's own CursorLine bg, nothing exotic
      n = {
        winhl = {
          CursorLine = { bg = normal_bg },
        },
      },
      -- Insert: subtle green tint
      i = {
        winhl = {
          CursorLine = { bg = insert_bg },
        },
      },
      -- Visual, Visual-line, Visual-block: theme Visual bg
      [{ 'v', 'V', '\x16' }] = {
        winhl = {
          CursorLine = { bg = visual_bg },
        },
      },
      -- Replace / Virtual-replace: amber tint
      [{ 'R', 'Rv' }] = {
        winhl = {
          CursorLine = { bg = replace_bg },
        },
      },
    },
  }
end

return {
  'rasulomaroff/reactive.nvim',
  event = 'VeryLazy',
  config = function()
    -- Enable cursorline so reactive's winhl actually shows up
    vim.opt.cursorline = true

    require('reactive').setup({
      builtin = {
        cursor   = true,
        modemsg  = true,
        -- builtin cursorline intentionally disabled; custom preset below owns it
        cursorline = false,
      },
    })

    -- Register our theme-aware preset after the colorscheme has loaded
    -- (VeryLazy fires after most plugins, so the theme is already active)
    require('reactive').add_preset(build_preset())
    require('reactive').setup({ configs = { ['theme-cursorline'] = true } })
  end,
}
