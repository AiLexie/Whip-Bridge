local B, W = Bridge, Whip.core
local QF, Players = QBCore.Functions, B.Players

QF.GetPlayer = function(src)
    if type(src) == 'string' and not tonumber(src) then return nil end
    src = tonumber(src)
    local pl = src and Players[src]
    if pl then pl.PlayerData = B.buildData(src) or pl.PlayerData end
    return pl
end
QF.GetPlayerByCitizenId = function(cid) local s = B.resolve(tostring(cid)) return s and QF.GetPlayer(s) end
QF.GetOfflinePlayerByCitizenId = function(cid) return B.offlinePlayer(cid) end
QF.GetPlayerByLicense = function(license) return B.playerByLicense(license) end
QF.GetPlayerByPhone = function(phone)
    for src, pl in pairs(Players) do
        if pl.PlayerData.charinfo.phone == phone then return QF.GetPlayer(src) end
    end
end
QF.GetPlayerByAccount = function(account)
    for src, pl in pairs(Players) do
        if pl.PlayerData.charinfo.account == account then return QF.GetPlayer(src) end
    end
end
QF.GetPlayerByCharInfo = function(props)
    for src, pl in pairs(Players) do
        local ok = true
        for k, v in pairs(props or {}) do if pl.PlayerData.charinfo[k] ~= v then ok = false break end end
        if ok then return QF.GetPlayer(src) end
    end
