-- One name answers every provided resource, so a name two of them share takes both argument shapes.
local B, W = Bridge, Whip.core
local QF, Inv = QBCore.Functions, B.inv

local builtAt = -10000
local function coreObject()
    if GetResourceState('whip_core') == 'started' and GetGameTimer() - builtAt > 5000 then
        local ok, err = pcall(B.rebuildShared)
        if not ok then print('^3[qbx_core] Shared: ' .. tostring(err) .. '^0') end
        builtAt = GetGameTimer()
    end
    return QBCore
end

local function anyPlayer(who)
    local s = B.resolve(who)
    if s then return QF.GetPlayer(s) end
    if type(who) == 'string' then return B.offlinePlayer(who) end
end

local function person(who)
    local s = B.resolve(who)
    if s then return s end
    local cid = tonumber(who)
    if type(who) == 'string' and cid then return { charId = cid } end
end

local function call(who, fn, ...)
    local pl = anyPlayer(who)
    if not pl then return false end
    return pl.Functions[fn](...)
end

exports('GetCoreObject', coreObject)
exports('GetShared', function(namespace, item)
    local s = coreObject().Shared
    if not namespace then return s end
    local ns = s[namespace]
    if ns == nil then return nil end
    if item ~= nil then return ns[item] end
    return ns
end)
exports('GetCoreVersion', function() return '1.0.0-whip' end)
exports('AddJob', QF.AddJob)
exports('AddJobs', QF.AddJobs)
exports('UpdateJob', QF.UpdateJob)
exports('AddGang', QF.AddGang)
exports('AddGangs', QF.AddGangs)
exports('UpdateGang', QF.UpdateGang)
exports('AddItems', QF.AddItems)
exports('UpdateItem', QF.UpdateItem)
exports('AddPlayerField', QF.AddPlayerField)
exports('AddPlayerMethod', QF.AddPlayerMethod)
exports('SetMethod', QF.SetMethod)
exports('SetField', QF.SetField)
exports('ExploitBan', QF.ExploitBan)
exports('GetOfflinePlayerByCitizenId', QF.GetOfflinePlayerByCitizenId)
exports('GetOfflinePlayerByLicense', QBCore.Player.GetOfflinePlayerByLicense)
exports('GetPlayerByLicense', QF.GetPlayerByLicense)

exports('RemoveJob', QF.RemoveJob)
exports('RemoveGang', QF.RemoveGang)

