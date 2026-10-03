if (Config.Framework == 'auto' and not checkResource('es_extended')) or (Config.Framework ~= 'auto' and Config.Framework ~= 'esx') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Vehicles] Loaded: ESX')
end

Bridge.Vehicles = {}

local TABLE = 'owned_vehicles'
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

--@param owner: string [job name or player identifier]
--@return table[]
Bridge.Vehicles.getByOwner = function(owner)
    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT * FROM `%s` WHERE owner = ? LIMIT 500'):format(TABLE), { owner })
    end)
    return (ok and type(rows) == 'table') and rows or {}
end

local SPAWN_TIMEOUT = 15000
local TYPE_TIMEOUT = 10000

--@param model: string|number [vehicle model name or hash]
--@param coords: vector3|vector4|table [spawn position]
--@param heading: number|nil [defaults to coords.w]
--@param props: table|nil [vehicle properties applied by es_extended]
--@return netId: number|nil
Bridge.Vehicles.spawn = function(model, coords, heading, props)
    if not model or not coords then return nil end

    local valid, point = pcall(function()
        return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end)
    if not valid then return nil end

    if heading == nil and type(coords) ~= 'vector3' then
        local read, w = pcall(function() return coords.w end)
        heading = read and w or nil
    end

    local p = promise.new()
    local settled = false
    local called = pcall(ESX.OneSync.SpawnVehicle, model, point, (tonumber(heading) or 0.0) + 0.0, props, function(netId)
        if settled then
            local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
            if entity > 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
            return
        end
        settled = true
        p:resolve(netId)
    end)
    if not called then return nil end

    SetTimeout(SPAWN_TIMEOUT, function()
        if settled then return end
        settled = true
        p:resolve(nil)
    end)

    return tonumber(Citizen.Await(p))
end

--@param owner: string [owned_vehicles.owner, the row must have stored = 1]
--@param plate: string
--@param coords: vector4|table [spawn position with heading in w]
--@return netId: number|nil
Bridge.Vehicles.spawnOwned = function(owner, plate, coords)
    if type(owner) ~= 'string' or type(plate) ~= 'string' or not coords then return nil end

    local valid, point = pcall(function()
        local w = type(coords) ~= 'vector3' and tonumber(coords.w) or 0.0
        return vector4(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, w + 0.0)
    end)
    if not valid then return nil end

    local created, xVehicle = pcall(ESX.CreateExtendedVehicle, owner, plate, point)
    if not created or not xVehicle then return nil end

    local ok, netId = pcall(function() return xVehicle:getNetId() end)
    return ok and tonumber(netId) or nil
end

--@param plate: string
--@return boolean [true if a spawned ESX owned vehicle was found and deleted]
Bridge.Vehicles.despawnOwned = function(plate)
    if type(plate) ~= 'string' then return false end

    local found, xVehicle = pcall(ESX.GetExtendedVehicleFromPlate, plate)
    if not found or not xVehicle then return false end

    return (pcall(function() xVehicle:delete() end))
end

--@param model: string|number [vehicle model name or hash]
--@param playerId: number [player whose client resolves the type when it is not cached]
--@return vehicleType: string|nil ['automobile', 'bike', 'boat', 'heli', 'plane', ...]
Bridge.Vehicles.getType = function(model, playerId)
    if not model then return nil end

    local p = promise.new()
    local settled = false
    local called = pcall(ESX.GetVehicleType, model, tonumber(playerId), function(vehicleType)
        if settled then return end
        settled = true
        p:resolve(vehicleType)
    end)
    if not called then return nil end

    if not settled then
        SetTimeout(TYPE_TIMEOUT, function()
            if settled then return end
            settled = true
            p:resolve(nil)
        end)
    end

    local result = Citizen.Await(p)
    return type(result) == 'string' and result or nil
end

local OPTIONAL_COLUMNS = { 'parking', 'pound', 'vin', 'co_owner', 'mdt_assigned', 'mdt_assigned_name', 'mileage' }
local CLEARED_ON_TRANSFER = { 'pound', 'co_owner', 'mdt_assigned', 'mdt_assigned_name' }
local columns = nil
local columnsLoading = nil

local function readColumns()
    local found = {}
    local ok, rows = pcall(MySQL.query.await, [[
        SELECT COLUMN_NAME AS name FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
    ]], { TABLE })
    for _, row in ipairs(ok and rows or {}) do
        if row.name then found[tostring(row.name):lower()] = true end
    end
    return found
end

Bridge.Vehicles.ensureColumns = function()
    if columns then return columns end
    if columnsLoading then
        Citizen.Await(columnsLoading)
        return columns or {}
    end

    columnsLoading = promise.new()
    local found = readColumns()
    if not found.mileage then
        pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `mileage` FLOAT NOT NULL DEFAULT 0'):format(TABLE))
    end
    if not found.vin then
        pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `vin` VARCHAR(24) NULL DEFAULT NULL'):format(TABLE))
    end
    if not found.mileage or not found.vin then
        found = readColumns()
    end

    columns = {}
    for _, name in ipairs(OPTIONAL_COLUMNS) do
        columns[name] = found[name] == true
    end
    columnsLoading:resolve(true)
    columnsLoading = nil
    return columns
