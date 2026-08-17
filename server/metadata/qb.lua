if (Config.Framework == 'auto' and not checkResource('qb-core')) or (Config.Framework ~= 'auto' and Config.Framework ~= 'qb') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Metadata] Loaded: QBCore')
end

Bridge.Metadata = {}

local function readOffline(uniqueId)
    local raw = MySQL.scalar.await('SELECT metadata FROM players WHERE citizenid = ?', { uniqueId })
    if not raw or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    return (ok and type(decoded) == 'table') and decoded or {}
end

local function writeOffline(uniqueId, metadata)
    MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', { json.encode(metadata), uniqueId })
end

--@param player: number|string [player id or citizenid]
--@param key: string
--@param subKey: string|nil
--@return any
Bridge.Metadata.get = function(player, key, subKey)
    if type(player) == 'number' then
        local xPlayer = Bridge.Framework.getPlayerById(player)
        local metadata = xPlayer and xPlayer.PlayerData and xPlayer.PlayerData.metadata
        if metadata then
            if key == nil then return metadata end
            local value = metadata[key]
            if subKey ~= nil and type(value) == 'table' then return value[subKey] end
            return value
        end
    end

    local uniqueId = type(player) == 'string' and player or Bridge.Framework.getUniqueId(player, true)
    if not uniqueId then return nil end

    local metadata = readOffline(uniqueId)
    if key == nil then return metadata end

    local value = metadata[key]
    if subKey ~= nil and type(value) == 'table' then return value[subKey] end
    return value
end

--@param player: number|string [player id or citizenid]
--@param key: string
--@param value: any [treated as a sub-key when subValue is given]
--@param subValue: any|nil
--@return boolean
Bridge.Metadata.set = function(player, key, value, subValue)
    if type(player) == 'number' then
        local xPlayer = Bridge.Framework.getPlayerById(player)
        if xPlayer and xPlayer.Functions and xPlayer.Functions.SetMetaData then
            if subValue == nil then
                xPlayer.Functions.SetMetaData(key, value)
            else
                local current = xPlayer.PlayerData.metadata[key]
                if type(current) ~= 'table' then current = {} end
                current[value] = subValue
                xPlayer.Functions.SetMetaData(key, current)
            end
            return true
        end
    end

    local uniqueId = type(player) == 'string' and player or Bridge.Framework.getUniqueId(player, true)
    if not uniqueId then return false end

    local metadata = readOffline(uniqueId)
    if subValue == nil then
        metadata[key] = value
    else
        if type(metadata[key]) ~= 'table' then metadata[key] = {} end
        metadata[key][value] = subValue
    end

    writeOffline(uniqueId, metadata)
    return true
end
