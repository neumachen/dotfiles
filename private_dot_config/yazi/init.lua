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
