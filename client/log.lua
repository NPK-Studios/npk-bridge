-- Bridge.Log: ujednolicony logger dostepny dla wszystkich npk-* resources.
-- API: Bridge.Log.print(resource, level, msg, ...) lub Bridge.Log.create(resource):debug/info/warn/error.

while not Bridge do Wait(0) end

Bridge.Log = Bridge.Log or {}

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }

---@param resource string
---@param level 'debug'|'info'|'warn'|'error'
---@param message string
---@param ... any
function Bridge.Log.print(resource, level, message, ...)
    level = (level or 'info'):lower()
    if not LEVELS[level] then level = 'info' end

    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, message, ...)
        if ok then message = formatted end
    end

    local prefix = ('[%s] [%s]'):format(resource or 'unknown', level:upper())

    if Bridge.libs and Bridge.libs.print and Bridge.libs.print[level] then
        Bridge.libs.print[level](('%s %s'):format(prefix, message))
    else
        print(('%s %s'):format(prefix, message))
    end
end

---@param resource string
---@return table  logger with .debug/.info/.warn/.error
function Bridge.Log.create(resource)
    local self = {}

    function self.debug(msg, ...) Bridge.Log.print(resource, 'debug', msg, ...) end
    function self.info(msg, ...)  Bridge.Log.print(resource, 'info',  msg, ...) end
    function self.warn(msg, ...)  Bridge.Log.print(resource, 'warn',  msg, ...) end
    function self.error(msg, ...) Bridge.Log.print(resource, 'error', msg, ...) end

    return self
end
