local w = require('wezterm')

local direction_keys = {
  h = 'Left',
  j = 'Down',
  k = 'Up',
  l = 'Right',
}

-- WezTerm names the domain backing panes it spawns and supervises directly
-- 'local'; ../modules/commands.lua relies on the same name. Any other domain
-- name -- the ssh_domains built in ../wezterm.lua, a unix/mux domain, WSL --
-- means the pane's program runs behind a domain boundary, where the local
-- process table cannot name the program a keystroke would reach. A domain
-- name we cannot read is treated as non-local too: declining to trust an
-- unverifiable process name only costs multiplexer routing in that one
-- pane, whereas trusting one wrongly costs native pane navigation.
local LOCAL_DOMAIN = 'local'

-- Programs that implement their own split navigation on these chords, and so
-- must receive the keystroke instead of WezTerm acting on it. tmux belongs
-- here because its own C-h/j/k/l and M-h/j/k/l bindings (see ../../../
-- dot_tmux.conf) are what choose between tmux panes and a Neovim running
-- inside them. While it was missing, WezTerm consumed the chord itself and
-- tmux never saw it.
local NAVIGATES_ITSELF = {
  nvim = true,
  vim = true,
  tmux = true,
}

-- POSIX basename(3). Given '/foo/bar' returns 'bar', given 'c:\\foo\\bar'
-- returns 'bar'. pane:get_foreground_process_name() returns nil whenever
-- WezTerm cannot read the pane's process table, so anything that is not a
-- string has to fall through to '' rather than reach string.gsub.
local function basename(path)
  if type(path) ~= 'string' then return '' end
  return (path:gsub('(.*[/\\])(.*)', '%2'))
end

-- Should this chord go to the program running in the pane rather than to
-- WezTerm? One policy, in precedence order:
--   1. IS_NVIM, set and cleared by smart-splits.nvim, is honoured wherever
--      it is present -- including panes with no readable process name.
--   2. The foreground process name, consulted only on the local domain,
--      where it genuinely names the program that would receive the key.
--      This is what routes a local tmux; from there it is tmux's own
--      @pane-is-vim bindings that find a Neovim running inside it.
-- Anything else keeps the chord for WezTerm's own panes.
local function pane_handles_navigation(pane)
  local user_vars = pane:get_user_vars() or {}
  if user_vars.IS_NVIM == 'true' then return true end
  if pane:get_domain_name() ~= LOCAL_DOMAIN then return false end
  return NAVIGATES_ITSELF[basename(pane:get_foreground_process_name())] == true
end

local function split_nav(resize_or_move, key)
  return {
    key = key,
    mods = resize_or_move == 'resize' and 'META' or 'CTRL',
    action = w.action_callback(function(win, pane)
      if pane_handles_navigation(pane) then
        -- pass the keys through to the program running in the pane
        win:perform_action({
          SendKey = {
            key = key,
            mods = resize_or_move == 'resize' and 'META' or 'CTRL',
          },
        }, pane)
      else
        if resize_or_move == 'resize' then
          win:perform_action(
            { AdjustPaneSize = { direction_keys[key], 3 } },
            pane
          )
        else
          win:perform_action(
            { ActivatePaneDirection = direction_keys[key] },
            pane
          )
        end
      end
    end),
  }
end

return {
  keys = {
    -- move between split panes
    split_nav('move', 'h'),
    split_nav('move', 'j'),
    split_nav('move', 'k'),
    split_nav('move', 'l'),
    -- resize panes
    split_nav('resize', 'h'),
    split_nav('resize', 'j'),
    split_nav('resize', 'k'),
    split_nav('resize', 'l'),
  },
}
