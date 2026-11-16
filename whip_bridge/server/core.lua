local W = Whip.core

QBCore = {
    Config = {
        Money = { MoneyTypes = { cash = 0, bank = 0, crypto = 0 }, DontAllowMinus = { 'cash', 'crypto' } },
        Server = { Closed = false, ClosedReason = 'Server Closed', PVP = true, Permissions = { 'god', 'admin', 'mod' } },
        Player = { HungerRate = 4.2, ThirstRate = 3.8 },
        Notify = { NotificationStyling = {} },
    },
    Shared = {
        Items = {}, Jobs = {}, Gangs = BridgeConfig.Gangs, Vehicles = {}, VehicleHashes = {}, Weapons = {},
        Locations = BridgeConfig.Locations, StarterItems = {}, ForceJobDefaultDutyAtLogin = false,
    },
    Functions = {},
    Player = {},
    Players = {},
    PlayersByCitizenId = {},
    Commands = { List = {}, IgnoreList = { god = true, user = true } },
    ServerCallbacks = {},
    ClientCallbacks = {},
    UseableItems = {},
}

Convert.sharedHelpers(QBCore.Shared)

Bridge = {
    W = W,
    Players = {},
    Bank = {},
    Extra = {},
    Methods = {},
    Fields = {},
    Roles = {},
}
local B = Bridge
local Players, Bank, Extra = B.Players, B.Bank, B.Extra
local Pushing = {}
local Defs, DefsAt = {}, -10000

function B.itemDefs()
    if GetGameTimer() - DefsAt > 5000 then
        Defs = W:GetItemDefs() or Defs
        DefsAt = GetGameTimer()
    end
    return Defs
end

function B.forgetDefs() DefsAt = -10000 end

function B.rolesOf(jobId)
    if not B.Roles[jobId] then B.Roles[jobId] = W:GetJobRoles(jobId) or {} end
    return B.Roles[jobId]
end

-- Scripts grab QBCore at load, often before whip_core is ready, so config items and jobs go in up front.
function B.rebuildShared()
    local items = {}
    for key, def in pairs(BridgeConfig.Items) do items[key] = Convert.item(key, Convert.toWhipItem(def)) end
    for key, def in pairs(B.itemDefs()) do items[key] = Convert.item(key, def) end
    QBCore.Shared.Items = items
    local jobs = { unemployed = { label = 'Civilian', type = 'none', defaultDuty = true, offDutyPay = false,
        grades = { ['0'] = { name = 'Freelancer', payment = 0 } } } }
    for key, def in pairs(BridgeConfig.Jobs) do
        jobs[key] = { label = def.label or key, type = def.type or 'none', defaultDuty = false, offDutyPay = false,
            grades = def.grades or {} }
    end
    for _, def in ipairs(W:GetJobs() or {}) do jobs[def.key] = Convert.sharedJob(def, B.rolesOf(def.jobId)) end
    QBCore.Shared.Jobs = jobs
    if B.rebuildVehicles then B.rebuildVehicles() end
    GlobalState.qbxShared = B.sharedForClient()
end

function B.sharedForClient()
    local s = QBCore.Shared
    return { Jobs = s.Jobs, Gangs = s.Gangs, Vehicles = s.Vehicles, VehicleHashes = s.VehicleHashes,
        Weapons = s.Weapons, Locations = s.Locations }
end

function B.sendShared(target)
    TriggerClientEvent('qbx_core:bridge:shared', target or -1, B.sharedForClient())
    TriggerClientEvent('QBCore:Client:UpdateObject', target or -1)
    if not target or target == -1 then TriggerEvent('QBCore:Server:UpdateObject') end
end

function B.jobOf(who)
    local info = W:GetPlayerJob(who)
    if not info then
        local first
        for _, j in pairs(W:GetPlayerJobs(who) or {}) do
            if not first or j.jobId < first.jobId then first = j end
        end
        info = first
    end
    if not info then return Convert.UNEMPLOYED end
    return Convert.job(info, B.rolesOf(info.jobId), W:GetJob(info.jobId))
end

