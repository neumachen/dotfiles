-- Hammerspoon config
-- ~/.hammerspoon is a symlink -> ~/.config/hammerspoon (managed by chezmoi)

local hs = hs -- luacheck: ignore

-- Reload config on file change
hs.pathwatcher.new(os.getenv('HOME') .. '/.config/hammerspoon', hs.reload):start()
hs.alert.show('Hammerspoon config loaded')
