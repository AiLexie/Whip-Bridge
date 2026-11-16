local W = Whip.core
local QF = QBCore.Functions

local shown = nil
local function drawText(text, position)
    shown = text
    W:ShowText(tostring(text), position == 'top' and 'top' or 'bottom')
end
local function hideText()
    shown = nil
    W:HideText()
end
local function keyPressed()
    if not shown then return end
    local text = shown
    CreateThread(function()
        W:ShowText(tostring(text), { tone = 'warn' })
        Wait(500)
        if shown == text then W:ShowText(tostring(text)) end
    end)
end

exports('DrawText', drawText)
exports('ChangeText', drawText)
exports('HideText', hideText)
exports('KeyPressed', keyPressed)
RegisterNetEvent('qb-core:client:DrawText', drawText)
RegisterNetEvent('qb-core:client:ChangeText', drawText)
RegisterNetEvent('qb-core:client:HideText', hideText)
RegisterNetEvent('qb-core:client:KeyPressed', keyPressed)

local function items() return QBCore.PlayerData.items or {} end

exports('HasItem', QF.HasItem)
exports('GetItemCount', function(item, meta)
    if type(meta) ~= 'table' then return W:GetItemCount(item) or 0 end
    local n = 0
    for _, it in pairs(items()) do
        local match = it.name == item
        for k, v in pairs(meta) do if it.info[k] ~= v then match = false end end
        if match then n = n + it.amount end
    end
    return n
end)
exports('Search', function(search, item, meta)
    local single = type(item) == 'string'
    local out = {}
    for name in pairs(Convert.itemList(item)) do
        local list, count = {}, 0
        for _, it in pairs(items()) do
            local match = it.name == name
            if match and type(meta) == 'table' then
                for k, v in pairs(meta) do if it.info[k] ~= v then match = false end end
            end
            if match then list[#list + 1] = it count = count + it.amount end
        end
        out[name] = search == 'count' and count or list
    end
    if single then return out[item] end
    return out
end)
exports('Items', function(name)
    local all = {}
    for key, def in pairs(W:GetItemDefs() or {}) do
        local qb = Convert.item(key, def)
        all[key] = { name = key, label = qb.label, weight = qb.weight, stack = not qb.unique, close = true,
            description = qb.description }
    end
    if name then return all[name] end
    return all
end)
exports('GetPlayerItems', function() return items() end)
exports('GetPlayerWeight', function() return Convert.weight(items()) end)
exports('GetPlayerMaxWeight', function() return QBCore.PlayerData.maxWeight or 0 end)
exports('getCurrentWeapon', function()
    local held = W:GetHeldItem()
    if not held then return nil end
    local it = items()[held.slot]
    return it and { name = it.name, slot = it.slot, metadata = it.info } or nil
end)
exports('openInventory', function(invType, data)
    if invType == nil or invType == 'player' and data == nil then
        ExecuteCommand('inventory')
        return
    end
    TriggerServerEvent('qbx_core:bridge:openInventory', invType, data)
end)
exports('openNearbyInventory', function()
    local p, d = QF.GetClosestPlayer()
    if p ~= -1 and d < 2.0 then TriggerServerEvent('qbx_core:bridge:openInventory', 'otherplayer', GetPlayerServerId(p)) end
end)
exports('closeInventory', function() W:CloseInventory() end)
exports('displayMetadata', function() end)
exports('setStashTarget', function() end)
exports('weaponWheel', function() end)
exports('suppressItemNotifications', function() end)
exports('useSlot', function(slot) TriggerServerEvent('qbx_core:bridge:useSlot', slot) end)
exports('useItem', function(data, cb)
    if cb ~= nil then cb(data) end
end)
exports('notify', function(data)
    if type(data) ~= 'table' then return end
    QF.Notify(data.description or data.title or '', data.type, data.duration)
end)
exports('Progress', function(opts, completed)
    local ok = W:Progress({ label = opts.label, duration = opts.duration, canCancel = opts.canCancel,
        anim = opts.anim and { dict = opts.anim.dict, clip = opts.anim.clip, flag = opts.anim.flag, scenario = opts.anim.scenario },
        prop = opts.prop and { model = opts.prop.model, bone = opts.prop.bone, offset = opts.prop.pos, rot = opts.prop.rot },
        disable = opts.disable and { move = opts.disable.move, car = opts.disable.car, combat = opts.disable.combat } })
    if completed ~= nil then completed(not ok) end
    return ok
end)
exports('ProgressActive', function() return W:IsProgressActive() end)
exports('CancelProgress', function() W:CancelProgress() end)
exports('giveItemToTarget', function() end)
