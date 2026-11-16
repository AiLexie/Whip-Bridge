-- require it, as qbx scripts do: logger.log({ source, event, message, webhook?, color?, tags? })
if not IsDuplicityVersion() then
    print('^1[qbx_core] the logger is server only^0')
    return
end

local COLORS = { default = 14423100, blue = 255, red = 16711680, green = 65280, white = 16777215, black = 0,
    orange = 16744192, yellow = 16776960, pink = 16761035, lightgreen = 65309 }

local function log(entry)
    local src = tonumber(entry.source)
    if src and GetPlayerName(src) then
        CreateThread(function()
            exports.whip_core:LogActivity(src, tostring(entry.event or 'log'), { detail = tostring(entry.message or '') })
        end)
    end
    print(('[%s] %s: %s'):format(tostring(entry.source), tostring(entry.event), tostring(entry.message)))
    if entry.webhook and entry.webhook ~= '' then
        local body = json.encode({
            content = entry.tags and table.concat(entry.tags, ' ') or nil,
            embeds = { { title = tostring(entry.event), description = tostring(entry.message),
                color = COLORS[entry.color] or COLORS.default, footer = { text = tostring(entry.source) } } },
        })
        PerformHttpRequest(entry.webhook, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
    end
end

return { log = log }
