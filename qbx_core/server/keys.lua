-- Keys a player's game asks for are given only for a nearby car nobody else owns.
local B, W = Bridge, Whip.core
local QF = QBCore.Functions
local NEAR = 10.0

local function trim(plate) return plate and (tostring(plate):gsub('^%s*(.-)%s*$', '%1')) or nil end

local function entityByPlate(plate)
    plate = trim(plate)
    for _, v in ipairs(GetAllVehicles()) do
        if B.getPlate(v) == plate then return v end
    end
end

local function vehicleId(ref, src, isNetId)
    if ref == nil then return nil end
    if isNetId then ref = NetworkGetEntityFromNetworkId(ref) end
    local v
    if type(ref) == 'string' then
        v = W:GetVehicle({ plate = trim(ref) })
        if v then return v.vehicleId end
        ref = entityByPlate(ref)
        if not ref then return nil end
    end
    if type(ref) ~= 'number' or ref == 0 or not DoesEntityExist(ref) then return nil end
    v = W:GetVehicle({ entity = ref })
    if v then return v.vehicleId end
    return (W:AdoptVehicle({ entity = ref, player = src })) or nil
end

local function isNear(src, ref, isNetId)
    local veh = ref
    if isNetId then veh = NetworkGetEntityFromNetworkId(ref) end
    if type(veh) == 'string' then veh = entityByPlate(veh) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) <= NEAR
end

-- Someone else's owned car is not theirs to ask keys for.
local function mayClaim(src, id)
    local v = W:GetVehicle(id)
    if not v then return false end
    if v.session then return true end
    local charId = W:GetCharId(src)
    return v.owner and v.owner.charId == charId
end

local function giveById(src, id, skipNotification)
    local ok, why = W:GiveVehicleKey(src, id)
    if not ok and tostring(why):find('[Aa]lready') then ok = true end
    if ok and not skipNotification then QF.Notify(src, 'You got the keys', 'success') end
    return ok == true
end

function B.giveKeys(src, ref, skipNotification, isNetId)
    local id = vehicleId(ref, src, isNetId)
    if not id then return false end
    return giveById(src, id, skipNotification)
end

function B.removeKeys(src, ref, skipNotification)
    local id = vehicleId(ref, src)
    if not id then return false end
    local ok = W:RemoveVehicleKey(src, id)
    if ok and not skipNotification then QF.Notify(src, 'The keys were taken', 'primary') end
    return ok == true
end

function B.hasKeys(src, ref)
    local v = type(ref) == 'string' and W:GetVehicle({ plate = trim(ref) }) or (type(ref) == 'number' and W:GetVehicle({ entity = ref }))
    if not v then return false end
    return W:HasVehicleKey(src, v.vehicleId) == true
end

function B.setLockState(veh, state)
    local id = vehicleId(veh)
    if not id then return false end
    local locked = state == 2 or state == true or state == 'lock' or state == 'locked'
    return W:SetVehicleLocked(id, locked) == true
end

exports('GiveKeys', function(src, ref, skip) return B.giveKeys(src, ref, skip) end)
exports('RemoveKeys', function(src, ref, skip) return B.removeKeys(src, ref, skip) end)
exports('HasKeys', function(src, ref) return B.hasKeys(src, ref) end)
exports('IsPlayerNearVehicle', function(src, veh) return isNear(src, veh) end)
exports('SetLockState', function(veh, state) return B.setLockState(veh, state) end)

local function acquire(src, ref, isNetId)
    if not isNear(src, ref, isNetId) then return end
    local id = vehicleId(ref, src, isNetId)
    if id and mayClaim(src, id) then giveById(src, id) end
end

RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(ref)
    local src = source
    acquire(src, ref, type(ref) == 'number')
end)
RegisterNetEvent('qbx_vehiclekeys:server:tookKeys', function(netId) acquire(source, netId, true) end)
RegisterNetEvent('qbx_vehiclekeys:server:hotwiredVehicle', function(netId) acquire(source, netId, true) end)
RegisterNetEvent('qbx_core:bridge:keys:acquirePlate', function(plate) acquire(source, plate, false) end)

RegisterNetEvent('qb-vehiclekeys:server:GiveVehicleKeys', function(receiver, plate)
    local src = source
    receiver = tonumber(receiver)
    if not receiver or not B.Players[receiver] then return end
    if not B.hasKeys(src, plate) then QF.Notify(src, 'You don\'t have the keys', 'error') return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(receiver))) > NEAR then return end
    local id = vehicleId(plate, src)
    if not id then return end
    if W:GiveVehicleKey(receiver, id, { spare = true }) then
        QF.Notify(src, 'You handed over the keys', 'success')
        QF.Notify(receiver, 'You got the keys', 'success')
    end
end)

RegisterNetEvent('qb-vehiclekeys:server:RemoveVehicleKeys', function(plate) B.removeKeys(source, plate, true) end)
RegisterNetEvent('qb-vehiclekeys:server:removeKeys', function(ref) B.removeKeys(source, ref, true) end)

RegisterNetEvent('qb-vehiclekeys:server:breakLockpick', function(itemName)
    if itemName ~= 'lockpick' and itemName ~= 'advancedlockpick' then return end
    B.inv.remove(source, itemName, 1, nil, nil, 'lockpick broke')
end)

RegisterNetEvent('qb-vehiclekeys:server:setVehLockState', function(netId, state)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not B.hasKeys(src, veh) then return end
    B.setLockState(veh, state)
end)
