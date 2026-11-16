-- An import of '@qbx_core/modules/utils.lua' lands here. The file itself lives in whip_bridge.
local src = LoadResourceFile('whip_bridge', 'modules/utils.lua')
assert(src, "[qbx_core] whip_bridge is not installed, so 'modules/utils.lua' cannot be loaded")
return assert(load(src, '@whip_bridge/modules/utils.lua'))()
