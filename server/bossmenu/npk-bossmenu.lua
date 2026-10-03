if (Config.BossMenu == 'auto' and not checkResource('npk-bossmenu')) or (Config.BossMenu ~= 'auto' and Config.BossMenu ~= 'npk-bossmenu') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[BossMenu] Loaded: npk-bossmenu')
end

Bridge.BossMenu = {}

local RESOURCE = 'npk-bossmenu'

local function call(name, ...)
    if GetResourceState(RESOURCE) ~= 'started' then return nil end
    local ok, result = pcall(function(...) return exports[RESOURCE][name](exports[RESOURCE], ...) end, ...)
    if not ok then
        if Config.Debug then
            Bridge.libs.print.error(('[BossMenu] export %s:%s zawiodl: %s'):format(RESOURCE, name, tostring(result)))
        end
        return nil
    end
    return result
end

--@param playerId: number
--@param key: string [permission key, e.g. 'withdraw' or a module key like 'komis_sell']
--@return boolean|nil [nil when the boss menu does not manage the player's job]
Bridge.BossMenu.hasPermission = function(playerId, key)
    local result = call('hasPermission', playerId, key)
    if type(result) == 'boolean' then return result end
    return nil
end

--@param job: string
--@param kind: string [history type, e.g. 'sale', 'purchase', 'deposit']
--@param text: string
--@param amount: number|nil
--@param actor: string|nil
--@return boolean
Bridge.BossMenu.addHistory = function(job, kind, text, amount, actor)
    return call('addHistory', job, kind, text, amount, actor) == true
end
