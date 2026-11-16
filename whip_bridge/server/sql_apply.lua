local B, W = Bridge, Whip.core
local SQL = B.sql
local Apply = {}
B.sqlApply = Apply

local function decode(v)
    if type(v) ~= 'string' then return v end
    local ok, out = pcall(json.decode, v)
    if ok then return out end
    return v
end

local function same(a, b) return json.encode(a) == json.encode(b) end

local function say(fmt, ...) print(('^3[whip_bridge:sql] ' .. fmt .. '^0'):format(...)) end

local function person(cid)
    local s = B.resolve(tostring(cid))
    if s then return s, true end
    local n = tonumber(cid)
    if n then return { charId = n }, false end
end

local NAMES = { firstname = true, lastname = true, birthdate = true, gender = true }

function Apply.players(op, old, new)
    if op ~= 'UPDATE' then
        say('%s on players ignored: whip makes and deletes characters (its character screen)', op)
        return
    end
    local who, online = person(new.citizenid)
    if not who then return end

    local om, nm = decode(old.money) or {}, decode(new.money) or {}
    for _, kind in ipairs({ 'cash', 'bank', 'crypto' }) do
        local want = tonumber(nm[kind])
        if want and not same(om[kind], nm[kind]) then
            if online then
                B.setMoney(who, kind, want, 'qb sql')
            else
                local pl = B.offlinePlayer(new.citizenid)
                if pl then pl.Functions.SetMoney(kind, want, 'qb sql') end
            end
        end
    end

    local oj, nj = decode(old.job) or {}, decode(new.job) or {}
    if type(nj) == 'table' and nj.name and (nj.name ~= oj.name or not same(oj.grade, nj.grade)) then
        local ok, why = B.setJob(who, nj.name, nj.grade and nj.grade.level or 0, { clockOn = false })
        if not ok then say('players job %s for %s: %s', nj.name, new.citizenid, tostring(why)) end
    end

    local og, ng = decode(old.gang) or {}, decode(new.gang) or {}
    if type(ng) == 'table' and ng.name and not same(og, ng) then
        B.setGang(who, ng.name, ng.grade and ng.grade.level or 0)
    end

    local omd, nmd = decode(old.metadata) or {}, decode(new.metadata) or {}
    if type(nmd) == 'table' then
        for k, v in pairs(nmd) do
            if not same(omd[k], v) and k ~= 'qb_gang' then
                local ok, why = W:SetPlayerMetadata(who, k, v)
                if not ok then say('players metadata %s: %s', k, tostring(why)) end
            end
        end
    end

    local oc, nc = decode(old.charinfo) or {}, decode(new.charinfo) or {}
    if type(nc) == 'table' then
        for k, v in pairs(nc) do
            if not same(oc[k], v) then
                if NAMES[k] then
                    say('players charinfo.%s ignored: names, birthdate and gender are whip\'s (/whip -> Players)', k)
                else
                    W:SetPlayerMetadata(who, k, v)
                end
            end
        end
    end
    if online then B.refresh(who, 'qb sql') end
end

local function vehicleOf(row)
    if row.whip_vehicle_id then return tonumber(row.whip_vehicle_id) end
    local v = row.plate and W:GetVehicle({ plate = row.plate })
    return v and v.vehicleId or nil
end

local function addVehicle(new)
    local src = B.resolve(tostring(new.citizenid))
    if not src then
        say('a car for citizenid %s was not made: whip makes an owned car only for someone online', tostring(new.citizenid))
        SQL.quiet('DELETE FROM player_vehicles WHERE id = ?', { new.id })
        return
    end
    local props = decode(new.mods)
    local data = { model = new.vehicle, plate = new.plate ~= '' and new.plate or nil, garage = new.garage,
        properties = type(props) == 'table' and next(props) and props or nil }
    local id, why = W:CreateOwnedVehicle(src, data)
    if not id and data.garage then
        data.garage = nil
        id, why = W:CreateOwnedVehicle(src, data)
    end
    if not id and data.plate then
        data.plate = nil
        id, why = W:CreateOwnedVehicle(src, data)
    end
    if not id then
        say('car %s for %s not made: %s', tostring(new.vehicle), tostring(new.citizenid), tostring(why))
        SQL.quiet('DELETE FROM player_vehicles WHERE id = ?', { new.id })
        return
    end
    local v = W:GetVehicle(id)
    SQL.quiet('UPDATE player_vehicles SET whip_vehicle_id = ?, plate = ? WHERE id = ?', { id, v and v.plate or new.plate, new.id })
