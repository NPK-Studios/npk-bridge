while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Locale] Loaded')
end

Bridge.Locale = {}

local dicts = {}

local function flattenDict(source, target, prefix)
    for key, value in pairs(source) do
        local fullKey = prefix and (prefix .. '.' .. key) or key
        if type(value) == 'table' then
            flattenDict(value, target, fullKey)
        else
            target[fullKey] = value
        end
    end
    return target
end

local function loadFile(resource, lang)
    local data = LoadResourceFile(resource, ('locales/%s.json'):format(lang))
    if not data or data == '' then return nil end
    local ok, decoded = pcall(json.decode, data)
    if not ok or type(decoded) ~= 'table' then return nil end
    return decoded
end

---@param resource string
---@param lang? string  defaults to Config.Language
function Bridge.Locale.load(resource, lang)
    if not resource then
        if Bridge.libs and Bridge.libs.print and Bridge.libs.print.error then
            Bridge.libs.print.error('[Locale] load: brak nazwy zasobu')
        end
        return
    end
    lang = lang or Config.Language or 'en'

    local locales = loadFile(resource, 'en') or {}
    if lang ~= 'en' then
        local langData = loadFile(resource, lang)
        if langData then
            for k, v in pairs(langData) do locales[k] = v end
        end
    end

    local dict = {}
    flattenDict(locales, dict)

    for k, v in pairs(dict) do
        if type(v) == 'string' then
            for var in v:gmatch('${[%w%s%p]-}') do
                local sub = dict[var:sub(3, -2)]
                if sub then
                    dict[k] = v:gsub(var, sub:gsub('%%', '%%%%'))
                end
            end
        end
    end

    dicts[resource] = dict
end

---@param resource string
---@param key string
---@param ... string | number
---@return string
function Bridge.Locale.t(resource, key, ...)
    local dict = dicts[resource]
    if not dict then return key end
    local str = dict[key]
    if not str then return key end
    if ... then return str:format(...) end
    return str
end

---@param resource string
---@return table  with .load(lang?) and .t(key, ...) methods
function Bridge.Locale.create(resource)
    local self = {}

    function self.load(lang)
        Bridge.Locale.load(resource, lang)
    end

    function self.t(key, ...)
        return Bridge.Locale.t(resource, key, ...)
    end

    function self.has(key)
        return dicts[resource] and dicts[resource][key] ~= nil
    end

    return self
end

function Bridge.Locale.getDict(resource)
    return dicts[resource] or {}
end
