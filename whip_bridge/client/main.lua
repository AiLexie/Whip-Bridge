local W = Whip.core

QBCore = {
    PlayerData = {},
    Shared = { Items = {}, Jobs = {}, Gangs = BridgeConfig.Gangs, Vehicles = {}, VehicleHashes = {}, Weapons = {},
        Locations = BridgeConfig.Locations },
    Functions = {},
    Config = {},
    ClientCallbacks = {},
}
Convert.sharedHelpers(QBCore.Shared)
ClientBridge = {}
local QF = QBCore.Functions

local itemsAt = -10000
function ClientBridge.refreshItems()
    if GetGameTimer() - itemsAt < 5000 then return end
    local items = {}
    for key, def in pairs(BridgeConfig.Items) do items[key] = Convert.item(key, Convert.toWhipItem(def)) end
    if GetResourceState('whip_core') == 'started' then
        local ok, defs = pcall(function() return W:GetItemDefs() end)
        for key, def in pairs(ok and defs or {}) do items[key] = Convert.item(key, def) end
        itemsAt = GetGameTimer()
    end
    QBCore.Shared.Items = items
end

local function takeShared(shared)
    for k, v in pairs(shared or {}) do QBCore.Shared[k] = v end
end
takeShared(GlobalState.qbxShared)
ClientBridge.refreshItems()
AddStateBagChangeHandler('qbxShared', 'global', function(_, _, value) takeShared(value) end)

QF.GetPlayerData = function(cb)
    if cb == nil then return QBCore.PlayerData end
    cb(QBCore.PlayerData)
end

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) QBCore.PlayerData = data end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() QBCore.PlayerData = {} end)

RegisterNetEvent('qbx_core:bridge:shared', function(shared)
    for k, v in pairs(shared or {}) do QBCore.Shared[k] = v end
end)

RegisterNetEvent('QBCore:Client:OnSharedUpdate', function(key, name, value)
    if QBCore.Shared[key] then QBCore.Shared[key][name] = value end
end)
RegisterNetEvent('QBCore:Client:OnSharedUpdateMultiple', function(key, values)
    if not QBCore.Shared[key] then return end
    for name, value in pairs(values or {}) do QBCore.Shared[key][name] = value end
end)

-- Wait until whip has the player in the world before firing qb's loaded events.
RegisterNetEvent('qbx_core:bridge:loaded', function(data)
    QBCore.PlayerData = data
    while not W:IsPlayerLoaded() do Wait(250) end
    TriggerEvent('QBCore:Player:SetPlayerData', data)
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
end)

CreateThread(function()
    if Whip.ready() and W:IsPlayerLoaded() then TriggerServerEvent('qbx_core:bridge:hello') end
end)

local Pending, nextId = {}, 0
QF.TriggerCallback = function(name, cb, ...)
    nextId = nextId + 1
    if cb == nil or cb == false then
        local p = promise.new()
        Pending[nextId] = function(...) p:resolve({ ... }) end
        TriggerServerEvent('qbx_core:bridge:cb', name, nextId, ...)
        return table.unpack(Citizen.Await(p))
    end
    Pending[nextId] = cb
    TriggerServerEvent('qbx_core:bridge:cb', name, nextId, ...)
end
QF.AwaitCallback = function(name, ...) return QF.TriggerCallback(name, nil, ...) end

RegisterNetEvent('qbx_core:bridge:cbr', function(id, ...)
    local cb = Pending[id]
    Pending[id] = nil
    if cb ~= nil then cb(...) end
end)

QF.CreateClientCallback = function(name, cb) QBCore.ClientCallbacks[name] = cb end
RegisterNetEvent('qbx_core:bridge:ccb', function(name, id, ...)
    local cb = QBCore.ClientCallbacks[name]
    if cb == nil then return end
    cb(function(...) TriggerServerEvent('qbx_core:bridge:ccbr', id, ...) end, ...)
end)

QF.Notify = function(text, kind, length)
    if type(text) == 'table' then text = text.text or text.caption end
    W:Notify(tostring(text), Convert.notifyType(kind), length)
end
RegisterNetEvent('QBCore:Notify', function(text, kind, length) QF.Notify(text, kind, length) end)

