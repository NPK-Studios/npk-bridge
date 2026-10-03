if (Config.BossMenu == 'auto' and not checkResource('npk-bossmenu')) or (Config.BossMenu ~= 'auto' and Config.BossMenu ~= 'npk-bossmenu') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[BossMenu] Loaded: npk-bossmenu')
end

Bridge.BossMenu = {}

Bridge.BossMenu.openMenu = function()
    exports['npk-bossmenu']:openBossMenu()
end
