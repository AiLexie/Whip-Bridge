-- Offline money only touches the bank: cash lives in pockets that load with the player.
local B, W = Bridge, Whip.core

function B.offlinePlayer(cid)
    local charId = tonumber(cid)
    if not charId then return nil end
    local online = B.resolve(tostring(charId))
    if online then return QBCore.Functions.GetPlayer(online) end

    local who = { charId = charId }
    local names = W:GetCharacterNames({ charId }) or {}
    local fullName = names[charId]
    if not fullName then return nil end
    local first, last = fullName:match('^(%S+)%s*(.*)$')
    local meta = Convert.metadata(W:GetPlayerMetadata(who) or {}, nil)
    local acct = W:GetDefaultBankAccount(who)
    local bank = acct and W:GetBalance({ accountId = acct.accountId }) or 0

    local self = { Offline = true, Functions = {} }
    local function build()
        return {
            source = nil,
            citizenid = tostring(charId),
            cid = charId,
            money = { cash = 0, bank = tonumber(bank) or 0, crypto = tonumber(meta.crypto) or 0 },
            charinfo = Convert.charinfo({ firstName = first, lastName = last }, meta),
            job = B.jobOf(who),
            gang = type(meta.qb_gang) == 'table' and meta.qb_gang or Convert.NO_GANG,
            metadata = meta,
            items = {},
        }
    end
    self.PlayerData = build()
    local F = self.Functions

    F.GetPlayerData = function() return self.PlayerData end
    F.UpdateClient = function() end
    F.UpdatePlayerData = F.UpdateClient
    F.GetName = function() return fullName end
    F.Notify = function() end
    F.SetMetaData = function(key, val)
        local ok = W:SetPlayerMetadata(who, key, val)
        if ok then meta[key] = val self.PlayerData = build() end
        return ok == true
    end
    F.SetMetadata = F.SetMetaData
    F.GetMetaData = function(key) if key == nil then return meta end return meta[key] end
    F.GetMetadata = F.GetMetaData
    F.SetPlayerData = function(key, val)
        if key == 'metadata' and type(val) == 'table' then
            for k, v in pairs(val) do F.SetMetaData(k, v) end
        else
            self.PlayerData[key] = val
        end
    end
    F.AddRep = function(rep, amount)
        local r = meta.rep or {}
        r[rep] = (r[rep] or 0) + (tonumber(amount) or 0)
        F.SetMetaData('rep', r)
    end
    F.RemoveRep = function(rep, amount)
        local r = meta.rep or {}
        r[rep] = math.max(0, (r[rep] or 0) - (tonumber(amount) or 0))
        F.SetMetaData('rep', r)
    end
    F.GetRep = function(rep) return (meta.rep or {})[rep] or 0 end
    F.AddJobReputation = function(amount)
        local r = meta.jobrep or {}
        local job = self.PlayerData.job.name
        r[job] = (r[job] or 0) + (tonumber(amount) or 0)
        F.SetMetaData('jobrep', r)
    end

    F.SetJob = function(job, grade)
        local ok = B.setJob(who, job, grade)
        self.PlayerData = build()
        return ok == true
    end
    F.SetGang = function(gang, grade)
        local entry = B.gangEntry(gang, grade)
        if not entry then return false end
        return F.SetMetaData('qb_gang', gang ~= 'none' and entry or false)
    end
    F.SetJobDuty = function() return false end

    F.GetMoney = function(kind) return self.PlayerData.money[kind] or 0 end
    F.AddMoney = function(kind, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount < 0 then return false end
        if kind == 'crypto' then return F.SetMetaData('crypto', F.GetMoney('crypto') + amount) end
        if kind ~= 'bank' then return false end
        local ok = W:PayPlayer(who, amount, { method = 'bank', reason = reason or 'qb offline' })
        if ok then bank = bank + amount self.PlayerData = build() end
        return ok ~= false and ok ~= nil
    end
    F.RemoveMoney = function(kind, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount < 0 then return false end
        if kind == 'crypto' then
            local have = F.GetMoney('crypto')
            if have < amount then return false end
            return F.SetMetaData('crypto', have - amount)
        end
        if kind ~= 'bank' or not acct then return false end
        local ok = W:BankSystemWithdraw(acct.accountId, amount, { reason = reason or 'qb offline', actorCharId = charId })
        if ok then bank = bank - amount self.PlayerData = build() end
        return ok == true
    end
    F.SetMoney = function(kind, amount, reason)
        local d = math.floor(tonumber(amount) or 0) - F.GetMoney(kind)
        if d > 0 then return F.AddMoney(kind, d, reason) end
        if d < 0 then return F.RemoveMoney(kind, -d, reason) end
        return true
    end

    F.AddItem = function(item, amount, _, info, reason)
        return W:GiveOnLogin(who, item, amount or 1, info, { reason = reason or 'qb offline' }) ~= false
    end
    F.RemoveItem = function() return false end
    F.HasItem = function() return false end
    F.GetItemByName = function() return nil end
    F.GetItemsByName = function() return {} end
    F.GetItemBySlot = function() return nil end
    F.ClearInventory = function() end
    F.SetInventory = function() end
    F.SetCreditCard = function(card) F.SetMetaData('creditcard', card) end

    F.Save = function() end
    F.Logout = function() end
    F.AddMethod = function(name, handler) self.Functions[name] = handler self[name] = handler return true end
    F.AddField = function(name, data) self[name] = data return true end
    return B.finishPlayer(self, -1)
end

function B.playerByLicense(license)
    local p = W:GetPlayer({ identifier = license })
    return p and QBCore.Functions.GetPlayer(p.source) or nil
end
