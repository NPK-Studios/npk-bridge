if (Config.Radial == 'auto' and not checkResource('ox_lib')) or (Config.Radial ~= 'auto' and Config.Radial ~= 'ox_lib') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Radial] Loaded: ox_lib')
end

Bridge.Radial = {}

local owned = {}

local function remember(resourceName, id)
    if not resourceName or not id then return end
    owned[resourceName] = owned[resourceName] or {}
    owned[resourceName][id] = true
end

--@param items: table | table[] [{ id, label, icon, menu?, onSelect?, canInteract?, keepOpen? }]
Bridge.Radial.addItem = function(items)
    local resourceName = GetInvokingResource() or cache.resource
    local list = (type(items) == 'table' and items.id == nil) and items or { items }

    for i = 1, #list do
        remember(resourceName, list[i].id)
    end

    lib.addRadialItem(list)
end

--@param id: string | string[] [id pozycji do usuniecia]
Bridge.Radial.removeItem = function(id)
    local resourceName = GetInvokingResource() or cache.resource
    local list = type(id) == 'table' and id or { id }

    for i = 1, #list do
        lib.removeRadialItem(list[i])
        if owned[resourceName] then owned[resourceName][list[i]] = nil end
    end
end

--@param menu: table [{ id, items = { ... } }] — podmenu radiala
Bridge.Radial.registerMenu = function(menu)
    if type(menu) ~= 'table' or not menu.id then return end
    lib.registerRadial(menu)
end

--@return string|nil [id aktualnie otwartego podmenu]
Bridge.Radial.getCurrentId = function()
    return lib.getCurrentRadialId()
end

Bridge.Radial.hide = function()
    lib.hideRadial()
end

--@param state: boolean [true = radial dostepny]
Bridge.Radial.toggle = function(state)
    lib.disableRadial(not state)
end

--Usuwa wszystkie pozycje zarejestrowane przez wolajacy zasob.
Bridge.Radial.clear = function()
    local resourceName = GetInvokingResource() or cache.resource
    for id in pairs(owned[resourceName] or {}) do
        lib.removeRadialItem(id)
    end
    owned[resourceName] = nil
end

AddEventHandler('onClientResourceStop', function(resourceName)
    for id in pairs(owned[resourceName] or {}) do
        lib.removeRadialItem(id)
    end
    owned[resourceName] = nil
end)
