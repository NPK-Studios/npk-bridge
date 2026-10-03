while not Bridge do
    Citizen.Wait(0)
end

Bridge.Utils = {}

Bridge.Utils.getNetIdFromEntity = function(entity)
    local timer = 0
    local netId = NetworkGetNetworkIdFromEntity(entity)
    while netId == 0 do
        Citizen.Wait(100)
        netId = NetworkGetNetworkIdFromEntity(entity)
        timer += 1
        if timer >= 20 then
            break
        end
    end

    return netId
end

Bridge.Utils.getEntityFromNetId = function(netId)
    local timer = 0
    local entity = NetworkGetEntityFromNetworkId(netId)
    while entity == 0 do
        Citizen.Wait(100)
        entity = NetworkGetEntityFromNetworkId(netId)
        timer += 1
        if timer >= 20 then
            break
        end
    end

    return entity
end

--@param vehicle: number [vehicle entity]
--@return props: table|nil
Bridge.Utils.getVehicleProperties = function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    local ok, props = pcall(function()
        if lib and lib.getVehicleProperties then return lib.getVehicleProperties(vehicle) end
        if ESX and ESX.Game then return ESX.Game.GetVehicleProperties(vehicle) end
    end)
    return ok and type(props) == 'table' and props or nil
end

--@param vehicle: number [vehicle entity]
--@param props: table
--@return boolean
Bridge.Utils.setVehicleProperties = function(vehicle, props)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or type(props) ~= 'table' then return false end
    local ok, result = pcall(function()
        if lib and lib.setVehicleProperties then return lib.setVehicleProperties(vehicle, props) end
        if ESX and ESX.Game then
            ESX.Game.SetVehicleProperties(vehicle, props)
            return true
        end
        return false
    end)
    return ok and result ~= false
end

--@param coords: vector3
--@param maxDistance: number
--@param includePlayerVehicle: boolean|nil
--@return vehicle: number|nil
Bridge.Utils.getClosestVehicle = function(coords, maxDistance, includePlayerVehicle)
    local current = GetVehiclePedIsIn(PlayerPedId(), false)
    local closest, closestDistance = nil, maxDistance or 2.0
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if includePlayerVehicle or vehicle ~= current then
            local distance = #(coords - GetEntityCoords(vehicle))
            if distance < closestDistance then
                closest, closestDistance = vehicle, distance
            end
        end
    end
    return closest
end

--@param coords: vector3
--@param maxDistance: number
--@param includeSelf: boolean|nil
--@return playerIndex: number|nil [client player index, use GetPlayerServerId for the server id]
Bridge.Utils.getClosestPlayer = function(coords, maxDistance, includeSelf)
    local self = PlayerId()
    local closest, closestDistance = nil, maxDistance or 2.0
    for _, player in ipairs(GetActivePlayers()) do
        if includeSelf or player ~= self then
            local distance = #(coords - GetEntityCoords(GetPlayerPed(player)))
            if distance < closestDistance then
                closest, closestDistance = player, distance
            end
        end
    end
    return closest
end

Bridge.Debug = function(...)
    if Config.Debug then
        print('[Debug]', ...)
    end
end