end

--@param name: string [column name, e.g. 'parking', 'vin', 'mileage']
--@return boolean
Bridge.Vehicles.hasColumn = function(name)
    return Bridge.Vehicles.ensureColumns()[name] == true
end

local function toRecord(row)
    local ok, props = pcall(json.decode, row.vehicle or '{}')
    return {
        plate = row.plate,
        owner = row.owner,
        job = row.job,
        type = row.type,
        stored = tonumber(row.stored) or 0,
        props = ok and type(props) == 'table' and props or {},
        mileage = tonumber(row.mileage) or 0,
        vin = row.vin,
    }
end

local function selectColumns()
    local cols = Bridge.Vehicles.ensureColumns()
    local list = { '`plate`', '`owner`', '`job`', '`type`', '`stored`', '`vehicle`' }
    if cols.mileage then list[#list + 1] = '`mileage`' end
    if cols.vin then list[#list + 1] = '`vin`' end
    return table.concat(list, ', ')
end

--@param plate: string
--@return { plate, owner, job, type, stored, props, mileage, vin }|nil
Bridge.Vehicles.getOwned = function(plate)
    if type(plate) ~= 'string' then return nil end
    local ok, row = pcall(MySQL.single.await, ('SELECT %s FROM `%s` WHERE plate = ? LIMIT 1'):format(selectColumns(), TABLE), { plate })
    return ok and row and toRecord(row) or nil
end

--@param owner: string [player identifier or company owner name]
--@return table[] [records like getOwned]
Bridge.Vehicles.getOwnedList = function(owner)
    if type(owner) ~= 'string' then return {} end
    local ok, rows = pcall(MySQL.query.await, ('SELECT %s FROM `%s` WHERE owner = ?'):format(selectColumns(), TABLE), { owner })
    local list = {}
    for _, row in ipairs(ok and rows or {}) do
        list[#list + 1] = toRecord(row)
    end
    return list
end

--@param data: table [{ owner, job?, plate, props, type?, stored?, vin?, mileage?, parking? }]
--@return boolean
Bridge.Vehicles.insertOwned = function(data)
    if type(data) ~= 'table' or type(data.owner) ~= 'string' or type(data.plate) ~= 'string' then return false end
    local cols = Bridge.Vehicles.ensureColumns()

    local names = { '`owner`', '`job`', '`plate`', '`vehicle`', '`type`', '`stored`' }
    local values = { data.owner, data.job, data.plate, json.encode(data.props or {}), data.type or 'car', tonumber(data.stored) or 1 }
    for _, name in ipairs({ 'vin', 'mileage', 'parking' }) do
        if data[name] ~= nil and cols[name] then
            names[#names + 1] = ('`%s`'):format(name)
            values[#values + 1] = data[name]
        end
    end

    local marks = {}
    for index = 1, #values do marks[index] = '?' end

    local ok, result = pcall(MySQL.insert.await, ('INSERT INTO `%s` (%s) VALUES (%s)'):format(TABLE, table.concat(names, ', '), table.concat(marks, ', ')), values)
    return ok and result ~= nil
end

--@param plate: string
--@param data: table [{ owner, job?, stored?, parking?, props?, fromOwner?, fromJob?, requireNoJob? }]
--@return changed: number [rows changed]
Bridge.Vehicles.transfer = function(plate, data)
    if type(plate) ~= 'string' or type(data) ~= 'table' or type(data.owner) ~= 'string' then return 0 end
    local cols = Bridge.Vehicles.ensureColumns()

    local sets = { '`owner` = ?', '`job` = ?', '`stored` = ?' }
    local values = { data.owner, data.job, tonumber(data.stored) or 1 }
    if cols.parking then
        sets[#sets + 1] = '`parking` = ?'
        values[#values + 1] = data.parking
    end
    for _, name in ipairs(CLEARED_ON_TRANSFER) do
        if cols[name] then sets[#sets + 1] = ('`%s` = NULL'):format(name) end
    end
    if type(data.props) == 'table' then
        sets[#sets + 1] = '`vehicle` = ?'
        values[#values + 1] = json.encode(data.props)
    end

    local where = { '`plate` = ?' }
    values[#values + 1] = plate
    if data.fromOwner then
        where[#where + 1] = '`owner` = ?'
        values[#values + 1] = data.fromOwner
    end
    if data.fromJob then
        where[#where + 1] = '`job` = ?'
        values[#values + 1] = data.fromJob
    end
    if data.requireNoJob then
        where[#where + 1] = "(`job` IS NULL OR `job` = '')"
    end

    local ok, changed = pcall(MySQL.update.await, ('UPDATE `%s` SET %s WHERE %s'):format(TABLE, table.concat(sets, ', '), table.concat(where, ' AND ')), values)
    return ok and tonumber(changed) or 0
end