local function gangOf(meta)
    return type(meta.qb_gang) == 'table' and meta.qb_gang or Convert.NO_GANG
end

function B.buildData(src)
    local p = W:GetPlayer(src)
    if not p then return nil end
    local meta = Convert.metadata(p.metadata, p)
    local ids = W:GetPlayerIdentifiers(src) or {}
    local data = {
        source = src,
        citizenid = tostring(p.charId),
        cid = p.charId,
        userId = p.userId,
        license = ids.license,
        name = GetPlayerName(src),
        money = { cash = p.cash or 0, bank = Bank[src] and Bank[src].balance or 0, crypto = tonumber(meta.crypto) or 0 },
        charinfo = Convert.charinfo(p, meta),
        job = B.jobOf(src),
        gang = gangOf(meta),
        metadata = meta,
        items = Convert.items(W:GetInventory(src), B.itemDefs()),
        position = p.position,
        optin = true,
        lastLoggedOut = 0,
        maxWeight = math.floor((W:GetPocketMaxWeight('player') or 0) * 1000),
        slots = W:GetPocketSlots('player') or 30,
    }
    data.charinfo.account = data.charinfo.account ~= '' and data.charinfo.account
        or (Bank[src] and Bank[src].accountNumber) or ''
    for k, v in pairs(Extra[src] or {}) do data[k] = v end
    return data
end

function B.resolve(who)
    if type(who) == 'number' then return Players[who] and who or nil end
    local cid = tonumber(who)
    if not cid then return nil end
    for src, pl in pairs(Players) do
        if pl.PlayerData.cid == cid then return src end
    end
end

function B.readBank(src)
    local acct = W:GetDefaultBankAccount(src)
    local bal = W:GetBalance(src)
    Bank[src] = { accountId = acct and acct.accountId, accountNumber = acct and acct.accountNumber,
        balance = tonumber(bal) or 0 }
end

local function moneyEvents(src, old, new, reason)
    for _, kind in ipairs({ 'cash', 'bank', 'crypto' }) do
        local d = (new[kind] or 0) - (old[kind] or 0)
        if d ~= 0 then
            local how = d > 0 and 'add' or 'remove'
            TriggerClientEvent('QBCore:Client:OnMoneyChange', src, kind, math.abs(d), how, reason)
            TriggerClientEvent('hud:client:OnMoneyChange', src, kind, math.abs(d), d < 0)
            TriggerEvent('QBCore:Server:OnMoneyChange', src, kind, math.abs(d), how, reason)
        end
    end
end

local function jobChanged(a, b)
    return a.name ~= b.name or a.grade.level ~= b.grade.level or a.onduty ~= b.onduty
end

function B.refresh(src, reason)
    local pl = Players[src]
    if not pl then return end
    local data = B.buildData(src)
    if not data then return end
    local old = pl.PlayerData
    pl.PlayerData = data
    moneyEvents(src, old.money, data.money, reason)
    if jobChanged(old.job, data.job) then
        TriggerClientEvent('QBCore:Client:OnJobUpdate', src, data.job)
        TriggerEvent('QBCore:Server:OnJobUpdate', src, data.job)
        TriggerClientEvent('qbx_core:client:onJobUpdate', src, data.job)
        TriggerEvent('qbx_core:server:onJobUpdate', src, data.job)
        TriggerClientEvent('qbx_core:client:onGroupUpdate', src, data.job.name, data.job.grade.level)
        TriggerEvent('qbx_core:server:onGroupUpdate', src, data.job.name, data.job.grade.level)
        if old.job.onduty ~= data.job.onduty then
            TriggerClientEvent('QBCore:Client:SetDuty', src, data.job.onduty)
            TriggerEvent('QBCore:Server:SetDuty', src, data.job.onduty)
        end
    end
    if old.gang.name ~= data.gang.name or old.gang.grade.level ~= data.gang.grade.level then
        TriggerClientEvent('QBCore:Client:OnGangUpdate', src, data.gang)
        TriggerEvent('QBCore:Server:OnGangUpdate', src, data.gang)
        TriggerClientEvent('qbx_core:client:onGangUpdate', src, data.gang)
        TriggerEvent('qbx_core:server:onGangUpdate', src, data.gang)
    end
    for k, v in pairs(data.metadata) do
        if old.metadata[k] ~= v and type(v) ~= 'table' then
            TriggerClientEvent('qbx_core:client:onSetMetaData', src, k, old.metadata[k], v)
            TriggerEvent('qbx_core:server:onSetMetaData', k, old.metadata[k], v, src)
        end
    end
    TriggerEvent('QBCore:Player:SetPlayerData', data)
    TriggerClientEvent('QBCore:Player:SetPlayerData', src, data)
