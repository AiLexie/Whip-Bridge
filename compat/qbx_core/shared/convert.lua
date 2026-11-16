-- An import of '@qbx_core/shared/convert.lua' lands here. The file itself lives in whip_bridge.
local src = LoadResourceFile('whip_bridge', 'shared/convert.lua')
assert(src, "[qbx_core] whip_bridge is not installed, so 'shared/convert.lua' cannot be loaded")
return assert(load(src, '@whip_bridge/shared/convert.lua'))()