end
QF.GetPlayers = function()
    local out = {}
    for src in pairs(Players) do out[#out + 1] = src end
    return out
end
QF.GetQBPlayers = function()
    for src in pairs(Players) do QF.GetPlayer(src) end
    return Players
end
QF.GetPlayersData = function()
    local out = {}
    for src in pairs(Players) do out[#out + 1] = QF.GetPlayer(src).PlayerData end
    return out
end
QF.GetPlayersByJob = function(job, checkOnDuty)
    local list, n = {}, 0
    for src in pairs(Players) do
        local j = B.jobOf(src)
        if j.name == job and (not checkOnDuty or j.onduty) then n = n + 1 list[n] = src end
    end
    return list, n
end
QF.GetPlayersOnDuty = function(job) return QF.GetPlayersByJob(job, true) end
QF.GetDutyCount = function(job)
    local list, n = QF.GetPlayersByJob(job, true)
    return n, list
end

QF.GetIdentifier = function(src, kind)
    if kind == nil or kind == 'license' then
        local ids = W:GetPlayerIdentifiers(src)
        if ids and ids.license then return ids.license end
    end
    return GetPlayerIdentifierByType(src, kind or 'license')
end
QF.GetSource = function(identifier)
    for _, s in ipairs(GetPlayers()) do
        for _, id in ipairs(GetPlayerIdentifiers(s)) do
            if id == identifier then return tonumber(s) end
        end
    end
    return 0
end
QF.GetUserId = function(src) local pl = Players[src] return pl and pl.PlayerData.userId end
QF.GetPlayerByUserId = function(userId)
    local p = W:GetPlayer({ userId = tonumber(userId) })
    return p and QF.GetPlayer(p.source) or nil
end

QF.GetCoords = function(entity)
    local c = GetEntityCoords(entity)
    return vector4(c.x, c.y, c.z, GetEntityHeading(entity))
end

local function closest(src, list, coords, skip)
    if not coords then coords = GetEntityCoords(GetPlayerPed(src)) end
    coords = vector3(coords.x, coords.y, coords.z)
    local best, dist = -1, -1
    for _, ent in ipairs(list) do
        if ent ~= skip then
            local d = #(coords - GetEntityCoords(ent))
            if dist == -1 or d < dist then best, dist = ent, d end
        end
    end
    return best, dist
end
QF.GetClosestPlayer = function(src, coords)
    local me = src and GetPlayerPed(src)
    local best, dist = -1, -1
    coords = coords or (me and GetEntityCoords(me))
    for _, s in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(s)
        if ped ~= me then
            local d = #(vector3(coords.x, coords.y, coords.z) - GetEntityCoords(ped))
            if dist == -1 or d < dist then best, dist = tonumber(s), d end
        end
    end
    return best, dist
end
QF.GetClosestVehicle = function(src, coords) return closest(src, GetAllVehicles(), coords) end
QF.GetClosestObject = function(src, coords) return closest(src, GetAllObjects(), coords) end
QF.GetClosestPed = function(src, coords)
    local peds = {}
    for _, p in ipairs(GetAllPeds()) do if not IsPedAPlayer(p) then peds[#peds + 1] = p end end
    return closest(src, peds, coords)
end

QF.GetBucketObjects = function()
    local players, entities = {}, {}
    for _, s in ipairs(GetPlayers()) do players[tonumber(s)] = GetPlayerRoutingBucket(s) end
    for _, list in ipairs({ GetAllVehicles(), GetAllPeds(), GetAllObjects() }) do
        for _, e in ipairs(list) do entities[e] = GetEntityRoutingBucket(e) end
    end
    return players, entities
end
QF.SetPlayerBucket = function(src, bucket)
    if not src or not bucket then return false end
    SetPlayerRoutingBucket(src, bucket)
    return true
end
QF.SetEntityBucket = function(entity, bucket)
    if not entity or not bucket then return false end
    SetEntityRoutingBucket(entity, bucket)
    return true
end
QF.GetPlayersInBucket = function(bucket)
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        if GetPlayerRoutingBucket(s) == bucket then out[#out + 1] = tonumber(s) end
    end
    return #out > 0 and out or false
end
QF.GetEntitiesInBucket = function(bucket)
    local out = {}
    for _, list in ipairs({ GetAllVehicles(), GetAllPeds(), GetAllObjects() }) do
        for _, e in ipairs(list) do if GetEntityRoutingBucket(e) == bucket then out[#out + 1] = e end end
    end
    return #out > 0 and out or false
end

QF.SpawnVehicle = function(src, model, coords, warp) return (B.spawnVehicle(src, model, coords, warp)) end
QF.CreateVehicle = function(src, model, _, coords, warp) return (B.spawnVehicle(src, model, coords, warp)) end
QF.CreateAutomobile = QF.CreateVehicle
QF.GetPlate = function(veh) return B.getPlate(veh) end

QF.Notify = function(src, text, kind, length)
    if type(text) == 'table' then text = text.text or text.caption end
    W:NotifyPlayer(src, tostring(text), Convert.notifyType(kind), length)
end

local function hasOne(src, perm)
    if perm == nil or perm == 'user' then return true end
    if IsPlayerAceAllowed(src, perm) or IsPlayerAceAllowed(src, 'qbcore.' .. perm) then return true end
    local whipPerm = BridgeConfig.Permissions[perm] or perm
    return W:HasPermission(src, whipPerm) == true
end
QF.HasPermission = function(src, perm)
    if src == 0 then return true end
    if type(perm) == 'table' then
        for _, p in pairs(perm) do if hasOne(src, p) then return true end end
        return false
    end
    return hasOne(src, perm)
end
QF.GetPermission = function(src)
    local out = {}
    for _, p in ipairs(QBCore.Config.Server.Permissions) do out[p] = hasOne(src, p) end
    for p in pairs(BridgeConfig.Permissions) do out[p] = hasOne(src, p) end
    return out
end
QF.AddPermission = function(src, perm)
    local ok = W:GrantPermission(src, BridgeConfig.Permissions[perm] or perm)
    TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src)
    TriggerEvent('QBCore:Server:OnPermissionUpdate', src)
    return ok == true
end
QF.RemovePermission = function(src, perm)
    local ok
    if perm then
        ok = W:RevokePermission(src, BridgeConfig.Permissions[perm] or perm)
    else
        for p in pairs(QF.GetPermission(src)) do ok = W:RevokePermission(src, BridgeConfig.Permissions[p] or p) end
    end
    TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src)
    TriggerEvent('QBCore:Server:OnPermissionUpdate', src)
    return ok == true
end

local Optout = {}
QF.IsOptin = function(src) return not Optout[src] end
QF.ToggleOptin = function(src)
    Optout[src] = not Optout[src]
    QF.Notify(src, Optout[src] and 'You are opted out' or 'You are opted in', 'primary')
end
QF.IsPlayerBanned = function() return false, '' end
QF.IsWhitelisted = function() return true end
QF.IsLicenseInUse = function(license)
    for _, s in ipairs(GetPlayers()) do
        for _, id in ipairs(GetPlayerIdentifiers(s)) do if id == license then return true end end
    end
    return false
end
QF.Kick = function(src, reason) W:KickPlayer(src, reason or 'Kicked') end
QF.ExploitBan = function(src, name)
    print(('^1[qbx_core] exploit "%s" by %s: kicked^0'):format(tostring(name), tostring(src)))
    W:KickPlayer(src, 'Exploiting')
end

QF.HasItem = function(src, items, amount) return B.inv.has(src, items, amount) end
QF.CreateUseableItem = function(item, cb) B.inv.createUseable(item, cb) end
QF.CanUseItem = function(item) return B.inv.useHandler(item) end
QF.UseItem = function(src, item)
    local name = type(item) == 'table' and item.name or item
    local cb = B.inv.useHandler(name)
    if cb ~= nil then cb(src, type(item) == 'table' and item or B.inv.byName(src, name)[1]) end
end

local function sharedUpdated(key, name, value)
    TriggerClientEvent('QBCore:Client:OnSharedUpdate', -1, key, name, value)
    TriggerEvent('QBCore:Server:UpdateObject')
end

QF.AddItem = function(name, def)
    if type(name) ~= 'string' or type(def) ~= 'table' then return false, 'invalid_item_name' end
    BridgeConfig.Items[name] = def
    if Whip.isReady() then
        local ok, why = W:RegisterItem(name, Convert.toWhipItem(def))
        if not ok then return false, why end
        B.forgetDefs()
    end
    QBCore.Shared.Items[name] = Convert.item(name, Convert.toWhipItem(def))
    sharedUpdated('Items', name, QBCore.Shared.Items[name])
    return true, 'success'
end
QF.UpdateItem = QF.AddItem
QF.AddItems = function(items)
    for name, def in pairs(items) do QF.AddItem(name, def) end
    return true, 'success'
end
QF.RemoveItem = function(name)
    if not BridgeConfig.Items[name] then return false, 'item_not_exists' end
    BridgeConfig.Items[name] = nil
    QBCore.Shared.Items[name] = nil
    sharedUpdated('Items', name, nil)
    return true, 'success'
end

QF.AddJob = function(name, def)
    if type(name) ~= 'string' or type(def) ~= 'table' then return false, 'invalid_job_name' end
    BridgeConfig.Jobs[name] = def
    if Whip.isReady() then
        local ok, why = B.ensureJob(name, def)
        if not ok then return false, why end
        B.rebuildShared()
        B.sendShared()
    end
    return true, 'success'
end
QF.UpdateJob = QF.AddJob
QF.AddJobs = function(jobs)
    for name, def in pairs(jobs) do QF.AddJob(name, def) end
    return true, 'success'
end
QF.RemoveJob = function(name)
    local job = W:GetJob(name)
    if not job then return false, 'job_not_exists' end
    local ok, why = W:DeleteJob(job.jobId)
    if not ok then return false, why end
    BridgeConfig.Jobs[name] = nil
    B.rebuildShared()
    B.sendShared()
    return true, 'success'
end

QF.AddGang = function(name, def)
    if type(name) ~= 'string' or type(def) ~= 'table' then return false, 'invalid_gang_name' end
    QBCore.Shared.Gangs[name] = def
    sharedUpdated('Gangs', name, def)
    B.sendShared()
    return true, 'success'
end
QF.UpdateGang = QF.AddGang
QF.AddGangs = function(gangs)
    for name, def in pairs(gangs) do QF.AddGang(name, def) end
    return true, 'success'
end
QF.RemoveGang = function(name)
    if not QBCore.Shared.Gangs[name] or name == 'none' then return false, 'gang_not_exists' end
    QBCore.Shared.Gangs[name] = nil
    sharedUpdated('Gangs', name, nil)
    B.sendShared()
    return true, 'success'
end

QF.AddPlayerMethod = function(ids, name, handler)
    B.Methods[name] = { ids = ids, handler = handler }
    for src, pl in pairs(Players) do
        if ids == -1 or ids == src or (type(ids) == 'table' and (function() for _, i in pairs(ids) do if i == src then return true end end end)()) then
            pl.Functions[name] = handler
            pl[name] = handler
        end
    end
end
QF.AddPlayerField = function(ids, name, data)
    B.Fields[name] = { ids = ids, data = data }
    for src, pl in pairs(Players) do
        if ids == -1 or ids == src then pl[name] = data end
    end
end
QF.SetMethod = function(name, fn) QBCore.Functions[name] = fn return true, 'success' end
QF.SetField = function(name, data) QBCore[name] = data return true, 'success' end

QF.CreateAccountNumber = function() return 'US0' .. math.random(1, 9) .. 'QBCore' .. Convert.randomInt(7) end
QF.CreatePhoneNumber = function() return math.random(100, 999) .. Convert.randomInt(7) end
QF.GetDatabaseInfo = function()
    return { exists = GetResourceState('oxmysql') == 'started', config = GetConvar('mysql_connection_string', '') }
end
QF.PrepForSQL = function(src, data, pattern)
    data = tostring(data)
    local result = data:match(pattern)
    if result ~= data then
        if src and src > 0 then QF.ExploitBan(src, 'SQL') end
        return false
    end
    return true
end

QF.CreateCallback = function(name, cb) QBCore.ServerCallbacks[name] = cb end

local Pending, nextId = {}, 0
QF.TriggerClientCallback = function(name, src, cb, ...)
    nextId = nextId + 1
    Pending[nextId] = { cb = cb, src = src }
    TriggerClientEvent('qbx_core:bridge:ccb', src, name, nextId, ...)
end
QF.TriggerCallback = function(name, src, cb, ...)
    local fn = QBCore.ServerCallbacks[name]
    if fn ~= nil then fn(src, cb, ...) end
end

RegisterNetEvent('qbx_core:bridge:cb', function(name, id, ...)
    local src = source
    local cb = QBCore.ServerCallbacks[name]
    if cb == nil then return end
    cb(src, function(...) TriggerClientEvent('qbx_core:bridge:cbr', src, id, ...) end, ...)
end)

RegisterNetEvent('qbx_core:bridge:ccbr', function(id, ...)
    local p = Pending[id]
    if not p or p.src ~= source then return end
    Pending[id] = nil
    if p.cb ~= nil then p.cb(...) end
end)

local QP = QBCore.Player
QP.Login = function(src)
    print(('^3[qbx_core] Login(%s): whip_core runs character select; the player picks their character^0'):format(tostring(src)))
    return false
end
QP.Logout = function(src) W:LogoutPlayer(src) end
QP.GetOfflinePlayer = function(cid) return B.offlinePlayer(cid) end
QP.GetPlayerByLicense = function(license) return B.playerByLicense(license) end
QP.GetOfflinePlayerByLicense = function(license) return B.playerByLicense(license) end
QP.CheckPlayerData = function(src) return B.buildData(src) end
QP.CreatePlayer = function(data) return data and data.source and QF.GetPlayer(data.source) end
QP.Save = function(src) W:SavePlayer(src) end
QP.SaveOffline = function() return true end
QP.DeleteCharacter = function(src)
    QF.Notify(src, 'Characters are deleted from the character screen', 'error')
    return false
end
QP.ForceDeleteCharacter = function() return false end
QP.CreateCitizenId = function() return Convert.randomStr(3, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') .. Convert.randomInt(5) end
QP.CreateFingerId = function()
    return Convert.randomInt(1) .. Convert.randomStr(2) .. Convert.randomInt(3) .. Convert.randomStr(3)
        .. Convert.randomInt(2) .. Convert.randomStr(3) .. Convert.randomInt(4) .. Convert.randomStr(2)
end
QP.CreateWalletId = function() return 'QB-' .. Convert.randomInt(8) end
QP.CreateSerialNumber = function() return Convert.randomInt(8) end

RegisterNetEvent('QBCore:ToggleDuty', function()
    local src = source
    local pl = Players[src]
    if not pl or pl.PlayerData.job.name == 'unemployed' then return end
    local key = pl.PlayerData.job.name
    local ok, why
    if pl.PlayerData.job.onduty then ok, why = W:ClockOff(src, key) else ok, why = W:ClockOn(src, key, { by = src }) end
    if not ok and why then QF.Notify(src, why, 'error') end
    B.refresh(src)
end)

RegisterNetEvent('QBCore:CallCommand', function(command, args)
    local src = source
    local cmd = QBCore.Commands.List[tostring(command):lower()]
    if not cmd or not Players[src] then return end
    if not QF.HasPermission(src, cmd.permission) then return end
    if cmd.argsrequired and #(args or {}) < #cmd.arguments then return end
    cmd.callback(src, args or {}, '')
end)

RegisterNetEvent('QBCore:UpdatePlayer', function() B.queueRefresh(source) end)

RegisterNetEvent('qbx_core:bridge:hello', function()
    local src = source
    if Players[src] then
        TriggerClientEvent('qbx_core:bridge:shared', src, B.sharedForClient())
        TriggerClientEvent('qbx_core:bridge:loaded', src, Players[src].PlayerData)
    end
end)

RegisterNetEvent('QBCore:Server:CloseServer', function(reason)
    local src = source
    if not QF.HasPermission(src, 'admin') then return end
    QBCore.Config.Server.Closed = true
    QBCore.Config.Server.ClosedReason = reason or 'Server Closed'
    for s in pairs(Players) do
        if not QF.HasPermission(s, 'admin') then W:KickPlayer(s, QBCore.Config.Server.ClosedReason) end
    end
end)
RegisterNetEvent('QBCore:Server:OpenServer', function()
    if QF.HasPermission(source, 'admin') then QBCore.Config.Server.Closed = false end
end)
AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not QBCore.Config.Server.Closed then return end
    local src = source
    if IsPlayerAceAllowed(src, 'qbcore.join') or IsPlayerAceAllowed(src, 'admin') then return end
    deferrals.defer()
    Wait(0)
    deferrals.done(QBCore.Config.Server.ClosedReason)
end)

AddEventHandler('playerDropped', function() Optout[source] = nil end)
