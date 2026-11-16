function GetCoordsFromEntity(entity)
    local c = GetEntityCoords(entity)
    return vec4(c.x, c.y, c.z, GetEntityHeading(entity))
end

function GetPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return (GetVehicleNumberPlateText(vehicle):gsub('^%s*(.-)%s*$', '%1'))
end

function CommaValue(num)
    local s = tostring(num)
    local k
    repeat s, k = s:gsub('^(-?%d+)(%d%d%d)', '%1,%2') until k == 0
    return s
end

function string.split(str, delimiter)
    local out = {}
    for part in (str .. delimiter):gmatch('(.-)' .. delimiter:gsub('%p', '%%%0')) do out[#out + 1] = part end
    return out
end

function string.trim(str) return (str:gsub('^%s*(.-)%s*$', '%1')) end
function string.firstToUpper(str) return (str:gsub('^%l', string.upper)) end

function math.round(value, numDecimalPlaces)
    if not numDecimalPlaces then return math.floor(value + 0.5) end
    local m = 10 ^ numDecimalPlaces
    return math.floor(value * m + 0.5) / m
end

local LETTERS, DIGITS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz', '0123456789'
local function random(len, pool)
    local out = {}
    for i = 1, len do
        local k = math.random(1, #pool)
        out[i] = pool:sub(k, k)
    end
    return table.concat(out)
end
function RandomLetter(length) return random(length or 1, LETTERS) end
function RandomNumber(length) return random(length or 1, DIGITS) end
function RandomNumberOrLetter(length) return random(length or 1, LETTERS .. DIGITS) end

function GenerateRandomPlate(pattern)
    pattern = pattern or '11AAA111'
    return (pattern:gsub('.', function(c)
        if c == '1' then return RandomNumber(1) end
        if c == 'A' then return RandomLetter(1):upper() end
        if c == '.' then return RandomNumberOrLetter(1):upper() end
        return c
    end))
end

function MapTableBySubfield(subfield, tbl)
    local out = {}
    for _, v in pairs(tbl) do
        local key = v[subfield]
        if key ~= nil then
            out[key] = out[key] or {}
            out[key][#out[key] + 1] = v
        end
    end
    return out
end
