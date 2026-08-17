-- `Bridge or {}`, a nie `{}` — shared/libs.lua wykonuje sie WCZESNIEJ
-- (shared_scripts ladowane sa przed client/server_scripts) i wpisuje tam
-- juz Bridge.libs. Twarde `Bridge = {}` skasowaloby je.
Bridge = Bridge or {}

Bridge.Config = Config

function checkResource(resourceName)
    local state = GetResourceState(resourceName)
    return state ~= 'missing' and state ~= 'unknown'
end

exports('getObject', function()
    return Bridge
end)

Bridge.Callback = {}

local _pendingCallbacks = {}

RegisterNetEvent('npk-bridge:cbResponse', function(cbId, ...)
    if _pendingCallbacks[cbId] then
        _pendingCallbacks[cbId](...)
        _pendingCallbacks[cbId] = nil
    end
end)

function Bridge.Callback.await(name, ...)
    local cbId = tostring(GetGameTimer()) .. tostring(math.random(100000, 999999))
    local result = nil
    local done = false
    _pendingCallbacks[cbId] = function(...)
        result = {...}
        done = true
    end
    TriggerServerEvent(name, cbId, ...)
    repeat Citizen.Wait(0) until done
    if result then return table.unpack(result) end
end

function Bridge.Callback.register(name, fn)
    RegisterNetEvent(name, function(cbId, ...)
        local result = {fn(...)}
        TriggerServerEvent('npk-bridge:cbResponseServer', cbId, table.unpack(result))
    end)
end