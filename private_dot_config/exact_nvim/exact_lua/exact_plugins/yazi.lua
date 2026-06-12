return {
  'mikavilpas/yazi.nvim',
  version = '*', -- use the latest stable version
  event = 'VeryLazy',
  dependencies = {
    { 'nvim-lua/plenary.nvim', lazy = true },
  },
  opts = {
    log_level = vim.log.levels.INFO,
    -- if you want to open yazi instead of netrw, see below for more info
    open_for_directories = true,
    integrations = {
      grep_in_directory = 'fzf-lua',
      grep_in_selected_files = 'fzf-lua',
    },
    -- mirror yazi.nvim's upstream defaults verbatim, so the full
    -- in-yazi keymap surface is discoverable here without reading
    -- the plugin source. values match
    -- https://github.com/mikavilpas/yazi.nvim/blob/main/lua/yazi/config.lua
    -- update this block if upstream changes a binding.
    keymaps = {
      show_help = '<f1>',
      open_file_in_vertical_split = '<c-v>',
      open_file_in_horizontal_split = '<c-x>',
      open_file_in_tab = '<c-t>',
      grep_in_directory = '<c-s>',
      replace_in_directory = '<c-g>',
      cycle_open_buffers = '<tab>',
      copy_relative_path_to_selected_files = '<c-y>',
      send_to_quickfix_list = '<c-q>',
      change_working_directory = '<c-\\>',
      open_and_pick_window = '<c-o>',
    },
    -- extra bindings layered on top of the upstream keymaps:
    --   <a-v> = pick a target window, then open the hovered file as a
    --           vertical split off that window
    --   <a-x> = same, but horizontal split
    -- this is the missing composition of <c-o> (open_and_pick_window,
    -- which only does :edit in the picked window) and <c-v>/<c-x>
    -- (which split in the previously focused window without asking).
    -- alt-key combos chosen because <c-a-v>/<c-a-x> don't survive
    -- many terminals; wezterm passes plain alt cleanly. install
    -- happens from on_yazi_ready because that hook receives both the
    -- yazi terminal buffer and the live YaziProcessApi needed to
    -- drive select_current_file_and_close_yazi.
    hooks = {
      on_yazi_ready = function(buffer, cfg, process_api)
        local ok_helpers, helpers = pcall(require, 'yazi.keybinding_helpers')
        if not ok_helpers then return end

        local function pick_and_split(split_cmd)
          return function()
            helpers.select_current_file_and_close_yazi(cfg, {
              api = process_api,
              -- single-file path
              on_file_opened = function(chosen_file, _, _)
                if vim.fn.isdirectory(chosen_file) == 1 then return end
                local ok_pu, picker_util = pcall(require, 'snacks.picker.util')
                if not ok_pu then return end
                local picked = picker_util.pick_win()
                if not picked or not vim.api.nvim_win_is_valid(picked) then
                  return
                end
                vim.api.nvim_set_current_win(picked)
                vim.cmd(split_cmd .. ' ' .. vim.fn.fnameescape(chosen_file))
              end,
              -- multi-file path: pick the target window ONCE, then
              -- open every selected file as a fresh split off it.
              on_multiple_files_opened = function(chosen_files)
                local ok_pu, picker_util = pcall(require, 'snacks.picker.util')
                if not ok_pu then return end
                local picked = picker_util.pick_win()
                if not picked or not vim.api.nvim_win_is_valid(picked) then
                  return
                end
                vim.api.nvim_set_current_win(picked)
                for _, f in ipairs(chosen_files) do
                  if vim.fn.isdirectory(f) ~= 1 then
                    vim.cmd(split_cmd .. ' ' .. vim.fn.fnameescape(f))
                  end
                end
              end,
            })
          end
        end

        vim.keymap.set(
          't',
          '<a-v>',
          pick_and_split('vsplit'),
          { buffer = buffer, desc = 'yazi: pick window, vsplit' }
        )
        vim.keymap.set(
          't',
          '<a-x>',
          pick_and_split('split'),
          { buffer = buffer, desc = 'yazi: pick window, hsplit' }
        )
      end,
    },
  },
  keys = {
    {
      '<localleader>yf',
      mode = { 'n', 'v' },
      '<cmd>Yazi<cr>',
      desc = 'Open yazi at the current file',
    },
    {
      -- Open in the current working directory
      '<localleader>yd',
      mode = { 'n', 'v' },
      '<cmd>Yazi cwd<cr>',
      desc = "Open the file manager in nvim's working directory",
    },
    {
      -- NOTE: this requires a version of yazi that includes
      -- https://github.com/sxyazi/yazi/pull/1305 from 2024-07-18
      '<localleader>yr',
      mode = { 'n' },
      '<cmd>Yazi toggle<cr>',
      desc = 'Resume the last yazi session',
    },
  },
}
