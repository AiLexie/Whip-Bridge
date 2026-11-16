Convert = {}

Convert.UNEMPLOYED = {
    name = 'unemployed', label = 'Civilian', payment = 0, type = 'none', onduty = false, isboss = false,
    grade = { name = 'Freelancer', level = 0 },
}

Convert.NO_GANG = { name = 'none', label = 'No Gang', isboss = false, grade = { name = 'none', level = 0 } }

local NOTIFY = { primary = 'info', inform = 'info', info = 'info', success = 'success', error = 'error',
    warning = 'warning', warn = 'warning', police = 'info', ambulance = 'info' }

function Convert.notifyType(t)
    return NOTIFY[t] or 'info'
end

-- qb weights are grams, whip's are kg.
function Convert.item(key, def)
    return {
        name = key,
        label = def.name or key,
        weight = math.floor((def.weight or 0) * 1000 + 0.5),
        type = def.type == 'weapon' and 'weapon' or 'item',
        image = key .. '.png',
        unique = def.stack == false,
        useable = def.usable == true,
        shouldClose = true,
        description = def.desc or '',
    }
end

function Convert.toWhipItem(qb)
    return {
        name = qb.label or qb.name,
        desc = qb.description,
        weight = (tonumber(qb.weight) or 0) / 1000,
        stack = not qb.unique,
        usable = qb.useable == true or nil,
    }
end

function Convert.slot(slot, data, def)
    local s = def and Convert.item(data.item, def) or { name = data.item, label = data.item, weight = 0,
        type = 'item', unique = false, useable = false, shouldClose = true, description = '', image = data.item .. '.png' }
    s.amount = data.amount or 1
    s.count = s.amount
    s.info = data.metadata or {}
    s.metadata = s.info
    s.slot = slot
    return s
end

function Convert.items(inv, defs)
    local out = {}
    for slot, data in pairs((inv and inv.player) or {}) do
        local n = tonumber(slot)
        if n and data and data.item then out[n] = Convert.slot(n, data, defs and defs[data.item]) end
    end
    return out
end

-- roles come highest first, as GetJobRoles returns them.
function Convert.gradeIndex(roles, roleId)
    for i, r in ipairs(roles or {}) do
        if r.roleId == roleId then return #roles - i end
    end
    return 0
end

