-- Offline lookups used by resources that need player data before he is loaded (queue, whitelist).

while not Bridge do
    Citizen.Wait(0)
end

Bridge.Framework = Bridge.Framework or {}

local framework

local function detect()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if checkResource('es_extended') then return 'esx' end
    if checkResource('qbx_core') then return 'qbox' end
    if checkResource('qb-core') then return 'qb' end
    if checkResource('ox_core') then return 'ox' end
    if checkResource('ND_Core') then return 'nd' end
    return 'standalone'
end

--@return name: string ['esx'|'qb'|'qbox'|'ox'|'nd'|'standalone']
Bridge.Framework.getName = function()
    if not framework then framework = detect() end
    return framework
end

local queries = {
    ['esx'] = function(license, hex)
        return MySQL.query.await('SELECT `group` AS name FROM `users` WHERE `identifier` = ? OR `identifier` LIKE ?', {
            license,
            ('%%%s'):format(hex)
        })
    end,
    ['ox'] = function(license, hex)
        return MySQL.query.await([[
            SELECT cg.name FROM character_groups cg
            INNER JOIN characters c ON c.charId = cg.charId
            INNER JOIN users u ON u.userId = c.userId
            WHERE u.license2 = ? OR u.license2 = ?
        ]], {
            license,
            hex
        })
    end
}

local function split(identifier)
    local hex = identifier:gsub('^license2?:', '')
    return identifier:find(':') and identifier or ('license:%s'):format(hex), hex
end

--@param identifier: string [license identifier, with or without the 'license:' prefix]
--@return jobs: table [job names of every character of that player]
Bridge.Framework.getOfflineJobs = function(identifier)
    if not identifier then return {} end

    local framework = Bridge.Framework.getName()

    if framework == 'ox' then
        return Bridge.Framework.getOfflineGroups(identifier)
    end

    local license, hex = split(identifier)
    local ok, rows

    if framework == 'esx' then
        ok, rows = pcall(MySQL.query.await, 'SELECT `job` FROM `users` WHERE `identifier` = ? OR `identifier` LIKE ?', {
            license,
            ('%%%s'):format(hex)
        })
    elseif framework == 'qb' or framework == 'qbox' then
        ok, rows = pcall(MySQL.query.await, 'SELECT `job` FROM `players` WHERE `license` = ?', { license })
    else
        return {}
    end

    if not ok or type(rows) ~= 'table' then
        if Config.Debug then
            Bridge.libs.print.error(('[Framework] getOfflineJobs failed: %s'):format(rows))
        end
        return {}
    end

    local jobs = {}

    for _, row in ipairs(rows) do
        local job = row.job

        if type(job) == 'string' and job:sub(1, 1) == '{' then
            local decoded, data = pcall(json.decode, job)
            job = decoded and type(data) == 'table' and data.name or nil
        end

        if job and job ~= '' then
            jobs[#jobs + 1] = job
        end
    end

    return jobs
end

--@param identifier: string [license identifier, with or without the 'license:' prefix]
--@return groups: table [group names owned by any character of that player, empty when the framework keeps groups outside the database]
Bridge.Framework.getOfflineGroups = function(identifier)
    if not identifier then return {} end

    local query = queries[Bridge.Framework.getName()]
    if not query then return {} end

    local hex = identifier:gsub('^license2?:', '')
    local license = identifier:find(':') and identifier or ('license:%s'):format(hex)

    local ok, rows = pcall(query, license, hex)

    if not ok or type(rows) ~= 'table' then
        if Config.Debug then
            Bridge.libs.print.error(('[Framework] getOfflineGroups failed: %s'):format(rows))
        end
        return {}
    end

    local groups = {}

    for _, row in ipairs(rows) do
        if row.name and row.name ~= '' then
            groups[#groups + 1] = row.name
        end
    end

    return groups
end
