local W = Whip.core
local QF = QBCore.Functions
local NoLock = {}

local function trim(plate) return plate and (tostring(plate):gsub('^%s*(.-)%s*$', '%1')) or nil end

local function vehicleByPlate(plate)
    plate = trim(plate)
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if trim(GetVehicleNumberPlateText(v)) == plate then return v end
    end
end

local function hasKeys(ref)
    local veh = type(ref) == 'string' and vehicleByPlate(ref) or ref
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    return W:HasVehicleKey({ entity = veh }) == true
end

local function nearestVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local v, d = QF.GetClosestVehicle()
    if v ~= -1 and d < 5.0 then return v end
end

exports('HasKeys', hasKeys)
exports('GiveKeys', function(id, plate)
    TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', id, plate or QF.GetPlate(nearestVehicle() or 0))
end)
exports('addNoLockVehicles', function(model) NoLock[model] = true end)
exports('removeNoLockVehicles', function(model) NoLock[model] = nil end)
exports('GetNoLockVehicles', function() return NoLock end)

RegisterNetEvent('vehiclekeys:client:SetOwner', function(plate) TriggerServerEvent('qbx_core:bridge:keys:acquirePlate', trim(plate)) end)
RegisterNetEvent('qb-vehiclekeys:client:AddKeys', function(plate) TriggerServerEvent('qbx_core:bridge:keys:acquirePlate', trim(plate)) end)
RegisterNetEvent('qb-vehiclekeys:client:RemoveKeys', function(plate) TriggerServerEvent('qb-vehiclekeys:server:RemoveVehicleKeys', trim(plate)) end)

RegisterNetEvent('qb-vehiclekeys:client:GiveKeys', function(id)
    local veh = nearestVehicle()
    if not veh then QF.Notify('No vehicle nearby', 'error') return end
    local target = tonumber(id)
    if not target then
        local p, d = QF.GetClosestPlayer()
        if p == -1 or d > 3.0 then QF.Notify('Nobody nearby', 'error') return end
        target = GetPlayerServerId(p)
    end
    TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', target, QF.GetPlate(veh))
end)

RegisterNetEvent('qb-vehiclekeys:client:ToggleEngine', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() then return end
    if not hasKeys(veh) then QF.Notify('You don\'t have the keys', 'error') return end
    SetVehicleEngineOn(veh, not GetIsVehicleEngineRunning(veh), false, true)
end)

RegisterNetEvent('qbx_vehiclekeys:client:OnLostKeys', function() end)
