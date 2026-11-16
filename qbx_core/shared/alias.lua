-- `provide` doesn't route exports (FiveM resolves __cfx_export_<resource>_<name>), so each export is also registered under every provided name.
local self = GetCurrentResourceName()
local aliases = {}
for i = 0, GetNumResourceMetadata(self, 'provide') - 1 do
    aliases[#aliases + 1] = GetResourceMetadata(self, 'provide', i)
end

local mt = getmetatable(exports)
local register = mt.__call
mt.__call = function(t, name, fn)
    register(t, name, fn)
    for _, alias in ipairs(aliases) do
        AddEventHandler(('__cfx_export_%s_%s'):format(alias, name), function(setCB) setCB(fn) end)
    end
end
