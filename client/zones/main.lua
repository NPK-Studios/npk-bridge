while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Zones] Loaded: ox_lib passthrough')
end

Bridge.Zones = {
    box    = lib.zones.box,
    sphere = lib.zones.sphere,
    poly   = lib.zones.poly,
    remove = function(zone)
        if zone and zone.remove then zone:remove() end
    end,
    getAll     = lib.zones.getAllZones,
    getCurrent = lib.zones.getCurrentZones,
    getNearby  = lib.zones.getNearbyZones,
}
