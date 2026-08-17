if (Config.BossMenu == 'auto' and not checkResource('neon-boss')) or (Config.BossMenu ~= 'auto' and Config.BossMenu ~= 'neon-boss') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[BossMenu] Loaded: neon-boss')
end

Bridge.BossMenu = {}

Bridge.BossMenu.openMenu = function()
    local playerJob = Bridge.Framework.fetchPlayerJob()
    if not playerJob or not playerJob.name then
        Bridge.libs.print.error('No job found for the player')
        return
    end
    
    exports['neon-boss']:OpenBossMenu(playerJob.name, "society")
end