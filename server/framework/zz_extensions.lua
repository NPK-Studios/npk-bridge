Citizen.CreateThread(function()
    while not Bridge or not Bridge.Framework or not Bridge.Framework.getPlayerJob do
        Citizen.Wait(100)
    end

    --@param jobs: string|string[] [job name or array of job names]
    --@param onDutyOnly: boolean [if true, count only players on duty]
    --@return count: number
    Bridge.Framework.getJobCount = function(jobs, onDutyOnly)
        if type(jobs) == 'string' then jobs = { jobs } end
        if type(jobs) ~= 'table' or not jobs[1] then return 0 end

        local count = 0
        for _, src in ipairs(GetPlayers()) do
            local id = tonumber(src)
            if id then
                local job = Bridge.Framework.getPlayerJob and Bridge.Framework.getPlayerJob(id)
                if job and job.name then
                    for _, j in ipairs(jobs) do
                        if job.name == j then
                            local onDuty = true
                            if onDutyOnly and Bridge.Framework.CheckJobDuty then
                                onDuty = Bridge.Framework.CheckJobDuty(id) == true
                            end
                            if onDuty then
                                count = count + 1
                            end
                            break
                        end
                    end
                end
            end
        end

        return count
    end

    if Config.Debug then
        Bridge.libs.print.info('[Framework] Extensions loaded (getJobCount)')
    end
end)
