if (Config.BossMenu == 'auto' and not checkResource('esx_society')) or (Config.BossMenu ~= 'auto' and Config.BossMenu ~= 'esx_society') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[BossMenu] Loaded: esx_society')
end

Bridge.BossMenu = {}

Bridge.BossMenu.openMenu = function()
    local playerJob = Bridge.Framework.fetchPlayerJob()
    if not playerJob or not playerJob.name then
        Bridge.libs.print.error('No job found for the player')
        return
    end

    TriggerEvent('esx_society:openBossMenu', playerJob.name, function(data, menu)
        menu.close()
    end, {checkBal = true, withdraw = true, deposit = true, wash = true, employees = true, salary = true, grades = true})
end