if (Config.Framework == 'auto' and not checkResource('es_extended')) or (Config.Framework ~= 'auto' and Config.Framework ~= 'esx') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Metadata] Loaded: ESX')
end

Bridge.Metadata = {}

local function readOffline(uniqueId)
    local raw = MySQL.scalar.await('SELECT metadata FROM users WHERE identifier = ?', { uniqueId })
    if not raw or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    return (ok and type(decoded) == 'table') and decoded or {}
end

--@param player: number|string [player id or unique identifier]
--@param key: string
--@param subKey: string|nil
--@return any
Bridge.Metadata.get = function(player, key, subKey)
    if type(player) == 'number' then
        local xPlayer = Bridge.Framework.getPlayerById(player)
        if xPlayer and xPlayer.getMeta then
            local ok, value = pcall(xPlayer.getMeta, key, subKey)
            if ok then return value end
        end
    end

    local uniqueId = type(player) == 'string' and player or Bridge.Framework.getUniqueId(player)
    if not uniqueId then return nil end

    local metadata = readOffline(uniqueId)
    if key == nil then return metadata end

    local value = metadata[key]
    if subKey ~= nil and type(value) == 'table' then return value[subKey] end
    return value
end

--@param player: number|string [player id or unique identifier]
--@param key: string
--@param value: any [treated as a sub-key when subValue is given, matching ESX]
--@param subValue: any|nil
--@return boolean
Bridge.Metadata.set = function(player, key, value, subValue)
    if type(player) == 'number' then
        local xPlayer = Bridge.Framework.getPlayerById(player)
        if xPlayer and xPlayer.setMeta then
            local ok = pcall(xPlayer.setMeta, key, value, subValue)
            if ok then return true end
        end
    end

    local uniqueId = type(player) == 'string' and player or Bridge.Framework.getUniqueId(player)
    if not uniqueId then return false end

    local metadata = readOffline(uniqueId)
    if subValue == nil then
        metadata[key] = value
    else
        if type(metadata[key]) ~= 'table' then metadata[key] = {} end
        metadata[key][value] = subValue
    end

    MySQL.update.await('UPDATE users SET metadata = ? WHERE identifier = ?', { json.encode(metadata), uniqueId })
    return true
end