exports('GetPlayer', function(who) return anyPlayer(who) end)
exports('GetPlayerByCitizenId', QF.GetPlayerByCitizenId)
exports('GetOfflinePlayer', function(cid) return B.offlinePlayer(cid) end)
exports('GetPlayerByPhone', QF.GetPlayerByPhone)
exports('GetPlayerByUserId', QF.GetPlayerByUserId)
exports('GetUserId', QF.GetUserId)
exports('GetQBPlayers', QF.GetQBPlayers)
exports('GetPlayersData', QF.GetPlayersData)
exports('GetSource', QF.GetSource)
exports('SearchPlayers', function(filters)
    local out = {}
    for _, d in ipairs(QF.GetPlayersData()) do
        local ok = true
        for k, v in pairs(filters or {}) do
            local have = d[k] or d.charinfo[k] or d.metadata[k]
            if type(v) == 'table' and v.value ~= nil then v = v.value end
            if tostring(have) ~= tostring(v) then ok = false break end
        end
        if ok then out[#out + 1] = d end
    end
    return out
end)
exports('Login', QBCore.Player.Login)
exports('Logout', QBCore.Player.Logout)
exports('Save', QBCore.Player.Save)
exports('SaveOffline', QBCore.Player.SaveOffline)
exports('CreatePlayer', QBCore.Player.CreatePlayer)
exports('DeleteCharacter', QBCore.Player.DeleteCharacter)
exports('CreateSessionId', function() return Convert.randomStr(16) end)
exports('GenerateUniqueIdentifier', function(kind)
    if kind == 'citizenid' then return QBCore.Player.CreateCitizenId() end
    if kind == 'FingerId' or kind == 'fingerprint' then return QBCore.Player.CreateFingerId() end
    if kind == 'WalletId' or kind == 'walletid' then return QBCore.Player.CreateWalletId() end
    if kind == 'SerialNumber' then return QBCore.Player.CreateSerialNumber() end
    if kind == 'PhoneNumber' then return QF.CreatePhoneNumber() end
    if kind == 'AccountNumber' then return QF.CreateAccountNumber() end
    return Convert.randomStr(10)
end)

exports('SetPlayerData', function(who, key, val) return call(who, 'SetPlayerData', key, val) end)
exports('UpdatePlayerData', function(who) return call(who, 'UpdatePlayerData') end)
-- qbx SetMetadata(who, key, value); ox SetMetadata(inv, slot, metadata): a number slot and a table say ox.
exports('SetMetadata', function(a1, a2, a3)
    if type(a2) == 'number' and type(a3) == 'table' then return Inv.setMetadata(a1, a2, a3, false) end
    return call(a1, 'SetMetaData', a2, a3)
end)
exports('GetMetadata', function(who, key) return call(who, 'GetMetaData', key) end)
exports('SetCharInfo', function(who, key, val)
    if key == 'firstname' or key == 'lastname' or key == 'birthdate' or key == 'gender' then
        print('^3[qbx_core] SetCharInfo: names, birthdate and gender are whip\'s (/whip → Players)^0')
        return false
    end
    local p = person(who)
    local ok = p and W:SetPlayerMetadata(p, key, val)
    if type(p) == 'number' then B.refresh(p) end
    return ok == true
end)

exports('AddMoney', function(who, kind, amount, reason) return call(who, 'AddMoney', kind, amount, reason) end)
exports('RemoveMoney', function(who, kind, amount, reason) return call(who, 'RemoveMoney', kind, amount, reason) end)
exports('SetMoney', function(who, kind, amount, reason) return call(who, 'SetMoney', kind, amount, reason) end)
exports('GetMoney', function(who, kind) return call(who, 'GetMoney', kind) end)

exports('GetJobs', function() return coreObject().Shared.Jobs end)
exports('GetJob', function(name) return coreObject().Shared.Jobs[name] end)
exports('GetGangs', function() return QBCore.Shared.Gangs end)
exports('GetGang', function(name) return QBCore.Shared.Gangs[name] end)
exports('CreateJob', function(name, def) return QF.AddJob(name, def) end)
exports('CreateJobs', function(jobs) return QF.AddJobs(jobs) end)
exports('UpsertJobData', function(name, data)
    local def = BridgeConfig.Jobs[name] or QBCore.Shared.Jobs[name] or { grades = {} }
    for k, v in pairs(data) do def[k] = v end
    return QF.AddJob(name, def)
end)
exports('UpsertJobGrade', function(name, grade, data)
    local def = BridgeConfig.Jobs[name] or QBCore.Shared.Jobs[name]
    if not def then return false end
    def.grades[tostring(grade)] = data
    return QF.AddJob(name, def)
end)
exports('RemoveJobGrade', function(name, grade)
    local job = W:GetJob(name)
    local role = job and Convert.roleForGrade(B.rolesOf(job.jobId), grade)
    if not role then return false end
    local ok = W:DeleteJobRole(job.jobId, role.roleId)
    B.Roles[job.jobId] = nil
    B.rebuildShared()
    B.sendShared()
    return ok == true
end)
exports('CreateGangs', QF.AddGangs)
exports('UpsertGangData', function(name, data)
    local def = QBCore.Shared.Gangs[name] or { grades = {} }
    for k, v in pairs(data) do def[k] = v end
    return QF.AddGang(name, def)
end)
exports('UpsertGangGrade', function(name, grade, data)
    local def = QBCore.Shared.Gangs[name]
    if not def then return false end
    def.grades[tostring(grade)] = data
    return QF.AddGang(name, def)
end)
exports('RemoveGangGrade', function(name, grade)
    local def = QBCore.Shared.Gangs[name]
    if not def then return false end
    def.grades[tostring(grade)] = nil
    return QF.AddGang(name, def)
end)

exports('SetJob', function(who, job, grade) local p = person(who) return p and B.setJob(p, job, grade) or false end)
exports('SetGang', function(who, gang, grade) local p = person(who) return p and B.setGang(p, gang, grade) or false end)
exports('SetJobDuty', function(who, onDuty) local s = B.resolve(who) return s and B.setDuty(s, onDuty) or false end)
exports('SetPlayerPrimaryJob', function(who, job)
    local s = B.resolve(who)
    if not s then return false end
    local ok = W:ClockOn(s, job)
    B.refresh(s)
    return ok == true
end)
exports('AddPlayerToJob', function(who, job, grade)
    local p = person(who)
    return p and B.setJob(p, job, grade, { clockOn = false }) or false
end)
exports('RemovePlayerFromJob', function(who, job)
    local p = person(who)
    if not p then return false end
    local ok = W:FirePlayer(p, job)
    if type(p) == 'number' then B.refresh(p) end
    return ok == true
end)
exports('SetPlayerPrimaryGang', function(who, gang)
    local p = person(who)
    return p and B.setGang(p, gang, 0) or false
end)
exports('AddPlayerToGang', function(who, gang, grade) local p = person(who) return p and B.setGang(p, gang, grade) or false end)
exports('RemovePlayerFromGang', function(who) local p = person(who) return p and B.setGang(p, 'none', 0) or false end)
exports('GetGroups', function(who) local p = person(who) return p and B.getGroups(p) or {} end)
exports('HasPrimaryGroup', function(src, filter) return B.hasGroup(src, filter, true) end)
exports('HasGroup', function(src, filter) return B.hasGroup(src, filter, false) end)
exports('GetGroupMembers', function(group, kind)
    local out = {}
    if kind == 'gang' then
        for _, d in ipairs(QF.GetPlayersData()) do
            if d.gang.name == group then out[#out + 1] = { citizenid = d.citizenid, grade = d.gang.grade.level } end
        end
        return out
    end
    local job = W:GetJob(group)
    local staff = job and W:GetJobEmployees(job.jobId) or {}
    for charId, e in pairs(staff) do
        out[#out + 1] = { citizenid = tostring(charId), grade = Convert.gradeIndex(B.rolesOf(job.jobId), e.roleId) }
    end
    return out
end)
exports('GetDutyCountJob', QF.GetDutyCount)
exports('GetDutyCountType', function(kind)
    local n, list = 0, {}
    for src in pairs(B.Players) do
        local j = B.jobOf(src)
        local shared = QBCore.Shared.Jobs[j.name]
        if j.onduty and shared and shared.type == kind then n = n + 1 list[n] = src end
    end
    return n, list
end)
exports('IsGradeBoss', function(job, grade)
    local j = coreObject().Shared.Jobs[job] or QBCore.Shared.Gangs[job]
    local g = j and j.grades[tostring(grade)]
    return g ~= nil and g.isboss == true
end)

exports('Notify', QF.Notify)
exports('HasPermission', QF.HasPermission)
exports('GetPermission', QF.GetPermission)
exports('AddPermission', QF.AddPermission)
exports('RemovePermission', QF.RemovePermission)
exports('IsOptin', QF.IsOptin)
exports('ToggleOptin', QF.ToggleOptin)
exports('IsPlayerBanned', QF.IsPlayerBanned)
exports('IsWhitelisted', QF.IsWhitelisted)
exports('CreateUseableItem', QF.CreateUseableItem)
exports('CanUseItem', QF.CanUseItem)
exports('GetBucketObjects', QF.GetBucketObjects)
exports('SetPlayerBucket', QF.SetPlayerBucket)
exports('SetEntityBucket', QF.SetEntityBucket)
exports('GetPlayersInBucket', QF.GetPlayersInBucket)
exports('GetEntitiesInBucket', QF.GetEntitiesInBucket)
exports('GetLocations', function() return QBCore.Shared.Locations end)
exports('GetWeapons', function() return coreObject().Shared.Weapons end)
exports('GetVehiclesByName', function(name)
    local v = coreObject().Shared.Vehicles
    if name then return v[name] end
    return v
end)
exports('GetVehiclesByHash', function(hash)
    local v = coreObject().Shared.VehicleHashes
    if hash then return v[hash] end
    return v
end)
exports('GetVehiclesByCategory', function() coreObject() return B.vehiclesByCategory() end)
exports('GetVehicleClass', B.vehicleClass)
exports('DeleteVehicle', B.deleteVehicle)
exports('BridgeSpawnVehicle', B.spawnVehicle)
exports('EnablePersistence', function() return true end)
exports('DisablePersistence', function() return true end)

-- qb-core AddItem(name, def) registers an item; qb-inventory / ox AddItem(inv, item, ...) gives one.
exports('AddItem', function(a1, a2, a3, a4, a5, a6)
    if type(a1) == 'string' and type(a2) == 'table' then return QF.AddItem(a1, a2) end
    local inv, item, amount, meta, slot, reason = Convert.itemArgs(a1, a2, a3, a4, a5, a6)
    return Inv.add(inv, item, amount, meta, slot, reason)
end)
exports('RemoveItem', function(a1, a2, a3, a4, a5, a6)
    if type(a1) == 'string' and a2 == nil then return QF.RemoveItem(a1) end
    local inv, item, amount, meta, slot, reason = Convert.itemArgs(a1, a2, a3, a4, a5, a6)
    return Inv.remove(inv, item, amount, meta, slot, reason)
end)
exports('HasItem', function(inv, items, amount) return Inv.has(inv, items, amount) end)
exports('GetItemCount', function(inv, items, meta)
    local total = 0
    for item in pairs(Convert.itemList(items)) do total = total + Inv.count(inv, item, meta) end
    return total
end)
exports('GetItemByName', function(inv, item) return Inv.byName(inv, item)[1] end)
exports('GetItemsByName', function(inv, item) return Inv.byName(inv, item) end)
exports('GetItemBySlot', function(inv, slot) return Inv.itemsOf(inv)[tonumber(slot)] end)
exports('GetFirstSlotByItem', function(items, name)
    local best
    for slot, it in pairs(items or {}) do
        if it.name == name and (not best or tonumber(slot) < best) then best = tonumber(slot) end
    end
    return best
end)
exports('GetSlotsByItem', function(items, name)
    local out = {}
    for slot, it in pairs(items or {}) do if it.name == name then out[#out + 1] = tonumber(slot) end end
    table.sort(out)
    return out
end)
exports('GetTotalWeight', function(items) return Convert.weight(items) end)
exports('GetFreeWeight', function(inv)
    local _, max = Inv.capacity(inv)
    return max - Convert.weight(Inv.itemsOf(inv))
end)
exports('GetSlots', function(inv)
    local slots = Inv.capacity(inv)
    local used = 0
    for _ in pairs(Inv.itemsOf(inv)) do used = used + 1 end
    return used, slots - used
end)
exports('CanAddItem', function(inv, item, amount)
    if Inv.canCarry(inv, item, amount) then return true end
    return false, 'weight'
end)
exports('CanCarryItem', function(inv, item, amount, meta) return Inv.canCarry(inv, item, amount, meta) end)
exports('CanCarryAmount', function(inv, item)
    local def = B.itemDefs()[item]
    if not def then return 0 end
    local w = Convert.item(item, def).weight
    local _, max = Inv.capacity(inv)
    local free = max - Convert.weight(Inv.itemsOf(inv))
    if w <= 0 then return 1000000 end
    return math.max(0, math.floor(free / w))
end)
exports('CanCarryWeight', function(inv, weight)
    local _, max = Inv.capacity(inv)
    local free = max - Convert.weight(Inv.itemsOf(inv))
    return (tonumber(weight) or 0) <= free, free
end)
exports('CanSwapItem', function(inv, firstItem, firstCount, testItem, testCount)
    local def1, def2 = B.itemDefs()[firstItem], B.itemDefs()[testItem]
    if not def1 or not def2 then return false end
    if Inv.count(inv, firstItem) < firstCount then return false end
    local _, max = Inv.capacity(inv)
    local w = Convert.weight(Inv.itemsOf(inv)) - Convert.item(firstItem, def1).weight * firstCount
        + Convert.item(testItem, def2).weight * testCount
    return w <= max
end)

exports('ClearInventory', function(inv, keep) return Inv.clear(inv, keep) end)
exports('ClearStash', function(name) return Inv.clear(name) end)
exports('SetInventory', function(inv, items) return Inv.setItems(inv, items) end)
exports('setPlayerInventory', function(player, items) return Inv.setItems(player.source or player, items) end)
exports('SetItemData', function(src, itemName, key, val)
    local it = Inv.byName(src, itemName)[1]
    if not it then return false end
    if key == 'info' or key == 'metadata' then return Inv.setMetadata(src, it.slot, val, false) end
    return Inv.setMetadata(src, it.slot, { [key] = val }, true)
end)

exports('GetInventory', function(inv) return Inv.oxInventory(inv) end)
exports('GetInventoryItems', function(inv) return Inv.itemsOf(inv) end)
exports('LoadInventory', function(src) return Inv.items(src) end)
exports('SaveInventory', function(src) if type(src) == 'number' then W:SavePlayer(src) end return true end)
exports('GetItem', function(inv, item, meta, returnsCount)
    local count = Inv.count(inv, item, meta)
    if returnsCount then return count end
    local def = B.itemDefs()[item]
    if not def then return nil end
    local qb = Convert.item(item, def)
    return { name = item, label = qb.label, weight = qb.weight, count = count, stack = not qb.unique,
        close = true, description = qb.description }
end)
exports('Search', function(inv, search, item, meta)
    local single = type(item) == 'string'
    local out = {}
    for name in pairs(Convert.itemList(item)) do
        if search == 'count' then
            out[name] = Inv.count(inv, name, meta)
        else
            local list = {}
            for _, it in ipairs(Inv.byName(inv, name, meta)) do list[#list + 1] = Inv.oxItem(it) end
            out[name] = list
        end
    end
    if single then return out[item] end
    return out
end)
exports('GetSlot', function(inv, slot)
    local it = Inv.itemsOf(inv)[tonumber(slot)]
    return it and Inv.oxItem(it) or nil
end)
local function slotsWith(inv, item, meta)
    local out = {}
    for _, it in ipairs(Inv.byName(inv, item, meta)) do out[#out + 1] = it end
    return out
end
exports('GetSlotWithItem', function(inv, item, meta) local s = slotsWith(inv, item, meta)[1] return s and Inv.oxItem(s) end)
exports('GetSlotsWithItem', function(inv, item, meta)
    local out = {}
    for _, it in ipairs(slotsWith(inv, item, meta)) do out[#out + 1] = Inv.oxItem(it) end
    return out
end)
exports('GetSlotIdWithItem', function(inv, item, meta) local s = slotsWith(inv, item, meta)[1] return s and s.slot end)
exports('GetSlotIdsWithItem', function(inv, item, meta)
    local out = {}
    for _, it in ipairs(slotsWith(inv, item, meta)) do out[#out + 1] = it.slot end
    return out
end)
exports('GetItemSlots', function(inv, item, meta)
    local slots, total, free = {}, 0, 0
    for _, it in ipairs(slotsWith(inv, item, meta)) do slots[it.slot] = it.amount total = total + it.amount end
    local max = Inv.capacity(inv)
    local items = Inv.itemsOf(inv)
    for i = 1, max do if not items[i] then free = free + 1 end end
    return slots, total, free
end)
exports('GetSlotForItem', function(inv, item)
    local s = slotsWith(inv, item)[1]
    if s and not s.unique then return s.slot end
    return Convert.freeSlot(Inv.itemsOf(inv), (Inv.capacity(inv)))
end)
exports('GetEmptySlot', function(inv) return Convert.freeSlot(Inv.itemsOf(inv), (Inv.capacity(inv))) end)
exports('GetContainerFromSlot', function() return nil end)
exports('SetSlotCount', function(inv, slots)
    local ref = Convert.invRef(inv)
    local addr = ref and ref.stash and Inv.addr(inv)
    return addr and W:UpdateContainer(addr.id, { slots = slots }) == true or false
end)
exports('SetMaxWeight', function(inv, weight)
    local ref = Convert.invRef(inv)
    local addr = ref and ref.stash and Inv.addr(inv)
    return addr and W:UpdateContainer(addr.id, { maxWeight = (tonumber(weight) or 0) / 1000 }) == true or false
end)
exports('SetDurability', function(inv, slot, durability)
    return Inv.setMetadata(inv, slot, { durability = durability }, true)
end)
exports('SwapSlots', function(fromInv, toInv, fromSlot, toSlot) return Inv.swap(fromInv, toInv, fromSlot, toSlot) end)

exports('RegisterStash', function(name, label, slots, maxWeight, owner, groups, coords)
    local id = (owner and owner ~= true) and (name .. ':' .. tostring(owner)) or name
    return Inv.registerStash(id, { label = label, slots = slots, maxWeight = maxWeight, groups = groups, coords = coords })
end)
exports('CreateInventory', function(name, data)
    data = data or {}
    return Inv.registerStash(name, { label = data.label, slots = data.slots, maxWeight = data.maxweight or data.maxWeight })
end)
exports('CreateTemporaryStash', function(def) return Inv.temporaryStash(def) end)
exports('RemoveInventory', function(name) return Inv.removeStash(name) end)
exports('OpenInventory', function(src, inv) return Inv.open(src, inv or src, false) end)
exports('OpenInventoryById', function(src, target) return Inv.open(src, tonumber(target), false) end)
exports('forceOpenInventory', function(src, kind, data)
    local id = type(data) == 'table' and (data.id or data.name) or data
    if kind == 'trunk' then id = 'trunk' .. tostring(id) elseif kind == 'glovebox' then id = 'glove' .. tostring(id) end
    return Inv.open(src, id, false)
end)
exports('InspectInventory', function(target, src) return Inv.open(src, tonumber(target), false) end)
exports('CloseInventory', function(src, inv) return Inv.close(src, inv) end)
exports('ConfiscateInventory', function(src) return Inv.confiscate(src) end)
exports('ReturnInventory', function(src) return Inv.returnConfiscated(src) end)
exports('CreateShop', function(data) return Inv.registerShop(data.name, data) end)
exports('RegisterShop', function(name, data) return Inv.registerShop(name, data) end)
exports('OpenShop', function(src, name) return Inv.openShop(src, name) end)
exports('CustomDrop', function(prefix, items, coords) return Inv.drop(items, coords, prefix) end)
exports('CreateDropFromPlayer', function(src) return Inv.dropFromPlayer(src) end)
exports('UseItem', function(item, ...) local cb = Inv.useHandler(item) if cb ~= nil then return cb(...) end end)
exports('Items', function(name) local all = Inv.oxItems() if name then return all[name] end return all end)
exports('ItemList', function() return Inv.oxItems() end)
exports('GetCurrentWeapon', function(src)
    local held = W:GetHeldItem(src)
    if not held then return nil end
    return { name = held.item, slot = held.addr.slot, metadata = held.metadata, count = held.amount }
end)
exports('Inventory', function(inv) return Inv.oxInventory(inv) end)
exports('GetInventories', function() return {} end)
exports('UpdateVehicle', function() return true end)
exports('ConvertItems', function() return {} end)
exports('registerHook', function(event, fn, opts) return Inv.addHook(event, fn, opts) end)
exports('removeHooks', function(id) Inv.removeHooks(id) end)
exports('AddHook', function(event, fn, opts) return Inv.addHook(event, fn, opts) end)
exports('RemoveHook', function(id) Inv.removeHooks(id) end)
exports('AddListener', function(event, fn) return Inv.addHook(event, fn) end)
exports('RemoveListener', function(id) Inv.removeHooks(id) end)
