-- Narzedzia siedza pod glownym obiektem API (Bridge.libs), zeby bridge
-- wystawial JEDNA globalna zmienna zamiast dwoch.
Bridge = Bridge or {}
Bridge.libs = Bridge.libs or {}

local resourceName = (cache and cache.resource) or GetCurrentResourceName()

-------------------------------------------------------------------------------
-- Bridge.libs.print (from ox_lib: imports/print/shared.lua)
-------------------------------------------------------------------------------

local printLevel = {
    error   = 1,
    warn    = 2,
    info    = 3,
    verbose = 4,
    debug   = 5,
}

local levelPrefixes = {
    '^1[ERROR]',
    '^3[WARN]',
    '^7[INFO]',
    '^4[VERBOSE]',
    '^6[DEBUG]',
}

local template = ('^5[%s] %%s %%s^7'):format(resourceName)

local function handleException(reason, value)
    if type(value) == 'function' then return tostring(value) end
    return reason
end

local jsonOptions = { sort_keys = true, indent = true, exception = handleException }

local function libPrint(level, ...)
    local args = { ... }
    for i = 1, #args do
        local arg = args[i]
        args[i] = type(arg) == 'table' and json.encode(arg, jsonOptions) or tostring(arg)
    end
    print(template:format(levelPrefixes[level], table.concat(args, '\t')))
end

Bridge.libs.print = {
    error   = function(...) libPrint(printLevel.error,   ...) end,
    warn    = function(...) libPrint(printLevel.warn,    ...) end,
    info    = function(...) libPrint(printLevel.info,    ...) end,
    verbose = function(...) libPrint(printLevel.verbose, ...) end,
    debug   = function(...) libPrint(printLevel.debug,   ...) end,
}

-------------------------------------------------------------------------------
-- Bridge.libs.table extensions (from ox_lib: imports/table/shared.lua)
-------------------------------------------------------------------------------

Bridge.libs.table = Bridge.libs.table or table

---Compares if two values are equal, iterating over tables and matching both keys and values.
---@param t1 any
---@param t2 any
---@return boolean
local function table_matches(t1, t2)
    local type1, type2 = type(t1), type(t2)
    if type1 ~= type2 then return false end
    if type1 ~= 'table' and type2 ~= 'table' then return t1 == t2 end

    for k, v1 in pairs(t1) do
        local v2 = t2[k]
        if v2 == nil or not table_matches(v1, v2) then
            return false
        end
    end

    for k in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end

    return true
end

table.matches  = table_matches
Bridge.libs.table      = table
