local B, W = Bridge, Whip.core

local function gtaWeapons()
    local src = LoadResourceFile('whip_core', 'shared/gta_weapons.lua')
    if not src then return {} end
    local env = setmetatable({}, { __index = _G })
    local chunk, err = load(src, '@whip_core/shared/gta_weapons.lua', 't', env)
    local ok, why = false, err
    if chunk then ok, why = pcall(chunk) end
    if not ok then print('^3[whip_bridge] Shared.Weapons: ' .. tostring(why) .. '^0') return {} end
    return env.GtaWeapons and env.GtaWeapons.list or {}
end

-- whip's catalog is empty until whip_core is ready; until then read whip's server/vehicle_catalog_list.lua.
local shipped
local function shippedCatalog()
    if shipped then return shipped end
    shipped = {}
    local src = LoadResourceFile('whip_core', 'server/vehicle_catalog_list.lua')
    if not src then return shipped end
    local env = setmetatable({ VehicleCatalog = { seed = {} } }, { __index = _G })
    local chunk = load(src, '@whip_core/server/vehicle_catalog_list.lua', 't', env)
    if chunk and pcall(chunk) then
        for _, row in ipairs(env.VehicleCatalog.seed) do
            shipped[row[1]] = { displayName = row[3], class = row[2] }
        end
    end
    return shipped
end

function B.rebuildVehicles()
    local vehicles, hashes = {}, {}
    local catalog = W:GetVehicleCatalog() or {}
    if next(catalog) == nil then catalog = shippedCatalog() end
    for model, row in pairs(catalog) do
        local hash = joaat(model)
        local v = Convert.vehicle(model, row, hash)
        vehicles[model] = v
        hashes[hash] = v
    end
    for model, extra in pairs(BridgeConfig.Vehicles or {}) do
        local hash = joaat(model)
        local v = vehicles[model] or Convert.vehicle(model, {}, hash)
        for k, val in pairs(extra) do v[k] = val end
        v.model, v.hash = model, hash
        vehicles[model], hashes[hash] = v, v
    end
    QBCore.Shared.Vehicles = vehicles
    QBCore.Shared.VehicleHashes = hashes
    if not next(QBCore.Shared.Weapons) then
        local weapons = {}
        for _, w in ipairs(gtaWeapons()) do weapons[joaat(w.name)] = Convert.weapon(w) end
        QBCore.Shared.Weapons = weapons
    end
end

local function entityOf(vehicleId)
    for _ = 1, 50 do
        local v = W:GetVehicle(vehicleId)
        if v and v.netId then
            local ent = NetworkGetEntityFromNetworkId(v.netId)
            if ent and ent ~= 0 then return ent, v.netId end
        end
        Wait(100)
    end
end

function B.spawnVehicle(src, model, coords, warp, props)
    local ped = src and src > 0 and GetPlayerPed(src) or nil
    if type(model) == 'number' then
        for name, v in pairs(QBCore.Shared.Vehicles) do if v.hash == model then model = name break end end
    end
    if not coords and ped then
        local c = GetEntityCoords(ped)
        coords = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
    end
    if not coords then return nil end
    local heading = coords.w or coords.heading or 0.0
    local id, why = W:SpawnTempVehicle(tostring(model), vector4(coords.x, coords.y, coords.z, heading), {
        forSource = ped and src or nil, idleDespawn = false, locked = false,
    })
    if not id then print(('^3[whip_bridge] spawn %s: %s^0'):format(tostring(model), tostring(why))) return nil end
    local veh, netId = entityOf(id)
    if not veh then return nil end
    if props then W:SetVehicleAppearance(id, props) end
    if warp and ped then
        for _ = 1, 20 do
            SetPedIntoVehicle(ped, veh, -1)
            Wait(50)
            if GetVehiclePedIsIn(ped, false) == veh then break end
        end
    end
    return veh, netId, id
end

function B.deleteVehicle(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local ok = W:DeleteVehicle({ entity = veh })
    if not ok and DoesEntityExist(veh) then DeleteEntity(veh) end
    return true
end

-- Server-side GetVehicleNumberPlateText is empty until some client has streamed the car, so ask whip.
function B.getPlate(veh)
    if not veh or veh == 0 then return nil end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s*(.-)%s*$', '%1')
    if plate == '' then
        local v = W:GetVehicle({ entity = veh })
        plate = v and v.plate or ''
    end
    if plate == '' then return nil end
    return plate
end

function B.vehiclesByCategory()
    local out = {}
    for _, v in pairs(QBCore.Shared.Vehicles) do
        out[v.category] = out[v.category] or {}
        out[v.category][#out[v.category] + 1] = v
    end
    return out
end

function B.vehicleClass(model)
    local row = (W:GetVehicleCatalog() or {})[model]
    return row and Convert.classNumber(row.class) or nil
end
