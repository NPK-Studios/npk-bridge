-- `Bridge or {}`, a nie `{}` — shared/libs.lua wykonuje sie WCZESNIEJ
-- (shared_scripts ladowane sa przed client/server_scripts) i wpisuje tam
-- juz Bridge.libs. Twarde `Bridge = {}` skasowaloby je.
Bridge = Bridge or {}

Bridge.Config = Config

function checkResource(resourceName)
    local state = GetResourceState(resourceName)
    return state ~= 'missing' and state ~= 'unknown'
end

exports('getObject', function() return Bridge end)

Bridge.Callback = {}
local _pendingServerCallbacks = {}

RegisterNetEvent('npk-bridge:cbResponseServer', function(cbId, ...)
    if _pendingServerCallbacks[cbId] then
        _pendingServerCallbacks[cbId](...)
        _pendingServerCallbacks[cbId] = nil
    end
end)

function Bridge.Callback.register(name, fn)
    RegisterNetEvent(name, function(cbId, ...)
        local src = source
        local result = {fn(src, ...)}
        TriggerClientEvent('npk-bridge:cbResponse', src, cbId, table.unpack(result))
    end)
end

function Bridge.Callback.await(name, playerId, ...)
    local cbId = tostring(GetGameTimer()) .. tostring(math.random(100000, 999999))
    local result = nil
    local done = false
    _pendingServerCallbacks[cbId] = function(...)
        result = {...}
        done = true
    end
    TriggerClientEvent(name, playerId, cbId, ...)
    local deadline = GetGameTimer() + 30000
    repeat Wait(0) until done or GetGameTimer() > deadline
    if result then return table.unpack(result) end
end

RegisterCommand('setup', function(source, args, raw)
    if not source or source == 0 then return end
    if not IsPlayerAceAllowed(source, 'command.setup') then return end
    TriggerClientEvent('npk-bridge/client/setup/start', source, args[1])
end, false)

RegisterNetEvent('npk-bridge/server/removeItem', function(itemName, amount, metadata)
    local _source = source
    if not itemName or type(itemName) ~= 'string' then return end
    if not amount or type(amount) ~= 'number' then amount = 1 end

    if Bridge.Inventory then
        Bridge.Inventory.removeItem(_source, itemName, amount, metadata)
    end
end)

Bridge.Callback.register('npk-bridge/server/getPlayerSkin', function(source)
    local _source = source
    if GetResourceState('tgiann-clothing') == 'started' then
        local xPlayer = Bridge.Framework.getPlayerById(_source)
        local result = MySQL.query.await('SELECT * FROM tgiann_skin WHERE citizenid = ?', { xPlayer.identifier })
        if result and result[1] then
            return json.decode(result[1].skin)
        end
    elseif GetResourceState('rcore_clothing') == 'started' then
        local identifier = Bridge.Framework.getUniqueId(_source)
        return exports["rcore_clothing"]:getSkinByIdentifier(identifier)
    end

    return nil
end)