-- An import of '@qbx_core/shared/config.lua' lands here. The file itself lives in whip_bridge.
local src = LoadResourceFile('whip_bridge', 'shared/config.lua')
assert(src, "[qbx_core] whip_bridge is not installed, so 'shared/config.lua' cannot be loaded")
return assert(load(src, '@whip_bridge/shared/config.lua'))()
