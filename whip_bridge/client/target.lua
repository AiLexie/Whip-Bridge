local W = Whip.core
local Sets = {}
local Disabled = false
local nextOpt, nextZone = 0, 0
local OxZoneByName = {}

local function playerAllowed(opt, ctx, set)
    local d = QBCore.PlayerData
    if not d.job then return false end
    local groups = Convert.groupNeeds(opt.job or opt.groups)
    if groups then
        local ok = (groups[d.job.name] and d.job.grade.level >= groups[d.job.name])
            or (d.gang and groups[d.gang.name] and d.gang.grade.level >= groups[d.gang.name])
        if not ok then return false end
    end
    local gangs = Convert.groupNeeds(opt.gang)
    if gangs and not (d.gang and gangs[d.gang.name] and d.gang.grade.level >= gangs[d.gang.name]) then return false end
    if opt.citizenid then
        local cids = Convert.groupFilter(opt.citizenid)
        if not cids[d.citizenid] then return false end
    end
    if set.filter == 'player' and not ctx.player then return false end
    if set.filter == 'npc' and ctx.player then return false end
    if opt.anyItem and opt.items then
        local any = false
        for item in pairs(Convert.itemList(opt.items)) do
            if W:HasItem(item) then any = true break end
        end
        if not any then return false end
    end
    return true
end

local function distanceTo(ctx)
    if not ctx.coords then return 0.0 end
    return #(GetEntityCoords(PlayerPedId()) - vector3(ctx.coords.x, ctx.coords.y, ctx.coords.z))
end

local function canInteract(set, opt, ctx)
    if not playerAllowed(opt, ctx, set) then return false end
    local dist = distanceTo(ctx)
    if opt.distance and dist > opt.distance + 0.5 then return false end
    if opt.canInteract == nil then return true end
    local ok, res
    if opt.__api == 'ox' then
        ok, res = pcall(opt.canInteract, ctx.entity or 0, dist, ctx.coords, opt.name, nil)
    else
        ok, res = pcall(opt.canInteract, ctx.entity or 0, dist, opt)
    end
    return ok and res and true or false
end

local function payload(set, opt, ctx)
    local data = {}
    for k, v in pairs(opt) do
        if type(v) ~= 'function' and type(v) ~= 'table' or k == 'args' or k == 'groups' or k == 'items' then data[k] = v end
    end
    data.__api = nil
    data.__owner = nil
    data.entity = ctx.entity or 0
    data.coords = ctx.coords
    data.distance = distanceTo(ctx)
    data.zone = set.zone
    return data
end

local function run(set, opt, ctx)
    local data = payload(set, opt, ctx)
    if opt.__api == 'ox' then
        if opt.onSelect ~= nil then return opt.onSelect(data) end
        if opt.export then
            local res, fn = opt.export:match('^([^%.]+)%.(.+)$')
            if res then return exports[res][fn](nil, data) end
        end
        if opt.event then return TriggerEvent(opt.event, data) end
        if opt.serverEvent then return TriggerServerEvent(opt.serverEvent, data) end
        if opt.command then return ExecuteCommand(opt.command) end
        return
    end
    if opt.action ~= nil then return opt.action(ctx.entity or 0) end
    local kind = opt.type or 'client'
    if not opt.event then return end
    if kind == 'client' then TriggerEvent(opt.event, data)
    elseif kind == 'server' then TriggerServerEvent(opt.event, data)
    elseif kind == 'command' then ExecuteCommand(opt.event)
    elseif kind == 'qbcommand' then TriggerServerEvent('QBCore:CallCommand', opt.event, data)
    end
end

local function whipOption(set, opt)
    local require
    local items = not opt.anyItem and Convert.itemNeeds(opt.item or opt.items) or nil
    if items then require = { item = items } end
    return {
        id = opt.__id,
        label = opt.label or opt.name or '?',
        icon = Convert.icon(opt.icon),
        require = require,
        canInteract = function(ctx) return canInteract(set, opt, ctx) end,
        onSelect = function(ctx) run(set, opt, ctx) end,
    }
end

