-- An import of '@qbx_core/shared/locale.lua' lands here. The file itself lives in whip_bridge.
local src = LoadResourceFile('whip_bridge', 'shared/locale.lua')
assert(src, "[qbx_core] whip_bridge is not installed, so 'shared/locale.lua' cannot be loaded")
return assert(load(src, '@whip_bridge/shared/locale.lua'))()
