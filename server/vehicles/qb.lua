if (Config.Framework == 'auto' and not checkResource('qb-core')) or (Config.Framework ~= 'auto' and Config.Framework ~= 'qb') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Vehicles] Loaded: QBCore')
end

Bridge.Vehicles = {}

local TABLE = 'player_vehicles'
local LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

local function randomize(pattern)
    local out = {}
    for i = 1, #pattern do
        local token = pattern:sub(i, i)
        if token == 'A' then
            local index = math.random(1, #LETTERS)
            out[i] = LETTERS:sub(index, index)
        elseif token == '1' then
            out[i] = tostring(math.random(0, 9))
        else
            out[i] = token
        end
    end
    return table.concat(out)
end

--@param plate: string
--@return boolean
Bridge.Vehicles.plateExists = function(plate)
    return MySQL.scalar.await(('SELECT plate FROM `%s` WHERE plate = ?'):format(TABLE), { plate }) ~= nil
end

--@param vin: string
--@return boolean
Bridge.Vehicles.vinExists = function(vin)
    local ok, existing = pcall(function()
        return MySQL.scalar.await(('SELECT vin FROM `%s` WHERE vin = ?'):format(TABLE), { vin })
    end)
    return ok and existing ~= nil
end

--@return string|nil [unique plate]
Bridge.Vehicles.generatePlate = function()
    for _ = 1, 40 do
        local plate = randomize('AA11AAA')
        if not Bridge.Vehicles.plateExists(plate) then return plate end
    end
    return nil
end

--@return string|nil [unique VIN]
Bridge.Vehicles.generateVIN = function()
    for _ = 1, 40 do
        local vin = randomize('AA11AA111111')
        if not Bridge.Vehicles.vinExists(vin) then return vin end
    end
    return nil
end

--@param owner: string [job name or citizenid]
--@return table[]
Bridge.Vehicles.getByOwner = function(owner)
    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT * FROM `%s` WHERE citizenid = ? LIMIT 500'):format(TABLE), { owner })
    end)
    return (ok and type(rows) == 'table') and rows or {}
end
