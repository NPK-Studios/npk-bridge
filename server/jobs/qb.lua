if (Config.Framework == 'auto' and not checkResource('qb-core')) or (Config.Framework ~= 'auto' and Config.Framework ~= 'qb') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Jobs] Loaded: QBCore')
end

Bridge.Jobs = {}

local catalog = {}

local function decode(raw, fallback)
    if raw == nil or raw == '' then return fallback end
    if type(raw) == 'table' then return raw end
    local ok, decoded = pcall(json.decode, raw)
    if ok and decoded ~= nil then return decoded end
    return fallback
end

local function resolveUniqueId(player)
    if type(player) == 'string' then return player end
    return Bridge.Framework.getUniqueId(player, true)
end

--@return table [{ [job] = { name, label, grades = { [gradeStr] = { grade, name, label, salary } } } }]
Bridge.Jobs.refresh = function()
    local shared = QBCore.Shared.Jobs or {}
    local out = {}

    for name, job in pairs(shared) do
        out[name] = { name = name, label = job.label or name, grades = {} }
        for gradeKey, grade in pairs(job.grades or {}) do
            out[name].grades[tostring(gradeKey)] = {
                grade = tonumber(gradeKey) or 0,
                name = grade.name or ('grade' .. tostring(gradeKey)),
                label = grade.name or tostring(gradeKey),
                salary = tonumber(grade.payment) or 0,
            }
        end
    end

    catalog = out
    return catalog
end

--@return table [job catalog, refreshed on first use]
Bridge.Jobs.getAll = function()
    if not next(catalog) then Bridge.Jobs.refresh() end
    return catalog
end

--@param jobName: string
--@return table|nil
Bridge.Jobs.get = function(jobName)
    return Bridge.Jobs.getAll()[jobName]
end

--@param jobName: string
--@param grade: number|string|nil
--@return boolean
Bridge.Jobs.exists = function(jobName, grade)
    local job = Bridge.Jobs.get(jobName)
    if not job then return false end
    if grade == nil then return true end
    return job.grades[tostring(tonumber(grade) or 0)] ~= nil
end

--@param name: string
--@param label: string
--@param grades: table [list of { grade, name, label, salary? }]
--@return boolean
Bridge.Jobs.create = function(name, label, grades)
    if type(name) ~= 'string' or name == '' then return false end

    local definition = { label = label or name, defaultDuty = true, grades = {} }
    for _, grade in ipairs(grades or {}) do
        definition.grades[tostring(tonumber(grade.grade) or 0)] = {
            name = grade.label or grade.name or tostring(grade.grade or 0),
            payment = tonumber(grade.salary) or 0,
        }
    end

    local ok = pcall(function()
        QBCore.Functions.AddJob(name, definition)
    end)

    if ok then Bridge.Jobs.refresh() end
    return ok
end

--@param uniqueId: string [citizenid]
--@return table [list of { name, grade }]
Bridge.Jobs.getStored = function(uniqueId)
    local stored = decode(MySQL.scalar.await('SELECT jobs FROM players WHERE citizenid = ?', { uniqueId }), {})
    return type(stored) == 'table' and stored or {}
end

