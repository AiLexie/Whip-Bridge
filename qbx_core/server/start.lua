local B, W = Bridge, Whip.core

local function clientEvents(defs)
    for key, def in pairs(defs or {}) do
        local event = type(def) == 'table' and type(def.client) == 'table' and def.client.event
        if event and not B.inv.useHandler(key) then
            B.inv.createUseable(key, function(src, item) TriggerClientEvent(event, src, item, item and item.slot) end)
        end
    end
end
clientEvents(BridgeConfig.Items)

Whip.register(function()
    for key, def in pairs(BridgeConfig.Items) do
        local ok, why = W:RegisterItem(key, Convert.toWhipItem(def))
        if not ok and not tostring(why):find('belongs to') then print(('^3[qbx_core] item %s: %s^0'):format(key, why)) end
    end
    for key, def in pairs(BridgeConfig.Jobs) do B.ensureJob(key, def) end
    clientEvents(W:GetItemDefs())
    B.inv.reRegister()
    B.forgetDefs()
    B.Roles = {}
    B.rebuildShared()
    for src in pairs(W:GetPlayers({ light = true }) or {}) do
        src = tonumber(src)
        if src then CreateThread(function() B.loadPlayer(src) end) end
    end
    B.sendShared()
end)

-- Build the shared tables before whip_core is ready, since scripts after us grab QBCore as they load.
do
    local ok, err = pcall(B.rebuildShared)
    if not ok then print('^3[qbx_core] Shared at start: ' .. tostring(err) .. '^0') end
end

-- Wait for ready: whip_core has to create its own tables before ours can read from them.
CreateThread(function()
    Whip.ready()
    B.sql.install()
end)
