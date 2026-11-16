local B, W = Bridge, Whip.core
local QF, QC = QBCore.Functions, QBCore.Commands

function QC.Add(name, help, arguments, argsrequired, callback, permission, ...)
    local key = tostring(name):lower()
    permission = permission or 'user'
    QC.List[key] = { name = key, help = help, arguments = arguments or {}, argsrequired = argsrequired,
        callback = callback, permission = permission }
    RegisterCommand(key, function(src, args, raw)
        if src > 0 and not QF.HasPermission(src, permission) then
            QF.Notify(src, 'No access to this command', 'error')
            return
        end
        if argsrequired and #args < #(arguments or {}) then
            if src > 0 then QF.Notify(src, 'All arguments must be filled in', 'error') end
            return
        end
        TriggerEvent('QBCore:Server:PreCommandExecution', src, key, args)
        callback(src, args, raw)
    end, false)
    for _, s in ipairs(GetPlayers()) do
        s = tonumber(s)
        if QF.HasPermission(s, permission) then
            TriggerClientEvent('chat:addSuggestion', s, '/' .. key, help, arguments)
        end
    end
end

function QC.Refresh(src)
    local list = {}
    for key, cmd in pairs(QC.List) do
        if QF.HasPermission(src, cmd.permission) then
            list[#list + 1] = { name = '/' .. key, help = cmd.help, params = cmd.arguments }
        else
            TriggerClientEvent('chat:removeSuggestion', src, '/' .. key)
        end
    end
    TriggerClientEvent('chat:addSuggestions', src, list)
end

if not BridgeConfig.Commands then return end

local function target(src, arg)
    local id = tonumber(arg)
    if id and B.Players[id] then return id end
    QF.Notify(src, 'Player not online', 'error')
end

QC.Add('tp', 'TP to player or coords (admin)', { { name = 'id/x', help = 'Player id or x' },
    { name = 'y', help = 'y' }, { name = 'z', help = 'z' } }, false, function(src, args)
    if args[1] and not args[2] then
        local t = target(src, args[1])
        if t then TriggerClientEvent('QBCore:Command:TeleportToPlayer', src, GetEntityCoords(GetPlayerPed(t))) end
    elseif args[3] then
        TriggerClientEvent('QBCore:Command:TeleportToCoords', src, tonumber(args[1]), tonumber(args[2]), tonumber(args[3]),
            tonumber(args[4]) or 0.0)
    end
end, 'admin')

QC.Add('tpm', 'TP to marker (admin)', {}, false, function(src)
    TriggerClientEvent('QBCore:Command:GoToMarker', src)
end, 'admin')

QC.Add('togglepvp', 'Toggle PVP on the server (admin)', {}, false, function()
    QBCore.Config.Server.PVP = not QBCore.Config.Server.PVP
    TriggerClientEvent('QBCore:Client:PvpHasToggled', -1, QBCore.Config.Server.PVP)
end, 'admin')

QC.Add('addpermission', 'Give a player a permission (god)', { { name = 'id', help = 'Player id' },
    { name = 'permission', help = 'Permission level' } }, true, function(src, args)
    local t = target(src, args[1])
    if t and QF.AddPermission(t, tostring(args[2]):lower()) then QF.Notify(src, 'Permission given', 'success') end
end, 'god')

QC.Add('removepermission', 'Take a permission away (god)', { { name = 'id', help = 'Player id' },
    { name = 'permission', help = 'Permission level' } }, true, function(src, args)
    local t = target(src, args[1])
    if t and QF.RemovePermission(t, tostring(args[2]):lower()) then QF.Notify(src, 'Permission removed', 'success') end
end, 'god')

QC.Add('openserver', 'Open the server for everyone (admin)', {}, false, function()
    QBCore.Config.Server.Closed = false
end, 'admin')

QC.Add('closeserver', 'Close the server to people without permissions (admin)', { { name = 'reason', help = 'Reason' } },
    false, function(src, args)
    QBCore.Config.Server.Closed = true
    QBCore.Config.Server.ClosedReason = table.concat(args, ' ') ~= '' and table.concat(args, ' ') or 'Server Closed'
    for s in pairs(B.Players) do
        if not QF.HasPermission(s, 'admin') then W:KickPlayer(s, QBCore.Config.Server.ClosedReason) end
    end
end, 'admin')

QC.Add('car', 'Spawn a vehicle (admin)', { { name = 'model', help = 'Model name' } }, true, function(src, args)
    CreateThread(function()
        local ped = GetPlayerPed(src)
        local old = GetVehiclePedIsIn(ped, false)
        if old ~= 0 then B.deleteVehicle(old) end
        if not B.spawnVehicle(src, args[1], nil, true) then QF.Notify(src, 'Could not spawn ' .. args[1], 'error') end
    end)
end, 'admin')

local function dvNear(src, list, radius)
    local c = GetEntityCoords(GetPlayerPed(src))
    for _, e in ipairs(list) do
        if #(c - GetEntityCoords(e)) <= radius then B.deleteVehicle(e) end
    end
end

QC.Add('dv', 'Delete vehicle (admin)', {}, false, function(src)
    CreateThread(function()
        local ped = GetPlayerPed(src)
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then B.deleteVehicle(veh) return end
        dvNear(src, GetAllVehicles(), 5.0)
    end)
end, 'admin')

QC.Add('dvall', 'Delete all vehicles (admin)', {}, false, function()
    CreateThread(function()
        for _, v in ipairs(GetAllVehicles()) do
            local driver = GetPedInVehicleSeat(v, -1)
            if driver == 0 or not IsPedAPlayer(driver) then B.deleteVehicle(v) end
        end
    end)
end, 'admin')

QC.Add('dvp', 'Delete all peds (admin)', {}, false, function()
    for _, p in ipairs(GetAllPeds()) do if not IsPedAPlayer(p) then DeleteEntity(p) end end
end, 'admin')

QC.Add('dvo', 'Delete all objects (admin)', {}, false, function()
    for _, o in ipairs(GetAllObjects()) do DeleteEntity(o) end
end, 'admin')

QC.Add('givemoney', 'Give a player money (admin)', { { name = 'id', help = 'Player id' },
    { name = 'moneytype', help = 'cash, bank, crypto' }, { name = 'amount', help = 'Amount' } }, true, function(src, args)
    local t = target(src, args[1])
    if t then CreateThread(function() B.addMoney(t, args[2], tonumber(args[3]), 'Admin give money') end) end
end, 'admin')

QC.Add('setmoney', 'Set a player\'s money (admin)', { { name = 'id', help = 'Player id' },
    { name = 'moneytype', help = 'cash, bank, crypto' }, { name = 'amount', help = 'Amount' } }, true, function(src, args)
    local t = target(src, args[1])
    if t then CreateThread(function() B.setMoney(t, args[2], tonumber(args[3]), 'Admin set money') end) end
end, 'admin')

QC.Add('job', 'Check your job', {}, false, function(src)
    local pl = B.Players[src]
    if not pl then return end
    local j = pl.PlayerData.job
    QF.Notify(src, ('Job: %s - %s (%s)'):format(j.label, j.grade.name, j.onduty and 'on duty' or 'off duty'), 'primary')
end, 'user')

QC.Add('setjob', 'Set a player\'s job (admin)', { { name = 'id', help = 'Player id' }, { name = 'job', help = 'Job name' },
    { name = 'grade', help = 'Grade' } }, true, function(src, args)
    local t = target(src, args[1])
    if t then
        CreateThread(function()
            local ok, why = B.setJob(t, args[2], tonumber(args[3]) or 0)
            if not ok then QF.Notify(src, why or 'Could not set job', 'error') end
        end)
    end
end, 'admin')

QC.Add('gang', 'Check your gang', {}, false, function(src)
    local pl = B.Players[src]
    if not pl then return end
    local g = pl.PlayerData.gang
    QF.Notify(src, ('Gang: %s - %s'):format(g.label, g.grade.name), 'primary')
end, 'user')

QC.Add('setgang', 'Set a player\'s gang (admin)', { { name = 'id', help = 'Player id' }, { name = 'gang', help = 'Gang name' },
    { name = 'grade', help = 'Grade' } }, true, function(src, args)
    local t = target(src, args[1])
    if t then
        CreateThread(function()
            local ok, why = B.setGang(t, args[2], tonumber(args[3]) or 0)
            if not ok then QF.Notify(src, why or 'Could not set gang', 'error') end
        end)
    end
end, 'admin')

QC.Add('ooc', 'OOC chat message', {}, false, function(src, args)
    local msg = table.concat(args, ' ')
    if msg == '' then return end
    local name = GetPlayerName(src)
    local c = GetEntityCoords(GetPlayerPed(src))
    for _, s in ipairs(GetPlayers()) do
        s = tonumber(s)
        if s == src or #(c - GetEntityCoords(GetPlayerPed(s))) < 20.0 or QF.HasPermission(s, 'admin') then
            TriggerClientEvent('chat:addMessage', s, { color = { 0, 0, 255 }, multiline = true, args = { 'OOC | ' .. name, msg } })
        end
    end
end, 'user')