--@param uniqueId: string [citizenid]
--@param list: table [list of { name, grade }]
Bridge.Jobs.setStored = function(uniqueId, list)
    MySQL.update.await('UPDATE players SET jobs = ? WHERE citizenid = ?',
        { (#list > 0) and json.encode(list) or '[]', uniqueId })
end

--@param jobName: string
--@param grade: number|string
--@param dutytime: number|nil
--@return table
Bridge.Jobs.buildJobData = function(jobName, grade, dutytime)
    local job = Bridge.Jobs.get(jobName)
    local gradeKey = tostring(tonumber(grade) or 0)
    local gradeData = job and job.grades[gradeKey]

    return {
        name = jobName,
        label = job and job.label or jobName,
        grade = tonumber(grade) or 0,
        grade_name = gradeData and gradeData.name or ('grade' .. gradeKey),
        grade_label = gradeData and gradeData.label or gradeKey,
        salary = gradeData and gradeData.salary or 0,
        dutytime = tonumber(dutytime) or 0,
        status = 0,
    }
end

--@param player: number|string [player id or citizenid]
--@return table [{ [job] = { name, label, grade, grade_name, grade_label, dutytime } }]
Bridge.Jobs.getPlayerJobs = function(player)
    local uniqueId = resolveUniqueId(player)
    if not uniqueId then return {} end

    local dutytimes = Bridge.Metadata and Bridge.Metadata.get(uniqueId, 'dutytime') or {}
    if type(dutytimes) ~= 'table' then dutytimes = {} end

    local jobs = {}
    for _, entry in ipairs(Bridge.Jobs.getStored(uniqueId)) do
        if type(entry) == 'table' and entry.name then
            jobs[entry.name] = Bridge.Jobs.buildJobData(entry.name, entry.grade, tonumber(dutytimes[entry.name]) or 0)
        end
    end

    local primary = type(player) == 'number' and Bridge.Framework.getPlayerJob(player) or nil
    if primary and primary.name and primary.name ~= 'unemployed' and not jobs[primary.name] then
        jobs[primary.name] = Bridge.Jobs.buildJobData(primary.name, primary.grade, tonumber(dutytimes[primary.name]) or 0)
    end

    return jobs
end

--@param player: number|string
--@param jobName: string
--@param grade: number|string
--@return boolean
Bridge.Jobs.addJob = function(player, jobName, grade)
    local uniqueId = resolveUniqueId(player)
    if not uniqueId then return false end

    grade = tonumber(grade) or 0
    if not Bridge.Jobs.exists(jobName, grade) then
        Bridge.Jobs.refresh()
        if not Bridge.Jobs.exists(jobName, grade) then return false end
    end

    local stored = Bridge.Jobs.getStored(uniqueId)
    for _, entry in ipairs(stored) do
        if entry.name == jobName then
            return Bridge.Jobs.setGrade(player, jobName, grade)
        end
    end

    stored[#stored + 1] = { name = jobName, grade = grade }
    Bridge.Jobs.setStored(uniqueId, stored)

    local playerId = type(player) == 'number' and player or Bridge.Framework.getPlayerId(uniqueId)
    if playerId then
        Bridge.Framework.SetJob(playerId, jobName, grade)
    else
        Bridge.Framework.SetOfflineJob(uniqueId, jobName, grade)
    end

    TriggerEvent('npk-bridge/server/jobs/added', uniqueId, jobName, grade)
    return true
end

--@param player: number|string
--@param jobName: string
--@param grade: number|string
--@return boolean
Bridge.Jobs.setGrade = function(player, jobName, grade)
    local uniqueId = resolveUniqueId(player)
    if not uniqueId then return false end

    grade = tonumber(grade) or 0
    if not Bridge.Jobs.exists(jobName, grade) then
        Bridge.Jobs.refresh()
        if not Bridge.Jobs.exists(jobName, grade) then return false end
    end

    local stored = Bridge.Jobs.getStored(uniqueId)
    local found = false
    for index, entry in ipairs(stored) do
        if entry.name == jobName then
            stored[index].grade = grade
            found = true
            break
        end
    end
    if not found then return false end

    Bridge.Jobs.setStored(uniqueId, stored)

    local playerId = type(player) == 'number' and player or Bridge.Framework.getPlayerId(uniqueId)
    local current = playerId and Bridge.Framework.getPlayerJob(playerId)
    if playerId and current and current.name == jobName then
        Bridge.Framework.SetJob(playerId, jobName, grade)
    elseif not playerId then
        Bridge.Framework.SetOfflineJob(uniqueId, jobName, grade)
    end

    TriggerEvent('npk-bridge/server/jobs/updated', uniqueId, jobName, grade)
    return true
end

--@param player: number|string
--@param jobName: string
--@return boolean
Bridge.Jobs.removeJob = function(player, jobName)
    local uniqueId = resolveUniqueId(player)
    if not uniqueId then return false end

    local stored = Bridge.Jobs.getStored(uniqueId)
    local kept, removed = {}, false
    for _, entry in ipairs(stored) do
        if entry.name == jobName then removed = true else kept[#kept + 1] = entry end
    end
    if not removed then return false end

    Bridge.Jobs.setStored(uniqueId, kept)

    local fallback = kept[1]
    local playerId = type(player) == 'number' and player or Bridge.Framework.getPlayerId(uniqueId)
    local current = playerId and Bridge.Framework.getPlayerJob(playerId)

    if playerId and current and current.name == jobName then
        Bridge.Framework.SetJob(playerId, fallback and fallback.name or 'unemployed', fallback and fallback.grade or 0)
    elseif not playerId then
        Bridge.Framework.SetOfflineJob(uniqueId, fallback and fallback.name or 'unemployed', fallback and fallback.grade or 0)
    end

    TriggerEvent('npk-bridge/server/jobs/removed', uniqueId, jobName)
    return true
end

--@param player: number|string
--@param jobName: string
--@return boolean
Bridge.Jobs.hasJob = function(player, jobName)
    return Bridge.Jobs.getPlayerJobs(player)[jobName] ~= nil
end

--@param player: number|string
--@param jobName: string
--@return number [seconds on duty]
Bridge.Jobs.getDutyTime = function(player, jobName)
    local uniqueId = resolveUniqueId(player)
    if not uniqueId then return 0 end

    local dutytimes = Bridge.Metadata and Bridge.Metadata.get(uniqueId, 'dutytime') or {}
    if type(dutytimes) ~= 'table' then return 0 end
    return tonumber(dutytimes[jobName]) or 0
end

--@param jobName: string
--@return table[] [{ identifier, name, grade, online, source }]
Bridge.Jobs.getEmployees = function(jobName)
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo, jobs FROM players
        WHERE JSON_SEARCH(jobs, 'one', ?, NULL, '$[*].name') IS NOT NULL
        LIMIT 500
    ]], { jobName }) or {}

    local online = {}
    for _, src in ipairs(GetPlayers()) do
        local uniqueId = Bridge.Framework.getUniqueId(tonumber(src), true)
        if uniqueId then online[uniqueId] = tonumber(src) end
    end

    local out = {}
    for _, row in ipairs(rows) do
        local grade = 0
        for _, entry in ipairs(decode(row.jobs, {})) do
            if entry.name == jobName then grade = tonumber(entry.grade) or 0 break end
        end

        local charinfo = decode(row.charinfo, {}) or {}
        out[#out + 1] = {
            identifier = row.citizenid,
            name = (((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')),
            grade = grade,
            online = online[row.citizenid] ~= nil,
            source = online[row.citizenid],
        }
    end

    return out
end

CreateThread(function()
    while not Bridge.Framework or not QBCore do Wait(100) end
    Bridge.Jobs.refresh()
end)
