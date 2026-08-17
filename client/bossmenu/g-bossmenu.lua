if (Config.BossMenu == 'auto' and not checkResource('g-bossmenu')) or (Config.BossMenu ~= 'auto' and Config.BossMenu ~= 'g-bossmenu') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[BossMenu] Loaded: g-bossmenu')
end

Bridge.BossMenu = {}

Bridge.BossMenu.openMenu = function()
    local playerJob = Bridge.Framework.fetchPlayerJob()
    if not playerJob or not playerJob.name then
        Bridge.libs.print.error('No job found for the player')
        return
    end

    exports['g-bossmenu']:OpenBossmenu(playerJob.name)
end