return {
  'gregorias/toggle.nvim',
  init = function()
    require('toggle').setup({
      keymaps = {
        toggle_option_prefix = 'yo',
        previous_option_prefix = false, -- Disabled to free [o for sort.nvim
        next_option_prefix = false, -- Disabled to free ]o for sort.nvim
        status_dashboard = 'yos',
      },
      -- The interface for registering keymaps.
      keymap_registry = require('toggle.keymap').keymap_registry(),
      -- See the default options section below.
      -- options_by_keymap = …,
      --- Whether to notify when a default option is set.
      notify_on_set_default_option = true,
    })
  end,
}