function Convert.roleForGrade(roles, grade)
    if not roles or #roles == 0 then return nil end
    local g = math.floor(tonumber(grade) or 0)
    if g < 0 then g = 0 end
    if g > #roles - 1 then g = #roles - 1 end
    return roles[#roles - g]
end

function Convert.job(info, roles, def)
    if not info then return Convert.UNEMPLOYED end
    local perms = info.permissions or {}
    return {
        name = info.key,
        label = (def and def.name) or info.name or info.key,
        payment = 0,
        type = 'none',
        onduty = info.clockedOn == true,
        isboss = (info.roleLevel or 0) >= 100 or perms.canHire == true,
        grade = { name = info.roleName or '', level = Convert.gradeIndex(roles, info.roleId) },
    }
end

function Convert.sharedJob(def, roles)
    local grades = {}
    local n = #(roles or {})
    for i, r in ipairs(roles or {}) do
        local p = r.permissions or {}
        grades[tostring(n - i)] = { name = r.name, payment = 0, isboss = r.level >= 100 or p.canHire == true }
    end
    return { label = def.name or def.key, type = 'none', defaultDuty = false, offDutyPay = false, grades = grades }
end

function Convert.charinfo(p, meta)
    return {
        firstname = p.firstName or '',
        lastname = p.lastName or '',
        birthdate = p.dateOfBirth or '',
        gender = p.gender == 'female' and 1 or 0,
        nationality = meta.nationality or '',
        phone = meta.phone or '',
        account = meta.account or '',
    }
end

local META_DEFAULTS = {
    hunger = 100, thirst = 100, stress = 0, armor = 0, ishandcuffed = false, tracker = false, injail = 0,
    jailitems = {}, status = {}, phone = {}, fitbit = {}, commandbinds = {}, bloodtype = 'O+', dealerrep = 0,
    craftingrep = 0, attachmentcraftingrep = 0, currentapartment = false, jobrep = {}, rep = {}, callsign = 'NO CALLSIGN',
    fingerprint = '', walletid = '', criminalrecord = { hasRecord = false },
    licences = { driver = true, business = false, weapon = false }, inside = { apartment = {} },
}

function Convert.metadata(meta, p)
    local out = {}
    for k, v in pairs(META_DEFAULTS) do out[k] = type(v) == 'table' and {} or v end
    out.licences = { driver = true, business = false, weapon = false }
    out.criminalrecord = { hasRecord = false }
    for k, v in pairs(meta or {}) do out[k] = v end
    out.isdead = p and p.isDead == true or false
    out.inlaststand = false
    if p and p.armour then out.armor = p.armour end
    return out
end

function Convert.itemList(items, amount)
    local want = {}
    if type(items) == 'string' then
        want[items] = amount or 1
    elseif type(items) == 'table' then
        for k, v in pairs(items) do
            if type(k) == 'number' then want[v] = amount or 1 else want[k] = tonumber(v) or 1 end
        end
    end
    return want
end

function Convert.groupFilter(filter)
    local f = {}
    if type(filter) == 'string' then
        f[filter] = 0
    elseif type(filter) == 'table' then
        for k, v in pairs(filter) do
            if type(k) == 'number' then f[v] = 0 else f[k] = tonumber(v) or 0 end
        end
    end
    return f
end

-- qb-inventory: (inv, item, amount, slot, info, reason); ox_inventory: (inv, item, count, metadata, slot).
function Convert.itemArgs(a1, a2, a3, a4, a5, a6)
    local meta, slot, reason
    if type(a4) == 'table' then
        meta = a4
        slot = tonumber(a5)
    else
        slot = tonumber(a4)
        if type(a5) == 'table' then meta = a5 end
        if type(a6) == 'string' then reason = a6 end
    end
    local inv = tonumber(a1) or a1
    return inv, a2, math.floor(tonumber(a3) or 1), meta, slot, reason
end

-- Inventory ids: 12 (pockets), 'trunk-PLATE'/'trunkPLATE', 'glovebox-PLATE'/'glovePLATE', 'otherplayer-12', { id, owner } (ox), else a stash name.
-- ponytail: a stash whose own name starts with 'trunk'/'glove' reads as a car; rename such a stash.
function Convert.invRef(inv)
    if type(inv) == 'number' then return { player = inv } end
    if type(inv) == 'table' then
        local id = tostring(inv.id or inv.name or '')
        if inv.owner ~= nil and inv.owner ~= false then id = id .. ':' .. tostring(inv.owner) end
        return { stash = id }
    end
    if type(inv) ~= 'string' then return nil end
    local n = tonumber(inv)
    if n then return { player = n } end
    if inv == 'trunk' or inv == 'trunk-' or inv == 'glove' or inv == 'glovebox' or inv == 'glovebox-' then return nil end
    local other = inv:match('^otherplayer%-(%d+)$')
    if other then return { player = tonumber(other) } end
    local plate = inv:match('^trunk%-(.+)$') or inv:match('^trunk(.+)$')
    if plate then return { vehicle = plate, sub = 'trunk' } end
    plate = inv:match('^glovebox%-(.+)$') or inv:match('^glove(.+)$')
    if plate then return { vehicle = plate, sub = 'glovebox' } end
    return { stash = inv }
end

-- whip container keys allow only letters, digits and _ - . :, up to 100 chars.
function Convert.stashKey(name)
    return ('qb:' .. tostring(name):gsub('[^%w_%-%.:]', '_')):sub(1, 100)
end

local BOSS = { canHire = true, canFire = true, canPromote = true, canDemote = true, canManage = true }
function Convert.rolesFromGrades(grades)
    local list = {}
    for g, def in pairs(grades or {}) do
        local n = tonumber(g)
        if n then list[#list + 1] = { n = n, def = def } end
    end
    table.sort(list, function(a, b) return a.n < b.n end)
    local roles = {}
    local top = #list - 1
    for i, e in ipairs(list) do
        local idx = i - 1
        local level = top == 0 and 100 or math.floor(1 + idx * 99 / top)
        roles[i] = { name = e.def.name or ('Grade ' .. e.n), level = level,
            permissions = e.def.isboss and BOSS or nil }
    end
    if #roles == 0 then roles[1] = { name = 'Employee', level = 100, permissions = BOSS } end
    return roles
end

local CLASS = { compacts = 0, sedans = 1, sedan = 1, suvs = 2, suv = 2, coupes = 3, coupe = 3, muscle = 4,
    sportsclassics = 5, sports_classics = 5, sports = 6, super = 7, motorcycles = 8, motorcycle = 8, offroad = 9,
    ['off-road'] = 9, industrial = 10, utility = 11, vans = 12, van = 12, cycles = 13, boats = 14, boat = 14,
    helicopters = 15, helicopter = 15, planes = 16, plane = 16, service = 17, emergency = 18, military = 19,
    commercial = 20, trains = 21, openwheel = 22 }

function Convert.classNumber(class)
    if type(class) == 'number' then return class end
    return CLASS[tostring(class or ''):lower():gsub('%s', '')] or 0
end

function Convert.vehicle(model, row, hash)
    return {
        name = row.displayName or model,
        brand = row.brand or '',
        model = model,
        price = tonumber(row.price) or 0,
        category = type(row.class) == 'string' and row.class or tostring(row.class or 'none'),
        categoryLabel = type(row.class) == 'string' and row.class or nil,
        hash = hash,
        shop = 'pdm',
        type = 'automobile',
    }
end

local AMMO = { pistol = 'AMMO_PISTOL', smg = 'AMMO_SMG', rifle = 'AMMO_RIFLE', mg = 'AMMO_MG',
    machinegun = 'AMMO_MG', shotgun = 'AMMO_SHOTGUN', sniper = 'AMMO_SNIPER', heavy = 'AMMO_RPG',
    thrown = 'AMMO_THROWN' }

function Convert.weapon(w)
    local group = w.group or 'melee'
    return {
        name = w.name:lower(),
        label = w.label or w.name,
        weapontype = group:sub(1, 1):upper() .. group:sub(2),
        ammotype = AMMO[group],
        damagereason = 'Killed',
    }
end

function Convert.weight(items)
    local total = 0
    for _, it in pairs(items or {}) do total = total + (it.weight or 0) * (it.amount or 1) end
    return total
end

function Convert.freeSlot(items, slots)
    for i = 1, slots do
        if not items[i] then return i end
    end
end

function Convert.randomStr(len, pool)
    pool = pool or 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local out = {}
    for i = 1, len do
        local k = math.random(1, #pool)
        out[i] = pool:sub(k, k)
    end
    return table.concat(out)
end

function Convert.randomInt(len)
    return Convert.randomStr(len, '0123456789')
end

-- whip prompts can't use Font Awesome classes ('fas fa-car'), so those are dropped.
function Convert.icon(icon)
    if type(icon) ~= 'string' or icon:find('fa%-') or icon:find('^fa[srbl]? ') then return nil end
    return icon
end

function Convert.groupNeeds(spec)
    if spec == nil or spec == 'all' then return nil end
    local f = Convert.groupFilter(spec)
    if next(f) == nil then return nil end
    return f
end

function Convert.itemNeeds(spec)
    if spec == nil then return nil end
    if type(spec) == 'string' then return spec end
    local out = {}
    for k, v in pairs(spec) do
        if type(k) == 'number' then out[#out + 1] = v else out[#out + 1] = { item = k, count = tonumber(v) or 1 } end
    end
    if #out == 0 then return nil end
    return out
end

function Convert.centroid(points, minZ, maxZ)
    local x, y, z, n = 0, 0, 0, 0
    for _, p in ipairs(points or {}) do
        x, y, z, n = x + p.x, y + p.y, z + (p.z or 0), n + 1
    end
    if n == 0 then return nil end
    z = z / n
    if minZ and maxZ then z = (minZ + maxZ) / 2 elseif minZ then z = minZ + 1.0 end
    return { x = x / n, y = y / n, z = z }
end

function Convert.radius(points, center)
    local r = 0
    for _, p in ipairs(points or {}) do
        local d = math.sqrt((p.x - center.x) ^ 2 + (p.y - center.y) ^ 2)
        if d > r then r = d end
    end
    return r
end

local PARTS = {
    bonnet = 'hood', engine = 'hood', boot = 'trunk', trunk = 'trunk',
    door_dside_f = 'door_dside_f', door_pside_f = 'door_pside_f', door_dside_r = 'door_dside_r', door_pside_r = 'door_pside_r',
    seat_dside_f = 'door_dside_f', seat_pside_f = 'door_pside_f', seat_dside_r = 'door_dside_r', seat_pside_r = 'door_pside_r',
    handle_dside_f = 'door_dside_f', handle_pside_f = 'door_pside_f', handle_dside_r = 'door_dside_r', handle_pside_r = 'door_pside_r',
    window_lf = 'door_dside_f', window_rf = 'door_pside_f', window_lr = 'door_dside_r', window_rr = 'door_pside_r',
}
function Convert.boneToPart(bone) return PARTS[bone] end

function Convert.inputFields(inputs)
    local fields, readers = {}, {}
    for _, inp in ipairs(inputs or {}) do
        local kind = inp.type or 'text'
        if kind == 'checkbox' then
            for _, o in ipairs(inp.options or {}) do
                fields[#fields + 1] = { label = o.text or tostring(o.value), type = 'checkbox', default = o.checked == true }
                readers[#fields] = { key = o.value, checkbox = true }
            end
        elseif kind == 'select' or kind == 'radio' then
            local opts = {}
            for _, o in ipairs(inp.options or {}) do opts[#opts + 1] = { value = tostring(o.value), label = o.text or tostring(o.value) } end
            fields[#fields + 1] = { label = inp.text, type = 'select', options = opts,
                default = inp.default ~= nil and tostring(inp.default) or (opts[1] and opts[1].value) }
            readers[#fields] = { key = inp.name }
        else
            fields[#fields + 1] = { label = inp.text, type = kind == 'number' and 'number' or 'text',
                placeholder = inp.text, default = inp.default, required = inp.isRequired == true }
            readers[#fields] = { key = inp.name }
        end
    end
    return fields, readers
end

function Convert.inputResult(answer, readers)
    local out = {}
    for i, r in pairs(readers) do
        local v = answer[i]
        if r.checkbox then out[r.key] = v and 'true' or 'false' else out[r.key] = v ~= nil and tostring(v) or '' end
    end
    return out
end

function Convert.menu(menu)
    local title, opts, entries = nil, {}, {}
    for _, item in ipairs(menu or {}) do
        if item.isMenuHeader then
            title = title or item.header
        elseif not item.hidden and not item.disabled then
            entries[#entries + 1] = item
            local text = item.txt or item.text
            local label = tostring(item.header or '')
            if text and text ~= '' then label = label .. ' - ' .. tostring(text) end
            opts[#opts + 1] = { value = tostring(#entries), label = label }
        end
    end
    return title or 'Menu', opts, entries
end

function Convert.sharedHelpers(S)
    S.RandomStr = function(len) return Convert.randomStr(len) end
    S.RandomInt = function(len) return Convert.randomInt(len) end
    S.SplitStr = function(str, delimiter)
        local out, from = {}, 1
        local s, e = str:find(delimiter, from, true)
        while s do
            out[#out + 1] = str:sub(from, s - 1)
            from = e + 1
            s, e = str:find(delimiter, from, true)
        end
        out[#out + 1] = str:sub(from)
        return out
    end
    S.Trim = function(value)
        if not value then return nil end
        return (tostring(value):gsub('^%s*(.-)%s*$', '%1'))
    end
    S.FirstToUpper = function(value)
        if not value then return nil end
        return (tostring(value):gsub('^%l', string.upper))
    end
    S.Round = function(value, places)
        if not places then return math.floor(value + 0.5) end
        local m = 10 ^ places
        return math.floor(value * m + 0.5) / m
    end
    S.ChangeVehicleExtra = function(vehicle, extra, enable)
        if DoesExtraExist(vehicle, extra) then
            if enable then
                SetVehicleExtra(vehicle, extra, false)
                if not IsVehicleExtraTurnedOn(vehicle, extra) then S.ChangeVehicleExtra(vehicle, extra, enable) end
            else
                SetVehicleExtra(vehicle, extra, true)
                if IsVehicleExtraTurnedOn(vehicle, extra) then S.ChangeVehicleExtra(vehicle, extra, enable) end
            end
        end
    end
    S.SetDefaultVehicleExtras = function(vehicle, config)
        for i = 0, 20 do if DoesExtraExist(vehicle, i) then SetVehicleExtra(vehicle, i, true) end end
        for id, enabled in pairs(config or {}) do S.ChangeVehicleExtra(vehicle, tonumber(id), type(enabled) == 'boolean' and enabled or true) end
    end
    S.IsFunction = function(value)
        if type(value) == 'function' then return true end
        if type(value) == 'table' and rawget(value, '__cfx_functionReference') then return true end
        local mt = getmetatable(value)
        return mt ~= nil and mt.__call ~= nil
    end
    return S
end
