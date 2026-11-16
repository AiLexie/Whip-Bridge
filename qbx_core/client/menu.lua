local W = Whip.core

local menuToken = 0

local function runEntry(item)
    local p = item.params or {}
    if item.action ~= nil then return item.action(p.args) end
    if not p.event then return end
    if p.isServer then
        TriggerServerEvent(p.event, p.args)
    elseif p.isCommand then
        ExecuteCommand(p.event)
    elseif p.isQBCommand then
        TriggerServerEvent('QBCore:CallCommand', p.event, p.args)
    elseif p.isAction then
        p.event(p.args)
    else
        TriggerEvent(p.event, p.args)
    end
end

local function openMenu(menu, sort, skipFirst)
    if type(menu) ~= 'table' then return end
    local items = {}
    for i, it in ipairs(menu) do if not (skipFirst and i == 1) then items[#items + 1] = it end end
    if sort then
        table.sort(items, function(a, b)
            if a.isMenuHeader ~= b.isMenuHeader then return a.isMenuHeader == true end
            return tostring(a.header or '') < tostring(b.header or '')
        end)
    end
    local title, options, entries = Convert.menu(items)
    if #options == 0 then return end
    menuToken = menuToken + 1
    local token = menuToken
    CreateThread(function()
        local answer = W:Input(title, { { label = 'Choose', type = 'select', options = options, default = options[1].value } })
        if token ~= menuToken or not answer then
            TriggerEvent('qb-menu:client:menuClosed')
            return
        end
        local item = entries[tonumber(answer[1])]
        if item then runEntry(item) end
    end)
end

-- whip's dialog can't be closed from code, so closing just makes any choice still made in it a no-op.
local headerShown = false
local function closeMenu()
    menuToken = menuToken + 1
    if headerShown then W:HideText() headerShown = false end
end

local function showHeader(menu)
    local parts = {}
    for _, it in ipairs(menu or {}) do
        if it.header then parts[#parts + 1] = tostring(it.header) .. (it.txt and (': ' .. tostring(it.txt)) or '') end
    end
    if #parts > 0 then
        W:ShowText(table.concat(parts, '  |  '))
        headerShown = true
    end
end

exports('openMenu', openMenu)
exports('closeMenu', closeMenu)
exports('showHeader', showHeader)
RegisterNetEvent('qb-menu:client:openMenu', openMenu)
RegisterNetEvent('qb-menu:client:closeMenu', closeMenu)

local function showInput(data)
    data = data or {}
    local fields, readers = Convert.inputFields(data.inputs)
    if #fields == 0 then return nil end
    local answer = W:Input(data.header or 'Input', fields)
    if not answer then return nil end
    return Convert.inputResult(answer, readers)
end

exports('ShowInput', showInput)