QF.Progressbar = function(_, label, duration, useWhileDead, canCancel, dc, anim, prop, _, onFinish, onCancel)
    CreateThread(function()
        local opts = { label = label, duration = duration, canCancel = canCancel == true, cancelOnDeath = not useWhileDead }
        if dc then
            opts.disable = { move = dc.disableMovement == true, car = dc.disableCarMovement == true,
                combat = dc.disableCombat == true }
        end
        if anim and anim.task then
            opts.anim = { scenario = anim.task }
        elseif anim and anim.animDict then
            opts.anim = { dict = anim.animDict, clip = anim.anim, flag = anim.flags }
        end
        if prop and prop.model then
            opts.prop = { model = prop.model, bone = prop.bone, offset = prop.coords, rot = prop.rotation }
        end
        local done = W:Progress(opts)
        if done then
            if onFinish ~= nil then onFinish() end
        elseif onCancel ~= nil then
            onCancel()
        end
    end)
end

QF.DrawText = function(x, y, width, height, scale, r, g, b, a, text)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x - width / 2, y - height / 2 + 0.005)
end

QF.DrawText3D = function(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

QF.HasItem = function(items, amount)
    for item, n in pairs(Convert.itemList(items, amount)) do
        if not W:HasItem(item, n) then return false end
    end
    return true
end

QF.GetName = function() return QBCore.PlayerData.charinfo and (QBCore.PlayerData.charinfo.firstname .. ' ' .. QBCore.PlayerData.charinfo.lastname) end

QF.GetCoords = function(entity)
    local c = GetEntityCoords(entity)
    return vector4(c.x, c.y, c.z, GetEntityHeading(entity))
end

QF.GetPlate = function(vehicle)
    if vehicle == 0 then return nil end
    return (GetVehicleNumberPlateText(vehicle):gsub('^%s*(.-)%s*$', '%1'))
end

QF.GetVehicleLabel = function(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
end

local function toVec3(c)
    if not c then return GetEntityCoords(PlayerPedId()) end
    return vector3(c.x, c.y, c.z)
end

local function closest(list, coords, skip)
    coords = toVec3(coords)
    local best, bestDist = -1, -1
    for _, ent in ipairs(list) do
        if ent ~= skip then
            local d = #(coords - GetEntityCoords(ent))
            if bestDist == -1 or d < bestDist then best, bestDist = ent, d end
        end
    end
    return best, bestDist
end

QF.GetPlayers = function() return GetActivePlayers() end
QF.GetPeds = function(ignore)
    local out, skip = {}, {}
    for _, p in ipairs(ignore or {}) do skip[p] = true end
    for _, ped in ipairs(GetGamePool('CPed')) do if not skip[ped] then out[#out + 1] = ped end end
    return out
end
QF.GetVehicles = function() return GetGamePool('CVehicle') end
QF.GetObjects = function() return GetGamePool('CObject') end

QF.GetPlayersFromCoords = function(coords, distance)
    coords = toVec3(coords)
    local out = {}
    for _, p in ipairs(GetActivePlayers()) do
        if #(coords - GetEntityCoords(GetPlayerPed(p))) <= (distance or 5.0) then out[#out + 1] = p end
    end
    return out
end

QF.GetClosestPlayer = function(coords)
    local me = PlayerId()
    local origin = toVec3(coords)
    local best, bestDist = -1, -1
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= me then
            local d = #(origin - GetEntityCoords(GetPlayerPed(p)))
            if bestDist == -1 or d < bestDist then best, bestDist = p, d end
        end
    end
    return best, bestDist
end

QF.GetClosestVehicle = function(coords) return closest(GetGamePool('CVehicle'), coords) end
QF.GetClosestObject = function(coords) return closest(GetGamePool('CObject'), coords) end
QF.GetClosestPed = function(coords, ignore)
    local list = {}
    local skip = {}
    for _, p in ipairs(type(ignore) == 'table' and ignore or {}) do skip[p] = true end
    for _, ped in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(ped) and not skip[ped] then list[#list + 1] = ped end
    end
    return closest(list, coords)
end

QF.GetClosestBone = function(entity, list)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local bone, coords, distance
    for _, element in pairs(list) do
        local id = type(element) == 'table' and element.id or element
        local boneCoords = GetWorldPositionOfEntityBone(entity, id)
        local d = #(playerCoords - boneCoords)
        if not distance or d < distance then bone, coords, distance = element, boneCoords, d end
    end
    if not bone then
        bone = { id = GetEntityBoneIndexByName(entity, 'bodyshell'), type = 'remains', name = 'bodyshell' }
        coords = GetWorldPositionOfEntityBone(entity, bone.id)
        distance = #(coords - playerCoords)
    end
    return bone, coords, distance
end

QF.GetBoneDistance = function(entity, boneType, boneIndex)
    local bone = boneType == 1 and GetPedBoneIndex(entity, boneIndex) or GetEntityBoneIndexByName(entity, boneIndex)
    return #(GetWorldPositionOfEntityBone(entity, bone) - GetEntityCoords(PlayerPedId()))
end

QF.AttachProp = function(ped, model, boneId, x, y, z, xR, yR, zR, vertex)
    local hash = type(model) == 'string' and joaat(model) or model
    QF.LoadModel(hash)
    local c = GetEntityCoords(ped)
    local prop = CreateObject(hash, c.x, c.y, c.z, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, boneId), x, y, z, xR, yR, zR, true, true, false, true,
        not vertex and 2 or 0, true)
    SetModelAsNoLongerNeeded(hash)
    return prop
end

QF.GetCardinalDirection = function(entity)
    entity = DoesEntityExist(entity) and entity or PlayerPedId()
    local h = GetEntityHeading(entity)
    if h >= 315 or h < 45 then return 'North' end
    if h < 135 then return 'West' end
    if h < 225 then return 'South' end
    return 'East'
end

QF.GetCurrentTime = function()
    local hour, minute = GetClockHours(), GetClockMinutes()
    local ampm = hour >= 12 and 'PM' or 'AM'
    local h12 = hour % 12
    if h12 == 0 then h12 = 12 end
    return { min = minute, hour = h12, ampm = ampm }
end

QF.GetGroundZCoord = function(coords)
    if not coords then return nil end
    local ok, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    if ok then return vector3(coords.x, coords.y, z) end
    return coords
end

QF.GetGroundHash = function(entity)
    local c = GetEntityCoords(entity)
    local ray = StartShapeTestRay(c.x, c.y, c.z + 4, c.x, c.y, c.z - 2.0, 1, 0, 7)
    local _, _, _, _, groundHash = GetShapeTestResultIncludingMaterial(ray)
    return groundHash
end

QF.GetStreetNametAtCoords = function(coords)
    local main, cross = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return { main = GetStreetNameFromHashKey(main), cross = GetStreetNameFromHashKey(cross) }
end
QF.GetStreetNameAtCoords = QF.GetStreetNametAtCoords

QF.GetZoneAtCoords = function(coords)
    return GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
end

local function noGloves(ped)
    local arms = GetPedDrawableVariation(ped, 3)
    local male = GetEntityModel(ped) == joaat('mp_m_freemode_01')
    local list = male and BridgeConfig.NoGloves.male or BridgeConfig.NoGloves.female
    return list[arms] == true
end
QF.IsWearingGloves = function() return not noGloves(PlayerPedId()) end
ClientBridge.noGloves = noGloves

QF.LoadModel = function(model)
    model = type(model) == 'string' and joaat(model) or model
    if HasModelLoaded(model) then return end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
end

QF.RequestAnimDict = function(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
end

QF.LoadAnimSet = function(set)
    if HasAnimSetLoaded(set) then return end
    RequestAnimSet(set)
    while not HasAnimSetLoaded(set) do Wait(0) end
end

QF.LoadParticleDictionary = function(dict)
    if HasNamedPtfxAssetLoaded(dict) then return end
    RequestNamedPtfxAsset(dict)
    while not HasNamedPtfxAssetLoaded(dict) do Wait(0) end
end

QF.StartParticleAtCoord = function(dict, name, looped, coords, rot, scale, alpha, color, duration)
    coords = coords and toVec3(coords) or GetEntityCoords(PlayerPedId())
    QF.LoadParticleDictionary(dict)
    UseParticleFxAssetNextCall(dict)
    SetPtfxAssetNextCall(dict)
    local handle
    rot = rot or vector3(0.0, 0.0, 0.0)
    if looped then
        handle = StartParticleFxLoopedAtCoord(name, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false, false)
        if color then SetParticleFxLoopedColour(handle, color.r, color.g, color.b, false) end
        SetParticleFxLoopedAlpha(handle, alpha or 10.0)
        if duration then SetTimeout(duration, function() StopParticleFxLooped(handle, false) end) end
    else
        SetParticleFxNonLoopedAlpha(alpha or 10.0)
        if color then SetParticleFxNonLoopedColour(color.r, color.g, color.b) end
        StartParticleFxNonLoopedAtCoord(name, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
    end
    return handle
end

QF.StartParticleOnEntity = function(dict, name, looped, entity, bone, offset, rot, scale, alpha, color, evolution, duration)
    QF.LoadParticleDictionary(dict)
    UseParticleFxAssetNextCall(dict)
    offset = offset or vector3(0.0, 0.0, 0.0)
    rot = rot or vector3(0.0, 0.0, 0.0)
    local handle
    local boneId = bone and GetPedBoneIndex(entity, bone) or 0
    if looped then
        if bone then
            handle = StartParticleFxLoopedOnEntityBone(name, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, boneId, scale or 1.0, false, false, false)
        else
            handle = StartParticleFxLoopedOnEntity(name, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
        end
        if evolution then SetParticleFxLoopedEvolution(handle, evolution.name, evolution.amount, false) end
        if color then SetParticleFxLoopedColour(handle, color.r, color.g, color.b, false) end
        SetParticleFxLoopedAlpha(handle, alpha or 10.0)
        if duration then SetTimeout(duration, function() StopParticleFxLooped(handle, false) end) end
    else
        SetParticleFxNonLoopedAlpha(alpha or 10.0)
        if color then SetParticleFxNonLoopedColour(color.r, color.g, color.b) end
        if bone then
            StartParticleFxNonLoopedOnPedBone(name, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, boneId, scale or 1.0, false, false, false)
        else
            StartParticleFxNonLoopedOnEntity(name, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
        end
    end
    return handle
end

QF.PlayAnim = function(dict, anim, blend, flag, duration)
    QF.RequestAnimDict(dict)
    TaskPlayAnim(PlayerPedId(), dict, anim, blend or 8.0, blend or 8.0, duration or -1, flag or 0, 0.0, false, false, false)
end

QF.LookAtEntity = function(entity, timeout, speed)
    local ped = PlayerPedId()
    local c = GetEntityCoords(entity)
    TaskTurnPedToFaceCoord(ped, c.x, c.y, c.z, timeout or 2000)
    local t = GetGameTimer()
    while GetGameTimer() - t < (timeout or 2000) do
        local d = GetEntityCoords(entity) - GetEntityCoords(ped)
        local want = math.deg(math.atan(d.y, d.x)) - 90.0
        if math.abs((GetEntityHeading(ped) - want + 180) % 360 - 180) < 10 then break end
        Wait(0)
    end
    ClearPedTasks(ped)
end

QF.SpawnVehicle = function(model, cb, coords, isnetworked, teleportInto)
    local ped = PlayerPedId()
    model = type(model) == 'string' and joaat(model) or model
    if coords then
        coords = vector4(coords.x, coords.y, coords.z, coords.w or GetEntityHeading(ped))
    else
        coords = QF.GetCoords(ped)
    end
    QF.LoadModel(model)
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, isnetworked ~= false, false)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetModelAsNoLongerNeeded(model)
    if teleportInto then TaskWarpPedIntoVehicle(ped, veh, -1) end
    if cb ~= nil then cb(veh) end
    return veh
end

QF.DeleteVehicle = function(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

QF.SpawnClear = function(coords, radius)
    coords = toVec3(coords)
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if #(coords - GetEntityCoords(v)) <= (radius or 5.0) then return false end
    end
    return true
end

-- whip reads a bare number as a vehicleId, so the entity has to go in { entity = }.
QF.GetVehicleProperties = function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end
    return W:GetVehicleProperties({ entity = vehicle })
end
QF.SetVehicleProperties = function(vehicle, props)
    if not vehicle or not DoesEntityExist(vehicle) or not props then return end
    W:SetVehicleProperties({ entity = vehicle }, props)
end

RegisterNetEvent('QBCore:Command:TeleportToPlayer', function(coords)
    SetPedCoordsKeepVehicle(PlayerPedId(), coords.x, coords.y, coords.z)
end)
RegisterNetEvent('QBCore:Command:TeleportToCoords', function(x, y, z, h)
    SetPedCoordsKeepVehicle(PlayerPedId(), x, y, z)
    if h then SetEntityHeading(PlayerPedId(), h) end
end)
RegisterNetEvent('QBCore:Command:GoToMarker', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then QF.Notify('No waypoint set', 'error') return end
    local c = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    for z = 1000.0, 0.0, -25.0 do
        SetPedCoordsKeepVehicle(ped, c.x, c.y, z)
        local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, z, false)
        if ok then SetPedCoordsKeepVehicle(ped, c.x, c.y, gz) return end
        Wait(10)
    end
end)
RegisterNetEvent('QBCore:Client:PvpHasToggled', function(pvp)
    SetCanAttackFriendly(PlayerPedId(), pvp, false)
    NetworkSetFriendlyFireOption(pvp)
end)

local function hasGroup(filter, primaryOnly)
    local d = QBCore.PlayerData
    if not d.job then return false end
    local want = Convert.groupFilter(filter)
    if want[d.job.name] and d.job.grade.level >= want[d.job.name] then return d.job.name, d.job.grade.level end
    if d.gang and want[d.gang.name] and d.gang.grade.level >= want[d.gang.name] then return d.gang.name, d.gang.grade.level end
    if primaryOnly then return false end
    for _, j in pairs(W:GetPlayerJobs() or {}) do
        if want[j.key] then return j.key, 0 end
    end
    return false
end

exports('GetCoreObject', function() ClientBridge.refreshItems() return QBCore end)
exports('GetShared', function(namespace, item)
    ClientBridge.refreshItems()
    if not namespace then return QBCore.Shared end
    local ns = QBCore.Shared[namespace]
    if ns == nil then return nil end
    if item ~= nil then return ns[item] end
    return ns
end)
exports('GetPlayerData', function() return QBCore.PlayerData end)
exports('Notify', QF.Notify)
exports('HasPrimaryGroup', function(filter) return hasGroup(filter, true) end)
exports('HasGroup', function(filter) return hasGroup(filter, false) end)
exports('GetGroups', function()
    local d = QBCore.PlayerData
    local out = {}
    for _, j in pairs(W:GetPlayerJobs() or {}) do out[j.key] = 0 end
    if d.job and d.job.name ~= 'unemployed' then out[d.job.name] = d.job.grade.level end
    if d.gang and d.gang.name ~= 'none' then out[d.gang.name] = d.gang.grade.level end
    return out
end)
exports('GetJobs', function() return QBCore.Shared.Jobs end)
exports('GetJob', function(name) return QBCore.Shared.Jobs[name] end)
exports('GetGangs', function() return QBCore.Shared.Gangs end)
exports('GetGang', function(name) return QBCore.Shared.Gangs[name] end)
exports('GetLocations', function() return QBCore.Shared.Locations end)
exports('GetWeapons', function() return QBCore.Shared.Weapons end)
exports('GetVehiclesByName', function(name)
    if name then return QBCore.Shared.Vehicles[name] end
    return QBCore.Shared.Vehicles
end)
exports('GetVehiclesByHash', function(hash)
    if hash then return QBCore.Shared.VehicleHashes[hash] end
    return QBCore.Shared.VehicleHashes
end)
exports('GetVehiclesByCategory', function()
    local out = {}
    for _, v in pairs(QBCore.Shared.Vehicles) do
        out[v.category] = out[v.category] or {}
        out[v.category][#out[v.category] + 1] = v
    end
    return out
end)