end

function B.queueRefresh(src)
    if not Players[src] or Pushing[src] then return end
    Pushing[src] = true
    SetTimeout(200, function()
        Pushing[src] = nil
        B.refresh(src)
    end)
end

function B.getMoney(src, kind)
    local pl = Players[src]
    return pl and pl.PlayerData.money[kind] or 0
end

function B.addMoney(src, kind, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if not Players[src] or amount < 0 then return false end
    if amount == 0 then return true end
    if kind == 'crypto' then
        local ok = W:SetPlayerMetadata(src, 'crypto', B.getMoney(src, 'crypto') + amount)
        if ok then B.refresh(src, reason) end
        return ok == true
    end
    if kind ~= 'cash' and kind ~= 'bank' then return false end
    local res = W:PayPlayer(src, amount, { method = kind, reason = reason or GetInvokingResource() or 'qb' })
    if not res then return false end
    if kind == 'bank' then B.readBank(src) end
    B.refresh(src, reason)
    return true
end

function B.removeMoney(src, kind, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if not Players[src] or amount < 0 then return false end
    if amount == 0 then return true end
    if kind == 'crypto' then
        local have = B.getMoney(src, 'crypto')
        if have < amount then return false end
        local ok = W:SetPlayerMetadata(src, 'crypto', have - amount)
        if ok then B.refresh(src, reason) end
        return ok == true
    end
    if kind ~= 'cash' and kind ~= 'bank' then return false end
    local receipt = W:ChargePlayer(src, amount, { method = kind, reason = reason or GetInvokingResource() or 'qb' })
    if not receipt then return false end
    if kind == 'bank' then
        B.readBank(src)
        TriggerClientEvent('qb-phone:client:RemoveBankMoney', src, amount)
    end
    B.refresh(src, reason)
    return true
end

function B.setMoney(src, kind, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    local d = amount - B.getMoney(src, kind)
    if d > 0 then return B.addMoney(src, kind, d, reason) end
    if d < 0 then return B.removeMoney(src, kind, -d, reason) end
    return true
end

function B.setJob(who, jobKey, grade, opts)
    opts = opts or {}
    local src = type(who) == 'number' and who or nil
    if jobKey == 'unemployed' then
        if src then W:ClockOff(src) B.refresh(src) end
        return true
    end
    local def = W:GetJob(jobKey)
    if not def then return false, 'No such job' end
    local role = Convert.roleForGrade(B.rolesOf(def.jobId), grade)
    if not role then return false, 'That job has no roles' end
    local ok, why
    if W:GetPlayerRole(who, def.jobId) then
        ok, why = W:SetPlayerRole(who, def.jobId, role.roleId)
    else
        ok, why = W:HirePlayer(who, def.jobId, role.roleId)
    end
    if not ok then return false, why end
    if src and opts.clockOn ~= false then W:ClockOn(src, def.jobId) end
    if src then B.refresh(src) end
    return true
end

function B.setDuty(src, onDuty)
    local pl = Players[src]
    if not pl or pl.PlayerData.job.name == 'unemployed' then return false end
    local ok
    if onDuty then ok = W:ClockOn(src, pl.PlayerData.job.name) else ok = W:ClockOff(src, pl.PlayerData.job.name) end
    B.refresh(src)
    return ok == true
end

function B.gangEntry(gangKey, grade)
    local g = QBCore.Shared.Gangs[gangKey]
    if not g then return nil end
    local level = math.floor(tonumber(grade) or 0)
    local gr = g.grades[tostring(level)] or g.grades[level] or g.grades['0'] or { name = '' }
    return { name = gangKey, label = g.label, isboss = gr.isboss == true, bankAuth = gr.bankAuth == true,
        grade = { name = gr.name, level = level } }
end

function B.setGang(who, gangKey, grade)
    local gang = B.gangEntry(gangKey, grade)
    if not gang then return false, 'No such gang' end
    local ok, why = W:SetPlayerMetadata(who, 'qb_gang', gangKey ~= 'none' and gang or false)
    if type(who) == 'number' then B.refresh(who) end
    return ok == true, why
end

function B.hasGroup(src, filter, primaryOnly)
    local pl = Players[src]
    if not pl then return false end
    local want = Convert.groupFilter(filter)
    local d = pl.PlayerData
    if want[d.job.name] and d.job.grade.level >= want[d.job.name] then return d.job.name, d.job.grade.level end
    if want[d.gang.name] and d.gang.grade.level >= want[d.gang.name] then return d.gang.name, d.gang.grade.level end
    if primaryOnly then return false end
    for _, j in pairs(W:GetPlayerJobs(src) or {}) do
        local lvl = Convert.gradeIndex(B.rolesOf(j.jobId), j.roleId)
        if want[j.key] and lvl >= want[j.key] then return j.key, lvl end
    end
    return false
end

function B.getGroups(who)
    local jobs, gangs = {}, {}
    for _, j in pairs(W:GetPlayerJobs(who) or {}) do jobs[j.key] = Convert.gradeIndex(B.rolesOf(j.jobId), j.roleId) end
    local src = type(who) == 'number' and who
    local pl = src and Players[src]
    if pl and pl.PlayerData.gang.name ~= 'none' then gangs[pl.PlayerData.gang.name] = pl.PlayerData.gang.grade.level end
    local all = {}
    for k, v in pairs(jobs) do all[k] = v end
    for k, v in pairs(gangs) do all[k] = v end
    return all, jobs, gangs
end

local function appliesTo(ids, src)
    if ids == -1 or ids == nil then return true end
    if type(ids) == 'number' then return ids == src end
    for _, id in pairs(ids) do if id == src then return true end end
    return false
end

function B.finishPlayer(self, src)
    for name, fn in pairs(self.Functions) do
        -- Through an export, the self a colon call passes is a copy: know it by its PlayerData.
        self[name] = function(first, ...)
            if type(first) == 'table' and first.PlayerData ~= nil then return fn(...) end
            return fn(first, ...)
        end
    end
    for name, m in pairs(B.Methods) do
        if appliesTo(m.ids, src) then self.Functions[name] = m.handler self[name] = m.handler end
    end
    for name, f in pairs(B.Fields) do
        if appliesTo(f.ids, src) then self[name] = f.data end
    end
    return self
end

function B.makePlayer(src)
    local self = { PlayerData = B.buildData(src), Functions = {}, Offline = false }
    if not self.PlayerData then return nil end
    local F = self.Functions

    F.GetPlayerData = function() return self.PlayerData end
    F.UpdateClient = function(key, val)
        B.refresh(src)
        if key then
            TriggerEvent('QBCore:Server:OnPlayerUpdated', src, key, val)
            TriggerClientEvent('QBCore:Client:OnPlayerUpdated', src, key, val)
        end
    end
    F.UpdatePlayerData = F.UpdateClient
    F.GetName = function() return self.PlayerData.charinfo.firstname .. ' ' .. self.PlayerData.charinfo.lastname end
    F.Notify = function(text, kind, length) QBCore.Functions.Notify(src, text, kind, length) end

    F.SetPlayerData = function(key, val)
        if key == 'metadata' and type(val) == 'table' then
            for k, v in pairs(val) do W:SetPlayerMetadata(src, k, v) end
        elseif key == 'money' and type(val) == 'table' then
            for kind, amount in pairs(val) do B.setMoney(src, kind, amount, 'SetPlayerData') end
        elseif key == 'job' and type(val) == 'table' then
            B.setJob(src, val.name, val.grade and val.grade.level or 0)
        elseif key == 'gang' and type(val) == 'table' then
            B.setGang(src, val.name, val.grade and val.grade.level or 0)
        elseif key == 'items' then
            B.inv.setPlayerItems(src, val)
        elseif key == 'charinfo' and type(val) == 'table' then
            for k, v in pairs(val) do
                if k ~= 'firstname' and k ~= 'lastname' and k ~= 'birthdate' and k ~= 'gender' then
                    W:SetPlayerMetadata(src, k, v)
                end
            end
        else
            Extra[src] = Extra[src] or {}
            Extra[src][key] = val
        end
        B.refresh(src)
    end
    F.SetMetaData = function(key, val)
        if type(key) ~= 'string' then return false end
        if key == 'hunger' or key == 'thirst' then val = math.max(0, math.min(100, tonumber(val) or 0)) end
        local ok, why = W:SetPlayerMetadata(src, key, val)
        if not ok then print(('^3[whip_bridge] SetMetaData %s: %s^0'):format(key, tostring(why))) end
        B.refresh(src)
        if key == 'hunger' or key == 'thirst' then
            local m = self.PlayerData.metadata
            TriggerClientEvent('hud:client:UpdateNeeds', src, m.hunger, m.thirst)
        end
        return ok == true
    end
    F.SetMetadata = F.SetMetaData
    F.GetMetaData = function(key)
        if key == nil then return self.PlayerData.metadata end
        return self.PlayerData.metadata[key]
    end
    F.GetMetadata = F.GetMetaData

    local function setRep(table_, key, value)
        local rep = self.PlayerData.metadata[table_] or {}
        rep[key] = value
        F.SetMetaData(table_, rep)
    end
    F.AddRep = function(rep, amount) setRep('rep', rep, (self.PlayerData.metadata.rep[rep] or 0) + (tonumber(amount) or 0)) end
    F.RemoveRep = function(rep, amount)
        setRep('rep', rep, math.max(0, (self.PlayerData.metadata.rep[rep] or 0) - (tonumber(amount) or 0)))
    end
    F.GetRep = function(rep) return self.PlayerData.metadata.rep[rep] or 0 end
    F.AddJobReputation = function(amount)
        local job = self.PlayerData.job.name
        setRep('jobrep', job, (self.PlayerData.metadata.jobrep[job] or 0) + (tonumber(amount) or 0))
    end

    F.SetJob = function(job, grade) return (B.setJob(src, job, grade)) end
    F.SetGang = function(gang, grade) return (B.setGang(src, gang, grade)) end
    F.SetJobDuty = function(onDuty) return B.setDuty(src, onDuty) end

    F.AddMoney = function(kind, amount, reason) return B.addMoney(src, kind, amount, reason) end
    F.RemoveMoney = function(kind, amount, reason) return B.removeMoney(src, kind, amount, reason) end
    F.SetMoney = function(kind, amount, reason) return B.setMoney(src, kind, amount, reason) end
    F.GetMoney = function(kind) return B.getMoney(src, kind) end
    F.SetCreditCard = function(cardNumber) F.SetMetaData('creditcard', cardNumber) end

    F.AddItem = function(item, amount, slot, info, reason) return (B.inv.add(src, item, amount, info, slot, reason)) end
    F.RemoveItem = function(item, amount, slot, reason) return (B.inv.remove(src, item, amount, nil, slot, reason)) end
    F.HasItem = function(items, amount) return B.inv.has(src, items, amount) end
    F.GetItemByName = function(item) return B.inv.byName(src, item)[1] end
    F.GetItemsByName = function(item) return B.inv.byName(src, item) end
    F.GetItemBySlot = function(slot) return B.inv.items(src)[tonumber(slot)] end
    F.GetCardSlot = function(cardNumber, cardType)
        for slot, it in pairs(B.inv.items(src)) do
            if it.name == (cardType or 'visa') and it.info.cardNumber == cardNumber then return slot end
        end
    end
    F.ClearInventory = function(keep) B.inv.clear(src, keep) end
    F.SetInventory = function(items) B.inv.setPlayerItems(src, items) end

    F.Save = function() W:SavePlayer(src) end
    F.Logout = function() W:LogoutPlayer(src) end
    F.AddMethod = function(name, handler)
        if type(name) ~= 'string' or handler == nil then return false end
        self.Functions[name] = handler
        self[name] = handler
        return true
    end
    F.AddField = function(name, data)
        if type(name) ~= 'string' then return false end
        self[name] = data
        return true
    end
    return B.finishPlayer(self, src)
end

function B.loadPlayer(src)
    if Players[src] then return end
    B.readBank(src)
    local pl = B.makePlayer(src)
    if not pl then return end
    Players[src] = pl
    QBCore.Players[src] = pl
    QBCore.PlayersByCitizenId[pl.PlayerData.citizenid] = pl
    -- A player with no connection has no state bag.
    if GetPlayerName(src) then Player(src).state:set('isLoggedIn', true, true) end
    TriggerEvent('QBCore:Server:PlayerLoaded', pl)
    TriggerClientEvent('qbx_core:bridge:shared', src, B.sharedForClient())
    TriggerClientEvent('qbx_core:bridge:loaded', src, pl.PlayerData)
    for name, cmd in pairs(QBCore.Commands.List) do
        if QBCore.Functions.HasPermission(src, cmd.permission) then
            TriggerClientEvent('chat:addSuggestion', src, '/' .. name, cmd.help, cmd.arguments)
        end
    end
end

function B.unloadPlayer(src, why)
    local pl = Players[src]
    if not pl then return end
    TriggerEvent('QBCore:Server:OnPlayerUnload', src)
    TriggerEvent('qbx_core:server:playerLoggedOut', src)
    if why == 'disconnect' then TriggerEvent('QBCore:Server:PlayerDropped', pl) end
    TriggerClientEvent('QBCore:Client:OnPlayerUnload', src)
    TriggerClientEvent('qbx_core:client:playerLoggedOut', src)
    if GetPlayerName(src) then Player(src).state:set('isLoggedIn', false, true) end
    QBCore.PlayersByCitizenId[pl.PlayerData.citizenid] = nil
    Players[src], QBCore.Players[src], Bank[src], Extra[src], Pushing[src] = nil, nil, nil, nil, nil
end

AddEventHandler('whip_core:player:loaded', function(e) B.loadPlayer(e.source) end)
AddEventHandler('whip_core:player:logout', function(e) B.unloadPlayer(e.source, e.why) end)
AddEventHandler('playerDropped', function() B.unloadPlayer(source, 'disconnect') end)

AddEventHandler('whip_core:inventory:changed', function(e) B.queueRefresh(e.source) end)
AddEventHandler('whip_core:player:died', function(e) B.queueRefresh(e.source) end)
AddEventHandler('whip_core:player:revived', function(e) B.queueRefresh(e.source) end)
AddEventHandler('whip_core:character:renamed', function(e) if e.source then B.queueRefresh(e.source) end end)

AddEventHandler('whip_core:bank:balanceChanged', function(e)
    for src, b in pairs(Bank) do
        if b.accountId and (b.accountId == e.accountId or b.accountId == e.fromAccountId or b.accountId == e.toAccountId) then
            CreateThread(function() B.readBank(src) B.refresh(src, e.message) end)
        end
    end
end)

for _, name in ipairs({ 'hired', 'fired', 'roleChanged', 'clockedOn', 'clockedOff' }) do
    AddEventHandler('whip_core:job:' .. name, function(e)
        if name == 'roleChanged' then B.Roles[e.jobId] = nil end
        if e.source then B.queueRefresh(e.source) end
    end)
end
for _, name in ipairs({ 'created', 'updated', 'deleted' }) do
    AddEventHandler('whip_core:job:' .. name, function(e)
        B.Roles[e.jobId] = nil
        B.rebuildShared()
        B.sendShared()
    end)
end

function B.ensureJob(key, def)
    local job, why = W:EnsureJob(key, { name = def.label or key, roles = Convert.rolesFromGrades(def.grades) })
    if not job then print(('^3[whip_bridge] job %s: %s^0'):format(key, tostring(why))) return false, why end
    B.Roles[job.jobId] = nil
    return true
end