local function sync(key)
    local set = Sets[key]
    if not set then return end
    if #set.options == 0 then
        if set.id then W:RemoveAction(set.id) end
        Sets[key] = nil
        return
    end
    local options = {}
    for i, opt in ipairs(set.options) do options[i] = whipOption(set, opt) end
    local def = {
        id = 'qbt:' .. key, at = set.at, label = options[1].label, icon = options[1].icon, reach = set.reach,
        enabled = not Disabled, options = options, group = 'qbx_core:target', focusMode = set.focusMode,
    }
    if set.at.entity then def.onGone = function() Sets[key] = nil end end
    local ok, why
    if set.id then
        ok, why = W:UpdateAction(set.id, def)
    else
        ok, why = W:AddAction(def)
        if ok then set.id = ok end
    end
    if not ok then print(('^3[whip_bridge] target %s: %s^0'):format(key, tostring(why))) end
end

local function add(key, at, options, api, extra)
    extra = extra or {}
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local set = Sets[key]
    if not set then
        set = { at = at, options = {}, reach = extra.reach, filter = extra.filter, zone = extra.zone, focusMode = extra.focusMode }
        Sets[key] = set
    elseif extra.zone then
        set.at, set.reach, set.options = at, extra.reach, {}
    elseif extra.reach and (not set.reach or extra.reach > set.reach) then
        set.reach = extra.reach
    end
    for _, opt in ipairs(options or {}) do
        nextOpt = nextOpt + 1
        opt.__id = 'o' .. nextOpt
        opt.__api = api
        opt.__owner = owner
        for i = #set.options, 1, -1 do
            local o = set.options[i]
            if o.__owner == owner and o.label == opt.label and (o.name == opt.name) then table.remove(set.options, i) end
        end
        set.options[#set.options + 1] = opt
    end
    sync(key)
end

local function remove(key, names, field)
    local set = Sets[key]
    if not set then return end
    if names == nil then
        set.options = {}
    else
        local list = type(names) == 'table' and names or { names }
        local drop = {}
        for _, n in pairs(list) do drop[n] = true end
        for i = #set.options, 1, -1 do
            if drop[set.options[i][field]] then table.remove(set.options, i) end
        end
    end
    sync(key)
end

AddEventHandler('onResourceStop', function(res)
    for key, set in pairs(Sets) do
        local before = #set.options
        for i = #set.options, 1, -1 do
            if set.options[i].__owner == res then table.remove(set.options, i) end
        end
        if #set.options ~= before then sync(key) end
    end
end)

local function setDisabled(value)
    Disabled = value == true
    for key in pairs(Sets) do sync(key) end
end

local function list(x)
    if type(x) == 'table' and x.x == nil then return x end
    return { x }
end

local function vec3(c) return vector3(c.x, c.y, c.z) end

local function qbOptions(params)
    params = params or {}
    local opts = params.options or {}
    for _, o in ipairs(opts) do o.distance = o.distance or params.distance end
    return opts, params.distance or 2.5
end

local function oxOptions(options)
    if options == nil then return {} end
    if options.label or options.name then return { options } end
    return options
end

local function oxReach(opts, base)
    local r = base or 2.0
    for _, o in ipairs(opts) do if o.distance and o.distance > r then r = o.distance end end
    return r
end

local function entityAt(entity)
    if NetworkGetEntityIsNetworked(entity) then return { netId = NetworkGetNetworkIdFromEntity(entity) }, 'net:' .. NetworkGetNetworkIdFromEntity(entity) end
    return { entity = entity }, 'entity:' .. entity
end

local GLOBALS = { ped = { aimBox = 'ped', filter = 'npc' }, player = { aimBox = 'ped', filter = 'player' },
    vehicle = { aimBox = 'vehicle' }, object = { aimBox = 'object' } }
local TYPES = { [1] = 'ped', [2] = 'vehicle', [3] = 'object', [4] = 'player' }

local function addGlobal(kind, options, api, reach)
    local g = GLOBALS[kind]
    add('global:' .. kind, { aimBox = g.aimBox }, options, api, { reach = reach, filter = g.filter })
end

local Q = {}
local ZoneData = {}

function Q.AddBoxZone(name, center, length, width, zoneOptions, targetoptions)
    local opts, dist = qbOptions(targetoptions)
    ZoneData[name] = { center = center, length = length, width = width, options = zoneOptions, targetoptions = targetoptions }
    add('zone:' .. name, { coords = vec3(center) }, opts, 'qb',
        { reach = math.max(dist, math.max(length or 0, width or 0) / 2), zone = name, focusMode = 'near' })
    return name
end

function Q.AddCircleZone(name, center, radius, zoneOptions, targetoptions)
    local opts, dist = qbOptions(targetoptions)
    ZoneData[name] = { center = center, radius = radius, options = zoneOptions, targetoptions = targetoptions }
    add('zone:' .. name, { coords = vec3(center) }, opts, 'qb', { reach = math.max(dist, radius or 0), zone = name, focusMode = 'near' })
    return name
end

function Q.AddPolyZone(name, points, zoneOptions, targetoptions)
    local opts, dist = qbOptions(targetoptions)
    zoneOptions = zoneOptions or {}
    local c = Convert.centroid(points, zoneOptions.minZ, zoneOptions.maxZ)
    if not c then return end
    ZoneData[name] = { points = points, options = zoneOptions, targetoptions = targetoptions }
    add('zone:' .. name, { coords = vec3(c) }, opts, 'qb',
        { reach = math.max(dist, Convert.radius(points, c)), zone = name, focusMode = 'near' })
    return name
end

function Q.AddComboZone(zones, zoneOptions, targetoptions)
    local name = zoneOptions and zoneOptions.name or ('combo' .. tostring(#zones))
    for i, z in ipairs(zones or {}) do
        local c = z.center or z.startPos or (z.points and Convert.centroid(z.points, z.minZ, z.maxZ))
        if c then
            local opts, dist = qbOptions(targetoptions)
            add('zone:' .. name .. ':' .. i, { coords = vec3(c) }, opts, 'qb',
                { reach = math.max(dist, z.radius or (z.length and z.length / 2) or 2.5), zone = name, focusMode = 'near' })
        end
    end
    ZoneData[name] = { zones = zones, options = zoneOptions, targetoptions = targetoptions }
    return name
end

function Q.AddEntityZone(name, entity, zoneOptions, targetoptions)
    local opts, dist = qbOptions(targetoptions)
    ZoneData[name] = { entity = entity, options = zoneOptions, targetoptions = targetoptions }
    local at = entityAt(entity)
    add('zone:' .. name, at, opts, 'qb', { reach = dist, zone = name })
    return name
end

function Q.RemoveZone(name)
    for key in pairs(Sets) do
        if key == 'zone:' .. name or key:find('^zone:' .. name:gsub('%p', '%%%0') .. ':%d+$') then remove(key) end
    end
    ZoneData[name] = nil
end

function Q.AddTargetEntity(entities, params)
    local opts, dist = qbOptions(params)
    for _, e in ipairs(list(entities)) do
        local at, key = entityAt(e)
        add(key, at, opts, 'qb', { reach = dist })
    end
end
function Q.RemoveTargetEntity(entities, labels)
    for _, e in ipairs(list(entities)) do
        local _, key = entityAt(e)
        remove(key, labels, 'label')
    end
end

function Q.AddTargetModel(models, params)
    local opts, dist = qbOptions(params)
    for _, m in ipairs(list(models)) do add('model:' .. tostring(m), { model = m }, opts, 'qb', { reach = dist }) end
end
function Q.RemoveTargetModel(models, labels)
    for _, m in ipairs(list(models)) do remove('model:' .. tostring(m), labels, 'label') end
end

local function boneKey(bone)
    local part = Convert.boneToPart(bone)
    if part then return 'part:' .. part, { vehiclePart = part } end
    return 'global:vehicle', { aimBox = 'vehicle' }
end
function Q.AddTargetBone(bones, params)
    local opts, dist = qbOptions(params)
    for _, b in ipairs(list(bones)) do
        local key, at = boneKey(b)
        add(key, at, opts, 'qb', { reach = dist })
    end
end
function Q.RemoveTargetBone(bones, labels)
    for _, b in ipairs(list(bones)) do remove((boneKey(b)), labels, 'label') end
end

for kind, name in pairs({ ped = 'Ped', vehicle = 'Vehicle', object = 'Object', player = 'Player' }) do
    Q['AddGlobal' .. name] = function(params)
        local opts, dist = qbOptions(params)
        addGlobal(kind, opts, 'qb', dist)
    end
    Q['RemoveGlobal' .. name] = function(labels) remove('global:' .. kind, labels, 'label') end
    Q['UpdateGlobal' .. name .. 'Data'] = function(label, data)
        local set = Sets['global:' .. kind]
        if not set then return end
        for _, o in ipairs(set.options) do if o.label == label then for k, v in pairs(data) do o[k] = v end end end
        sync('global:' .. kind)
    end
    Q['GetGlobal' .. name .. 'Data'] = function(label)
        local set = Sets['global:' .. kind]
        for _, o in ipairs(set and set.options or {}) do if o.label == label then return o end end
    end
end
function Q.AddGlobalType(kind, params) local k = TYPES[kind] if k then Q['AddGlobal' .. ({ ped = 'Ped', vehicle = 'Vehicle', object = 'Object', player = 'Player' })[k]](params) end end
function Q.RemoveGlobalType(kind, labels) local k = TYPES[kind] if k then remove('global:' .. k, labels, 'label') end end
function Q.UpdateGlobalTypeData(kind, label, data)
    local k = TYPES[kind]
    if k then Q['UpdateGlobal' .. ({ ped = 'Ped', vehicle = 'Vehicle', object = 'Object', player = 'Player' })[k] .. 'Data'](label, data) end
end
function Q.GetGlobalTypeData(kind, label)
    local k = TYPES[kind]
    if k then return Q['GetGlobal' .. ({ ped = 'Ped', vehicle = 'Vehicle', object = 'Object', player = 'Player' })[k] .. 'Data'](label) end
end

local function findOption(key, label)
    local set = Sets[key]
    for _, o in ipairs(set and set.options or {}) do if o.label == label then return o end end
end
local function updateOption(key, label, data)
    local o = findOption(key, label)
    if not o then return end
    for k, v in pairs(data or {}) do o[k] = v end
    sync(key)
end

function Q.UpdateZoneData(name, data)
    local z = ZoneData[name]
    if not z then return end
    z.targetoptions = data
    local set = Sets['zone:' .. name]
    if set then
        local opts = qbOptions(data)
        set.options = {}
        add('zone:' .. name, set.at, opts, 'qb')
    end
end
function Q.GetZoneData(name) return ZoneData[name] end
function Q.UpdateTargetModelData(model, label, data) updateOption('model:' .. tostring(model), label, data) end
function Q.GetTargetModelData(model, label) return findOption('model:' .. tostring(model), label) end
function Q.UpdateTargetEntityData(entity, label, data) local _, key = entityAt(entity) updateOption(key, label, data) end
function Q.GetTargetEntityData(entity, label) local _, key = entityAt(entity) return findOption(key, label) end
function Q.UpdateTargetBoneData(bone, label, data) updateOption((boneKey(bone)), label, data) end
function Q.GetTargetBoneData(bone, label) return findOption((boneKey(bone)), label) end

function Q.AllowTargeting(value) setDisabled(value == false) end
function Q.DisableTarget(value) setDisabled(value ~= false) end
function Q.IsTargetActive() return false end
function Q.IsTargetSuccess() return false end
function Q.CheckEntity() end
function Q.CheckBones() end
function Q.LeftTarget() end
function Q.EnableNUI() end
function Q.DisableNUI() end
function Q.DrawOutlineEntity(entity, toggle)
    SetEntityDrawOutline(entity, toggle == true)
end

function Q.RaycastCamera(flag, playerCoords)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local to = cam + dir * 30.0
    local ray = StartShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, flag or -1, PlayerPedId(), 7)
    local result, hit, endCoords, _, entity
    repeat
        result, hit, endCoords, _, entity = GetShapeTestResult(ray)
        Wait(0)
    until result ~= 1
    local dist = playerCoords and #(playerCoords - endCoords) or #(GetEntityCoords(PlayerPedId()) - endCoords)
    return endCoords, dist, entity, entity ~= 0 and GetEntityType(entity) or 0
end

local Peds = {}

local function spawnOne(data)
    local model = type(data.model) == 'string' and joaat(data.model) or data.model
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) do
        if GetGameTimer() - t > 10000 then return nil end
        Wait(0)
    end
    local c = data.coords
    local z = data.minusOne and c.z - 1.0 or c.z
    local ped = CreatePed(0, model, c.x, c.y, z, c.w or 0.0, data.networked == true, false)
    SetModelAsNoLongerNeeded(model)
    if data.freeze then FreezeEntityPosition(ped, true) end
    if data.invincible then SetEntityInvincible(ped, true) end
    if data.blockevents then SetBlockingOfNonTemporaryEvents(ped, true) end
    if data.animDict and data.anim then
        RequestAnimDict(data.animDict)
        while not HasAnimDictLoaded(data.animDict) do Wait(0) end
        TaskPlayAnim(ped, data.animDict, data.anim, 8.0, 0, -1, data.flag or 1, 0, false, false, false)
    end
    if data.scenario then TaskStartScenarioInPlace(ped, data.scenario, 0, true) end
    if data.pedrelations then SetPedRelationshipGroupHash(ped, joaat(data.pedrelations.groupname or 'CIVMALE')) end
    if data.weapon then GiveWeaponToPed(ped, joaat(data.weapon.name), data.weapon.ammo or 0, data.weapon.hidden == true, true) end
    data.currentpednumber = ped
    if data.target then
        if data.target.useModel then
            Q.AddTargetModel(data.model, data.target)
        else
            Q.AddTargetEntity(ped, data.target)
        end
    end
    if data.action ~= nil then data.action(data) end
    Peds[#Peds + 1] = data
    return ped
end

function Q.SpawnPed(data)
    if data.model then
        CreateThread(function() spawnOne(data) end)
        return
    end
    for _, d in pairs(data) do CreateThread(function() spawnOne(d) end) end
end

function Q.RemoveSpawnedPed(peds)
    for _, p in ipairs(list(peds)) do
        for i = #Peds, 1, -1 do
            if Peds[i].currentpednumber == p then
                Q.RemoveTargetEntity(p)
                DeletePed(p)
                table.remove(Peds, i)
            end
        end
    end
end

function Q.DeletePeds()
    for _, d in ipairs(Peds) do
        if d.currentpednumber and DoesEntityExist(d.currentpednumber) then DeletePed(d.currentpednumber) end
    end
    Peds = {}
end

function Q.GetPeds() return Peds end
function Q.UpdatePedsData(index, data) Peds[index] = data end

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then Q.DeletePeds() end end)

for name, fn in pairs(Q) do exports(name, fn) end

local O = {}

local function oxZoneKey(data)
    nextZone = nextZone + 1
    local key = 'oxzone:' .. nextZone
    if data.name then
        if OxZoneByName[data.name] then remove(OxZoneByName[data.name]) end
        OxZoneByName[data.name] = key
    end
    return key, nextZone
end

function O.addBoxZone(data)
    local opts = oxOptions(data.options)
    local key, id = oxZoneKey(data)
    local size = data.size or vector3(2, 2, 2)
    add(key, { coords = vec3(data.coords) }, opts, 'ox',
        { reach = oxReach(opts, math.max(size.x, size.y) / 2 + 1.0), zone = data.name or id, focusMode = 'near' })
    return id
end

function O.addSphereZone(data)
    local opts = oxOptions(data.options)
    local key, id = oxZoneKey(data)
    add(key, { coords = vec3(data.coords) }, opts, 'ox',
        { reach = oxReach(opts, (data.radius or 2.0) + 1.0), zone = data.name or id, focusMode = 'near' })
    return id
end

function O.addPolyZone(data)
    local opts = oxOptions(data.options)
    local c = Convert.centroid(data.points)
    if not c then return end
    if data.thickness then c.z = c.z + data.thickness / 2 end
    local key, id = oxZoneKey(data)
    add(key, { coords = vec3(c) }, opts, 'ox',
        { reach = oxReach(opts, Convert.radius(data.points, c) + 1.0), zone = data.name or id, focusMode = 'near' })
    return id
end

function O.removeZone(id)
    local key = type(id) == 'string' and OxZoneByName[id] or ('oxzone:' .. tostring(id))
    if Sets[key] then remove(key) end
    if type(id) == 'string' then OxZoneByName[id] = nil end
end

function O.zoneExists(id)
    local key = type(id) == 'string' and OxZoneByName[id] or ('oxzone:' .. tostring(id))
    return Sets[key] ~= nil
end

function O.addLocalEntity(arr, options)
    local opts = oxOptions(options)
    for _, e in ipairs(list(arr)) do add('entity:' .. e, { entity = e }, opts, 'ox', { reach = oxReach(opts) }) end
end
function O.removeLocalEntity(arr, names)
    for _, e in ipairs(list(arr)) do remove('entity:' .. e, names, 'name') end
end

function O.addEntity(netIds, options)
    local opts = oxOptions(options)
    for _, n in ipairs(list(netIds)) do add('net:' .. n, { netId = n }, opts, 'ox', { reach = oxReach(opts) }) end
end
function O.removeEntity(netIds, names)
    for _, n in ipairs(list(netIds)) do remove('net:' .. n, names, 'name') end
end

function O.addModel(models, options)
    local opts = oxOptions(options)
    for _, m in ipairs(list(models)) do add('model:' .. tostring(m), { model = m }, opts, 'ox', { reach = oxReach(opts) }) end
end
function O.removeModel(models, names)
    for _, m in ipairs(list(models)) do remove('model:' .. tostring(m), names, 'name') end
end

local function oxGlobalVehicle(opts)
    local plain = {}
    for _, o in ipairs(opts) do
        local bones = o.bones and list(o.bones)
        if bones then
            for _, b in ipairs(bones) do
                local key, at = boneKey(b)
                add(key, at, { o }, 'ox', { reach = oxReach({ o }) })
            end
        else
            plain[#plain + 1] = o
        end
    end
    if #plain > 0 then addGlobal('vehicle', plain, 'ox', oxReach(plain)) end
end

function O.addGlobalPed(options) local o = oxOptions(options) addGlobal('ped', o, 'ox', oxReach(o)) end
function O.addGlobalPlayer(options) local o = oxOptions(options) addGlobal('player', o, 'ox', oxReach(o)) end
function O.addGlobalObject(options) local o = oxOptions(options) addGlobal('object', o, 'ox', oxReach(o)) end
function O.addGlobalVehicle(options) oxGlobalVehicle(oxOptions(options)) end
function O.addGlobalOption(options)
    local o = oxOptions(options)
    add('global:any', { aimBox = { 'ped', 'vehicle', 'object' } }, o, 'ox', { reach = oxReach(o) })
end

function O.removeGlobalPed(names) remove('global:ped', names, 'name') end
function O.removeGlobalPlayer(names) remove('global:player', names, 'name') end
function O.removeGlobalObject(names) remove('global:object', names, 'name') end
function O.removeGlobalVehicle(names)
    remove('global:vehicle', names, 'name')
    for key in pairs(Sets) do if key:find('^part:') then remove(key, names, 'name') end end
end
function O.removeGlobalOption(names) remove('global:any', names, 'name') end

function O.disableTargeting(value) setDisabled(value) end
function O.isActive() return false end
function O.getTargetOptions(entity, kind, model)
    local out = {}
    local function addFrom(key)
        for _, o in ipairs(Sets[key] and Sets[key].options or {}) do out[#out + 1] = o end
    end
    if entity then addFrom('entity:' .. entity) end
    if model then addFrom('model:' .. tostring(model)) end
    if kind then addFrom('global:' .. kind) end
    return out
end

for name, fn in pairs(O) do exports(name, fn) end

RegisterNetEvent('ox_target:toggleEntityDoor', function(netId, door)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end
    if GetVehicleDoorAngleRatio(veh, door) > 0.0 then SetVehicleDoorShut(veh, door, false) else SetVehicleDoorOpen(veh, door, false, false) end
end)
