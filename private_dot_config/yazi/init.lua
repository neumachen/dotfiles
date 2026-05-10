require('starship'):setup()
require('zoxide'):setup({
  update_db = true,
})
require('smart-enter'):setup({
  open_multi = true,
})
require('git'):setup()
require('full-border'):setup({
  type = ui.Border.ROUNDED,
})
require('relative-motions'):setup({
  show_numbers = 'relative_absolute',
  show_motion = true,
  only_motions = true,
  enter_mode = 'cache_or_first',
})
