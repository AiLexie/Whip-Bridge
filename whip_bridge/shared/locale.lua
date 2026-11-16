-- qb scripts call Locale:new(...) with a colon; Locale.new works too.
Locale = {}
Locale.__index = Locale

function Locale.new(a, b)
    local opts = (a == Locale or b ~= nil) and b or a
    opts = opts or {}
    local self = setmetatable({}, Locale)
    self.fallback = opts.fallbackLang and Locale.new({ warnOnMissing = false, phrases = opts.fallbackLang.phrases }) or false
    if type(opts.warnOnMissing) == 'boolean' then self.warnOnMissing = opts.warnOnMissing else self.warnOnMissing = true end
    self.phrases = {}
    self:extend(opts.phrases or {})
    return self
end

function Locale:extend(phrases, prefix)
    for key, phrase in pairs(phrases or {}) do
        local full = prefix and (prefix .. '.' .. key) or key
        if type(phrase) == 'table' then self:extend(phrase, full) else self.phrases[full] = phrase end
    end
end

function Locale:clear()
    self.phrases = {}
end

function Locale:replace(phrases)
    self:clear()
    self:extend(phrases or {})
end

function Locale:locale(newLocale)
    if newLocale then self.currentLocale = newLocale end
    return self.currentLocale
end

function Locale:has(key)
    return self.phrases[key] ~= nil
end

function Locale:delete(target, prefix)
    if type(target) == 'string' then
        self.phrases[target] = nil
        return
    end
    for key, phrase in pairs(target or {}) do
        local full = prefix and (prefix .. '.' .. key) or key
        if type(phrase) == 'table' then self:delete(phrase, full) else self.phrases[full] = nil end
    end
end

function Locale:t(key, subs)
    local phrase = self.phrases[key]
    if type(phrase) ~= 'string' then
        if self.warnOnMissing then print(('^3[Locale] missing phrase "%s"^0'):format(key)) end
        if self.fallback then return self.fallback:t(key, subs) end
        return key
    end
    if not subs then return phrase end
    return (phrase:gsub('%%{(.-)}', function(name)
        local v = subs[name]
        if v == nil then return '%{' .. name .. '}' end
        return tostring(v)
    end))
end
