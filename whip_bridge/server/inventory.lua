-- Weights are grams here, kg in whip.
local B, W = Bridge, Whip.core
local Inv = {}
B.inv = Inv

local Stashes = {}
local StashIds = {}
local Shops = {}
local UseHandlers = {}
local Hooks, nextHook = {}, 0

-- ponytail: a fixed hidden spot; give the stash coords (RegisterStash's coords) when players should walk up to it.
local HIDDEN = { x = 0.0, y = 0.0, z = -300.0 }

-- A hook returning false stops the change. whip's own drags are not hooked.
local function runHooks(event, payload)
    for _, h in ipairs(Hooks) do
        if h.event == event or h.event == '*' then
            local ok, res = pcall(h.fn, payload)
            if ok and res == false then return false end
        end
    end
    return true
end

function Inv.addHook(event, fn, opts)
    nextHook = nextHook + 1
    Hooks[#Hooks + 1] = { id = nextHook, event = event, fn = fn, opts = opts, resource = GetInvokingResource() }
    return nextHook
end

function Inv.removeHooks(id)
    local res = GetInvokingResource()
    for i = #Hooks, 1, -1 do
        if (id and Hooks[i].id == id) or (not id and Hooks[i].resource == res) then table.remove(Hooks, i) end
    end
end

AddEventHandler('onResourceStop', function(res)
    for i = #Hooks, 1, -1 do if Hooks[i].resource == res then table.remove(Hooks, i) end end
end)

local function ensureStash(name)
    if StashIds[name] then return StashIds[name] end
    local def = Stashes[name] or {}
    local c = def.coords or HIDDEN
    local data = {
        name = def.label or name,
        slots = def.slots or 50,
        maxWeight = (def.maxWeight or 100000) / 1000,
        x = c.x, y = c.y, z = c.z, heading = c.w or c.heading or 0.0,
    }
    if def.groups then
        local jobs = {}
        for k, v in pairs(def.groups) do jobs[#jobs + 1] = type(k) == 'number' and v or k end
        data.requirements = { jobs = jobs }
    end
    local container, why = W:EnsureContainer(Convert.stashKey(name), data)
    if not container then return nil, why end
    StashIds[name] = container.containerId
    return container.containerId
end

function Inv.addr(inv, slot)
    local ref = Convert.invRef(inv)
    if not ref then return nil, 'Unknown inventory' end
    local addr
    if ref.player then
        addr = { kind = 'player', id = ref.player, sub = 'player' }
    elseif ref.vehicle then
        addr = { kind = 'vehicle', id = { plate = ref.vehicle }, sub = ref.sub }
    else
        local id, why = ensureStash(ref.stash)
        if not id then return nil, why end
        addr = { kind = 'container', id = id }
    end
    addr.slot = slot
    return addr, ref
end

function Inv.items(src)
    return Convert.items(W:GetInventory(src), B.itemDefs())
end

function Inv.itemsOf(inv)
    local addr, ref = Inv.addr(inv)
    if not addr then return {} end
    if ref.player then return Inv.items(ref.player) end
    local c = W:StoreRead(addr)
    if not c then return {} end
    return Convert.items({ player = c.items or c }, B.itemDefs())
end

local function metaMatches(it, meta)
    if type(meta) ~= 'table' then return true end
    for k, v in pairs(meta) do if it.info[k] ~= v then return false end end
    return true
end

function Inv.byName(inv, item, meta)
    local out = {}
    for _, it in pairs(Inv.itemsOf(inv)) do
        if it.name == item and metaMatches(it, meta) then out[#out + 1] = it end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

function Inv.count(inv, item, meta)
    local ref = Convert.invRef(inv)
    if ref and ref.player and type(meta) ~= 'table' then return W:GetItemCount(ref.player, item) or 0 end
    local n = 0
    for _, it in ipairs(Inv.byName(inv, item, meta)) do n = n + it.amount end
    return n
end

function Inv.has(inv, items, amount)
    for item, n in pairs(Convert.itemList(items, amount)) do
        if Inv.count(inv, item) < n then return false end
    end
    return true
end

function Inv.capacity(inv)
    local ref = Convert.invRef(inv)
    if not ref then return 0, 0 end
    if ref.player then
        return W:GetPocketSlots('player') or 30, math.floor((W:GetPocketMaxWeight('player') or 0) * 1000)
    end
    local addr = Inv.addr(inv)
    local c = addr and W:StoreRead(addr)
    if not c then return 0, 0 end
    return c.slots or 0, math.floor((c.maxWeight or 0) * 1000)
end

function Inv.canCarry(inv, item, amount, meta)
    local ref = Convert.invRef(inv)
    if not ref then return false end
    if ref.player then return W:CanFitItem(ref.player, item, amount or 1, meta) == true end
    local def = B.itemDefs()[item]
    if not def then return false end
    local items = Inv.itemsOf(inv)
    local slots, max = Inv.capacity(inv)
    local w = Convert.weight(items) + Convert.item(item, def).weight * (amount or 1)
    return w <= max and (Convert.freeSlot(items, slots) ~= nil or #Inv.byName(inv, item) > 0)
end

local function ensureItem(item)
    if not BridgeConfig.AutoCreateItems or type(item) ~= 'string' or not item:match('^[%w_%-]+$') then return end
    if B.itemDefs()[item] then return end
    B.forgetDefs()
    if B.itemDefs()[item] then return end
    local label = item:gsub('_', ' '):gsub('(%a)(%w*)', function(a, b) return a:upper() .. b end)
    local ok, why = W:RegisterItem(item, { name = label, weight = 0.1, stack = true })
    if ok then
        print(('^3[whip_bridge] made item "%s" (%s) because %s gave it and whip didn\'t know it. Add it to whip\'s item list.^0')
            :format(item, label, GetInvokingResource() or 'a script'))
        B.forgetDefs()
    else
        print(('^3[whip_bridge] item %s is unknown and could not be made: %s^0'):format(item, why))
    end
end

function Inv.add(inv, item, amount, meta, slot, reason)
    amount = amount or 1
    ensureItem(item)
    local addr, ref = Inv.addr(inv, slot)
    if not addr then return false, ref end
    if not runHooks('createItem', { inventoryId = inv, item = item, count = amount, metadata = meta, slot = slot }) then
        return false, 'Refused by a hook'
    end
    local ok, why
    if ref.player then
        if slot then ok, why = W:StoreGive(addr, item, amount, meta, reason) end
        if not ok then
            local where
            where, why = W:AddItem(ref.player, item, amount, meta, reason or GetInvokingResource())
            ok = where ~= false and where ~= nil
        end
        if ok then B.queueRefresh(ref.player) end
    else
        ok, why = W:StoreGive(addr, item, amount, meta, reason)
        if not ok and slot then
            addr.slot = nil
            ok, why = W:StoreGive(addr, item, amount, meta, reason)
        end
        ok = ok ~= false and ok ~= nil
    end
    return ok, why
end

function Inv.remove(inv, item, amount, meta, slot, reason)
    amount = amount or 1
    local addr, ref = Inv.addr(inv, slot)
    if not addr then return false, ref end
    local ok, why
    if slot then
        local at = W:GetItemAt(addr)
        if not at or at.item ~= item then return false, 'That slot does not hold ' .. tostring(item) end
        ok, why = W:StoreTake(addr, amount, reason)
    elseif ref.player then
        ok, why = W:RemoveItem(ref.player, item, amount, meta, reason or GetInvokingResource())
    elseif type(meta) == 'table' then
        local left = amount
        for _, it in ipairs(Inv.byName(inv, item, meta)) do
            local take = math.min(left, it.amount)
            local a = { kind = addr.kind, id = addr.id, sub = addr.sub, slot = it.slot }
            if W:StoreTake(a, take, reason) then left = left - take end
            if left <= 0 then break end
        end
        ok = left <= 0
        why = not ok and 'Not enough' or nil
    else
        ok, why = W:StoreTake(addr, amount, { item = item, reason = reason })
    end
    ok = ok ~= false and ok ~= nil
    if ok and ref.player then B.queueRefresh(ref.player) end
    return ok, why
end

function Inv.clear(inv, keep)
    local keepSet = {}
    if type(keep) == 'string' then keepSet[keep] = true
    elseif type(keep) == 'table' then
        for k, v in pairs(keep) do keepSet[type(k) == 'number' and v or k] = true end
    end
    local addr, ref = Inv.addr(inv)
    if not addr then return false end
    for slot, it in pairs(Inv.itemsOf(inv)) do
        if not keepSet[it.name] then
            W:StoreTake({ kind = addr.kind, id = addr.id, sub = addr.sub, slot = slot }, nil, 'cleared')
        end
    end
    if ref.player then B.queueRefresh(ref.player) end
    return true
end

function Inv.setItems(inv, items)
    Inv.clear(inv)
    for _, it in pairs(items or {}) do
        if it.name then Inv.add(inv, it.name, it.amount or it.count or 1, it.info or it.metadata, it.slot, 'SetInventory') end
    end
end
Inv.setPlayerItems = Inv.setItems

function Inv.setMetadata(inv, slot, meta, merge)
    local addr = Inv.addr(inv, tonumber(slot))
    if not addr or not addr.slot then return false end
    local ok = W:SetItemMetadata(addr, meta or {}, { replace = not merge })
    local ref = Convert.invRef(inv)
    if ok and ref.player then B.queueRefresh(ref.player) end
    return ok == true
end

function Inv.swap(fromInv, toInv, fromSlot, toSlot, amount)
    local a = Inv.addr(fromInv, fromSlot)
    local b = Inv.addr(toInv, toSlot)
    if not a or not b then return false end
    if not runHooks('swapItems', { fromInventory = fromInv, toInventory = toInv, fromSlot = fromSlot, toSlot = toSlot, count = amount }) then
        return false
    end
    return W:StoreMove(a, b, { amount = amount }) == true
end

function Inv.registerStash(name, def)
    Stashes[name] = def
    StashIds[name] = nil
    if Whip.isReady() then return ensureStash(name) ~= nil end
    return true
end

function Inv.temporaryStash(def)
    local c = W:CreateContainer({ name = def.label or 'Stash', slots = def.slots or 50,
        maxWeight = (def.maxWeight or 100000) / 1000, persist = false, prop = false,
        x = HIDDEN.x, y = HIDDEN.y, z = HIDDEN.z, items = def.items })
    if not c then return nil end
    local name = 'temp:' .. c.containerId
    StashIds[name] = c.containerId
    return name
end

function Inv.removeStash(name)
    local id = StashIds[name] or (W:GetContainer({ key = Convert.stashKey(name) }) or {}).containerId
    if not id then return false end
    StashIds[name], Stashes[name] = nil, nil
    return W:DeleteContainer(id) == true
end

-- fromClient: the player's own game asked, so whip's distance and access checks stay on.
function Inv.open(src, inv, fromClient)
    local ref = Convert.invRef(inv)
    if not ref then return false, 'Unknown inventory' end
    if not runHooks('openInventory', { source = src, inventoryId = inv }) then return false, 'Refused by a hook' end
    if ref.player then
        if ref.player == src then return false, 'Your pockets open with your inventory key' end
        return W:OpenPlayerInventory(src, ref.player, { range = fromClient and 3 or false })
    end
    if fromClient and ref.stash and not (Stashes[ref.stash] and Stashes[ref.stash].coords) then
        return false, 'That stash opens from its own script'
    end
    local addr, why = Inv.addr(inv)
    if not addr then return false, why end
    return W:OpenStore(src, addr, { skipDistance = not fromClient, skipAccess = not fromClient })
end

function Inv.close(src, inv)
    local addr = inv and Inv.addr(inv)
    if addr and addr.kind ~= 'player' then return W:CloseStore(src, addr) end
    return W:ClosePlayerInventory(src)
end

function Inv.registerShop(name, def)
    Shops[name] = def
    if not Whip.isReady() then return true end
    local loc = def.coords or (def.locations and def.locations[1])
    if not loc then return false, 'A shop needs a location in whip' end
    local catalog = {}
    for _, it in pairs(def.items or def.inventory or {}) do
        catalog[it.name] = math.floor(tonumber(it.price) or 0)
    end
    return W:EnsureShop(Convert.stashKey('shop:' .. name), {
        name = def.label or def.name or name, mode = 'npc',
        x = loc.x, y = loc.y, z = loc.z, heading = loc.w or 0.0,
        npcModel = def.ped or def.model, catalog = catalog, blipSprite = def.blip and def.blip.id or nil,
    })
end

function Inv.openShop(src, name)
    QBCore.Functions.Notify(src, 'Walk up to the shop counter to buy', 'primary')
    return false, ('whip opens shop "%s" from its counter'):format(tostring(name))
end

local function registerUse(item)
    local cb = UseHandlers[item]
    -- false keeps the item: qb/ox scripts take it themselves with RemoveItem.
    exports.whip_core:RegisterUseHandler(item, function(source, _, slotData, addr)
        local qbItem = Convert.slot(addr and addr.slot or 0, slotData, B.itemDefs()[item])
        local ok, err = pcall(cb, source, qbItem)
        if not ok then print(('^1[whip_bridge] use handler for %s: %s^0'):format(item, err)) end
        return false
    end)
end

function Inv.createUseable(item, cb)
    UseHandlers[item] = cb
    QBCore.UseableItems[item] = true
    if Whip.isReady() then registerUse(item) end
end

function Inv.useHandler(item) return UseHandlers[item] end

function Inv.reRegister()
    for item in pairs(UseHandlers) do registerUse(item) end
    StashIds = {}
    for name in pairs(Stashes) do ensureStash(name) end
    for name, def in pairs(Shops) do Inv.registerShop(name, def) end
end

function Inv.drop(items, coords, reason)
    local made = 0
    for _, it in pairs(items) do
        local name = it.name or it[1]
        local count = it.amount or it.count or it[2] or 1
        local ok = W:CreateGroundItem({ item = name, amount = count, metadata = it.metadata or it.info or it[3],
            coords = vector3(coords.x, coords.y, coords.z), reason = reason })
        if ok then made = made + 1 end
    end
    return made > 0
end

function Inv.dropFromPlayer(src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local items = Inv.items(src)
    for slot in pairs(items) do
        W:StoreTake({ kind = 'player', id = src, sub = 'player', slot = slot }, nil, 'dropped')
    end
    B.queueRefresh(src)
    return Inv.drop(items, coords, 'CreateDropFromPlayer')
end

local function confiscateName(src)
    local pl = B.Players[src]
    return pl and ('confiscated:' .. pl.PlayerData.citizenid)
end

function Inv.confiscate(src)
    local name = confiscateName(src)
    if not name then return false end
    Inv.registerStash(name, { label = 'Confiscated', slots = 60, maxWeight = 1000000 })
    local to = Inv.addr(name)
    for slot in pairs(Inv.items(src)) do
        W:StoreMove({ kind = 'player', id = src, sub = 'player', slot = slot }, to)
    end
    B.queueRefresh(src)
    return true
end

function Inv.returnConfiscated(src)
    local name = confiscateName(src)
    if not name then return false end
    local from = Inv.addr(name)
    for slot in pairs(Inv.itemsOf(name)) do
        W:StoreMove({ kind = from.kind, id = from.id, slot = slot }, { kind = 'player', id = src, sub = 'player' })
    end
    B.queueRefresh(src)
    return true
end

local function oxItem(it)
    return { name = it.name, label = it.label, weight = it.weight, count = it.amount, slot = it.slot,
        metadata = it.info, stack = not it.unique, close = it.shouldClose, description = it.description }
end

function Inv.oxInventory(inv)
    local ref = Convert.invRef(inv)
    if not ref then return nil end
    local items = {}
    for slot, it in pairs(Inv.itemsOf(inv)) do items[slot] = oxItem(it) end
    local slots, max = Inv.capacity(inv)
    local label = ref.player and (GetPlayerName(ref.player) or '') or (ref.stash or ref.vehicle)
    return {
        id = inv, label = label, type = ref.player and 'player' or (ref.vehicle and ref.sub) or 'stash',
        slots = slots, maxWeight = max, weight = Convert.weight(Inv.itemsOf(inv)), items = items,
        owner = ref.player and B.Players[ref.player] and B.Players[ref.player].PlayerData.citizenid or nil,
    }
end

function Inv.oxItems()
    local all = {}
    for key, def in pairs(B.itemDefs()) do
        local qb = Convert.item(key, def)
        all[key] = { name = key, label = qb.label, weight = qb.weight, stack = not qb.unique, close = true,
            description = qb.description, consume = 0 }
    end
    return all
end

Inv.oxItem = oxItem

RegisterNetEvent('qbx_core:bridge:openInventory', function(invType, data)
    local src = source
    local id = type(data) == 'table' and (data.id or data.name) or data
    if invType == 'player' or invType == 'otherplayer' then id = tonumber(id) end
    if invType == 'trunk' and type(id) == 'string' then id = 'trunk' .. id end
    if invType == 'glovebox' and type(id) == 'string' then id = 'glove' .. id end
    local ok, why = Inv.open(src, id, true)
    if not ok and why then QBCore.Functions.Notify(src, why, 'error') end
end)

RegisterNetEvent('qbx_core:bridge:useSlot', function(slot)
    local src = source
    local it = Inv.items(src)[tonumber(slot)]
    local cb = it and UseHandlers[it.name]
    if cb ~= nil then cb(src, it) end
end)

RegisterNetEvent('qbx_core:bridge:closeInventory', function()
    W:ClosePlayerInventory(source)
end)
