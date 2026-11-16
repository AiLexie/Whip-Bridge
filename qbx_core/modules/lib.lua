qbx = qbx or {}
local isServer = IsDuplicityVersion()

qbx.string = {}
qbx.math = {}
qbx.table = {}
qbx.array = {}

local cfg = BridgeConfig or (function()
    local env = setmetatable({}, { __index = _G })
    local src = LoadResourceFile('qbx_core', 'shared/config.lua')
    if src then load(src, '@qbx_core/shared/config.lua', 't', env)() end
    return env.BridgeConfig or {}
end)()
qbx.armsWithoutGloves = cfg.NoGloves or { male = {}, female = {} }
qbx.duffelbagIndexes = cfg.DuffelBags or {}

function qbx.string.trim(str) return (str:gsub('^%s*(.-)%s*$', '%1')) end
function qbx.string.capitalize(str) return (str:gsub('^%l', string.upper)) end

function qbx.math.round(num, decimalPlaces)
    if not decimalPlaces then return math.floor(num + 0.5) end
    local m = 10 ^ decimalPlaces
    return math.floor(num * m + 0.5) / m
end
function qbx.math.isFinite(value) return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge end

function qbx.table.size(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end
function qbx.table.mapBySubfield(tble, subfield)
    local out = {}
    for _, v in pairs(tble) do
        local key = v[subfield]
        if key ~= nil then
            out[key] = out[key] or {}
            out[key][#out[key] + 1] = v
        end
    end
    return out
end

function qbx.array.contains(arr, val)
    for i = 1, #arr do if arr[i] == val then return true end end
    return false
end

function qbx.getVehiclePlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return qbx.string.trim(GetVehicleNumberPlateText(vehicle))
end

-- '1' is a digit, 'A' a letter, '.' either, '^' escapes the next character; anything else is literal.
function qbx.generateRandomPlate(pattern)
    pattern = pattern or '11AAA111'
    local letters, digits = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '0123456789'
    local out, escape = {}, false
    for c in pattern:gmatch('.') do
        if escape then out[#out + 1] = c escape = false
        elseif c == '^' then escape = true
        else
            local pool = (c == '1' and digits) or (c == 'A' and letters) or (c == '.' and (letters .. digits)) or nil
            if pool then
                local i = math.random(1, #pool)
                out[#out + 1] = pool:sub(i, i)
            else
                out[#out + 1] = c
            end
        end
    end
    return table.concat(out):upper()
end

function qbx.getCardinalDirection(entity)
    local h = GetEntityHeading(entity)
    if h >= 315 or h < 45 then return 'North' end
    if h < 135 then return 'West' end
    if h < 225 then return 'South' end
    return 'East'
end

if isServer then
    -- qbx.spawnVehicle({ model, spawnSource = ped|coords, warp?, props?, bucket? }) -> netId, veh
    function qbx.spawnVehicle(params)
        local src = params.spawnSource
        local coords, ped
        if type(src) == 'number' then
            ped = src
            local c = GetEntityCoords(ped)
            coords = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
        else
            coords = vector4(src.x, src.y, src.z, src.w or 0.0)
        end
        local owner = ped and NetworkGetEntityOwner(ped) or nil
        local veh, netId = exports.qbx_core:BridgeSpawnVehicle(owner, params.model, coords, false, params.props)
        if not veh then error('qbx.spawnVehicle: could not spawn ' .. tostring(params.model)) end
        if params.bucket then SetEntityRoutingBucket(veh, params.bucket) end
        local warpPed = type(params.warp) == 'number' and params.warp or (params.warp == true and ped) or nil
        if warpPed then
            for _ = 1, 20 do
                SetPedIntoVehicle(warpPed, veh, -1)
                Wait(50)
                if GetVehiclePedIsIn(warpPed, false) == veh then break end
            end
        end
        return netId, veh
    end

    function qbx.deleteVehicle(vehicle) return exports.qbx_core:DeleteVehicle(vehicle) end
    return
end

function qbx.drawText2d(params)
    local coords = params.coords or vec2(0.5, 0.5)
    local color = params.color or vec4(255, 255, 255, 255)
    SetTextScale(params.scale or 0.35, params.scale or 0.35)
    SetTextFont(params.font or 4)
    SetTextColour(math.floor(color.x), math.floor(color.y), math.floor(color.z), math.floor(color.w))
    if params.enableDropShadow then SetTextDropShadow() end
    if params.enableOutline then SetTextOutline() end
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(params.text)
    EndTextCommandDisplayText(coords.x - (params.width or 1.0) / 2, coords.y - (params.height or 1.0) / 2 + 0.005)
end

function qbx.drawText3d(params)
    local color = params.color or vec4(255, 255, 255, 255)
    SetTextScale(params.scale or 0.35, params.scale or 0.35)
    SetTextFont(params.font or 4)
    SetTextColour(math.floor(color.x), math.floor(color.y), math.floor(color.z), math.floor(color.w))
    if params.enableDropShadow then SetTextDropShadow() end
    if params.enableOutline then SetTextOutline() end
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(params.text)
    SetDrawOrigin(params.coords.x, params.coords.y, params.coords.z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

function qbx.getEntityAndNetIdFromBagName(bagName)
    local netId = tonumber((bagName:gsub('entity:', '')))
    if not netId then return 0, 0 end
    local t = GetGameTimer()
    while not NetworkDoesEntityExistWithNetworkId(netId) do
        if GetGameTimer() - t > 10000 then return 0, netId end
        Wait(0)
    end
    return NetworkGetEntityFromNetworkId(netId), netId
end

function qbx.entityStateHandler(keyFilter, cb)
    return AddStateBagChangeHandler(keyFilter, '', function(bagName, _, value)
        local entity, netId = qbx.getEntityAndNetIdFromBagName(bagName)
        if entity ~= 0 then cb(entity, netId, value, bagName) end
    end)
end

function qbx.deleteVehicle(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
    return not DoesEntityExist(vehicle)
end

function qbx.getVehicleDisplayName(vehicle) return GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))) end
function qbx.getVehicleMakeName(vehicle) return GetLabelText(GetMakeNameFromVehicleModel(GetEntityModel(vehicle))) end
function qbx.getVehicleModName(vehicle, modType, modIndex) return GetLabelText(GetModTextLabel(vehicle, modType, modIndex)) end
function qbx.getVehicleLiveryName(vehicle, liveryIndex) return GetLabelText(GetLiveryName(vehicle, liveryIndex)) end

function qbx.getStreetName(coords)
    local main, cross = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return { main = GetStreetNameFromHashKey(main), cross = GetStreetNameFromHashKey(cross) }
end
function qbx.getZoneName(coords) return GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)) end

function qbx.setVehicleExtra(vehicle, extra, enable)
    if DoesExtraExist(vehicle, extra) then SetVehicleExtra(vehicle, extra, not enable) end
end
function qbx.resetVehicleExtras(vehicle)
    for i = 0, 20 do if DoesExtraExist(vehicle, i) then SetVehicleExtra(vehicle, i, true) end end
end
function qbx.setVehicleExtras(vehicle, extras)
    if not DoesEntityExist(vehicle) then return end
    for id, on in pairs(extras or {}) do qbx.setVehicleExtra(vehicle, tonumber(id), on == true or on == 1) end
end

function qbx.isWearingGloves()
    local ped = PlayerPedId()
    local arms = GetPedDrawableVariation(ped, 3)
    local list = GetEntityModel(ped) == joaat('mp_m_freemode_01') and qbx.armsWithoutGloves.male or qbx.armsWithoutGloves.female
    return not list[arms]
end

function qbx.isWearingDuffelbag()
    local bag = GetPedDrawableVariation(PlayerPedId(), 5)
    return qbx.duffelbagIndexes[bag] == true
end

function qbx.loadAudioBank(audioBank, timeout)
    local t = GetGameTimer()
    while not RequestScriptAudioBank(audioBank, false) do
        if GetGameTimer() - t > (timeout or 1000) then return false end
        Wait(0)
    end
    return true
end

function qbx.playAudio(params)
    local soundId = GetSoundId()
    local src = params.audioSource
    if type(src) == 'number' then
        PlaySoundFromEntity(soundId, params.audioName, src, params.audioRef, false, 0)
    elseif src then
        PlaySoundFromCoord(soundId, params.audioName, src.x, src.y, src.z, params.audioRef, false, params.range or 5.0, false)
    else
        PlaySoundFrontend(soundId, params.audioName, params.audioRef, true)
    end
    if params.returnSoundId then return soundId end
    ReleaseSoundId(soundId)
end