end

local function updateVehicle(old, new)
    local id = vehicleOf(new) or vehicleOf(old)
    if not id then return end
    local function tell(what, ok, why) if not ok then say('car %s %s: %s', tostring(id), what, tostring(why)) end end

    if new.plate ~= old.plate and new.plate and new.plate ~= '' then tell('plate', W:SetVehiclePlate(id, new.plate)) end
    if new.citizenid ~= old.citizenid and new.citizenid then
        local to = B.resolve(tostring(new.citizenid))
        if to then tell('owner', W:TransferVehicle(id, to)) else say('car %s owner: whip hands a car only to someone online', tostring(id)) end
    end
    -- qb state: 0 out, 1 garaged, 2 impounded. DespawnVehicle is only for a car that's out; stored cars move with SetVehicleGarage.
    local os_, ns = tonumber(old.state), tonumber(new.state)
    local wasOut, isOut = os_ == 0, ns == 0
    if wasOut and not isOut then
        tell('stored', W:DespawnVehicle(id, { garage = new.garage }))
    elseif isOut and not wasOut then
        tell('taken out', W:RetrieveVehicle(id, new.garage))
    elseif not isOut and new.garage and new.garage ~= old.garage then
        tell('garage', W:SetVehicleGarage(id, new.garage))
    end
    if not same(decode(old.mods), decode(new.mods)) then
        local props = decode(new.mods)
        if type(props) == 'table' then tell('look', W:SetVehicleAppearance(id, props)) end
    end
    if tonumber(new.fuel) and tonumber(new.fuel) ~= tonumber(old.fuel) then
        tell('fuel', W:SetVehicleStat(id, 'fuel', tonumber(new.fuel), 'qb sql'))
    end
end

function Apply.player_vehicles(op, old, new)
    if op == 'INSERT' then return addVehicle(new) end
    if op == 'UPDATE' then return updateVehicle(old, new) end
    if op == 'DELETE' then
        local id = vehicleOf(old)
        if id then
            local ok, why = W:DeleteVehicle(id)
            if not ok then say('car %s delete: %s', tostring(id), tostring(why)) end
        end
    end
end

function Apply.player_groups(op, old, new)
    if op == 'DELETE' then
        local who = person(old.citizenid)
        if not who then return end
        if old.type == 'gang' then B.setGang(who, 'none', 0) else W:FirePlayer(who, old.group) end
        return
    end
    local who = person(new.citizenid)
    if not who then return end
    if new.type == 'gang' then
        B.setGang(who, new.group, tonumber(new.grade) or 0)
    else
        local ok, why = B.setJob(who, new.group, tonumber(new.grade) or 0, { clockOn = false })
        if not ok then say('player_groups %s for %s: %s', tostring(new.group), tostring(new.citizenid), tostring(why)) end
    end
end

local busy = false
function Apply.drain()
    if busy or not SQL.isReady() then return end
    busy = true
    local rows = MySQL.query.await('SELECT id, tbl, op, old_row, new_row FROM qbx_bridge_queue ORDER BY id LIMIT 50') or {}
    local done = {}
    for _, r in ipairs(rows) do
        local fn = Apply[r.tbl]
        if fn and SQL.managed[r.tbl] then
            local ok, err = pcall(fn, r.op, decode(r.old_row) or {}, decode(r.new_row) or {})
            if not ok then print(('^1[whip_bridge:sql] %s %s: %s^0'):format(r.op, r.tbl, tostring(err))) end
        end
        done[#done + 1] = r.id
    end
    if #done > 0 then
        MySQL.query.await(('DELETE FROM qbx_bridge_queue WHERE id IN (%s)'):format(table.concat(done, ',')))
        SQL.fill()
    end
    busy = false
end

CreateThread(function()
    while true do
        Wait(1000)
        local ok, err = pcall(Apply.drain)
        if not ok then busy = false print('^1[whip_bridge:sql] queue: ' .. tostring(err) .. '^0') end
    end
end)
