-- Bridge.Modules: dynamiczny loader plikow Lua z dowolnego zasobu, z cache i _ENV.
-- API: Bridge.Modules.load(resource, path) lub Bridge.Modules.create(resource):load(path).

while not Bridge do Wait(0) end

Bridge.Modules = Bridge.Modules or {}

local cache = {}

local function normalize(path)
    local normalized = path:gsub('%.', '/')
    if not normalized:match('%.lua$') then
        normalized = normalized .. '.lua'
    end
    return normalized
end

---@param resource string
---@param path string
---@return any
function Bridge.Modules.load(resource, path)
    if type(resource) ~= 'string' or resource == '' then
        error('Bridge.Modules.load: invalid resource name')
    end
    if type(path) ~= 'string' or path == '' then
        error('Bridge.Modules.load: invalid module path')
    end

    local normalized = normalize(path)
    local key = resource .. ':' .. normalized

    local cached = cache[key]
    if cached ~= nil then return cached end

    local source = LoadResourceFile(resource, normalized)
    if not source then
        error(('Bridge.Modules.load: module not found: %s/%s'):format(resource, normalized))
    end

    local chunk, err = load(source, ('@%s/%s'):format(resource, normalized), 't', _ENV)
    if not chunk then
        error(('Bridge.Modules.load: compile failed for %s/%s: %s'):format(resource, normalized, err))
    end

    local ok, result = pcall(chunk)
    if not ok then
        error(('Bridge.Modules.load: execute failed for %s/%s: %s'):format(resource, normalized, result))
    end

    cache[key] = (result == nil) and true or result
    return result
end

---@param resource string
---@return table  with .load(path) method
function Bridge.Modules.create(resource)
    local self = {}

    function self.load(path)
        return Bridge.Modules.load(resource, path)
    end

    return self
end
