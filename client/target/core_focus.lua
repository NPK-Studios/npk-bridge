if (Config.Target == 'auto' and checkResource('core_focus')) or (Config.Target ~= 'auto' and Config.Target ~= 'core_focus') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Target] Loaded: core_focus')
end

Bridge.Target = {}

--@param state: boolean [enable or disable target system]
Bridge.Target.toggleTarget = function(state)
    exports['qb-target']:AllowTargeting(state)
end

Bridge.Target.addGlobal = function(options)
    return 'textUI' -- dont touch it
end

--@param optionNames: string | string[] [names of the options to remove]
Bridge.Target.removeGlobal = function(optionNames)
    -- qb-target doesnt support global, scripts use text ui instead
end


--@param options: table [options for the target, see qb-target documentation for details]
Bridge.Target.addPlayer = function(options)
    for i = 1, #options do
        if options[i].onSelect then
            options[i].action = options[i].onSelect
        end
        if options[i].groups then
            local jobs = {}
            for k, v in pairs(options[i].groups) do
                if type(v) == 'string' then
                    jobs[v] = 0
                else
                    jobs = options[i].groups
                    break
                end
            end
            options[i].job = jobs
        end
        if options[i].items then
            options[i].item = options[i].items
        end
    end
    exports['core_focus']:AddGlobalPlayer({
        options = options,
        distance = options[1]?.distance or 2.0,
    })
end

--@param optionNames: string | string[] [names of the options to remove]
Bridge.Target.removePlayer = function(optionNames)
    exports['core_focus']:RemoveGlobalPlayer(optionNames)
end

--@param options: table [options for the target, see qb-target documentation for details]
Bridge.Target.addVehicle = function(options)
    for i = 1, #options do
        if options[i].onSelect then
            options[i].action = options[i].onSelect
        end
        if options[i].groups then
            local jobs = {}
            for k, v in pairs(options[i].groups) do
                if type(v) == 'string' then
                    jobs[v] = 0
                else
                    jobs = options[i].groups
                    break
                end
            end
            options[i].job = jobs
        end
        if options[i].items then
            options[i].item = options[i].items
        end
    end
    exports['core_focus']:AddGlobalVehicle({
        options = options,
        distance = options[1]?.distance or 2.0,
    })
end

--@param optionNames: string | string[] [names of the options to remove]
Bridge.Target.removeVehicle = function(optionNames)
    exports['core_focus']:RemoveGlobalVehicle(optionNames)
end

--@param models: number | string | number[] | string[] | Array<number | string>
--@param options: table [options for the target, see qb-target documentation for details]
Bridge.Target.addModel = function(models, options)
    for i = 1, #options do
        if options[i].onSelect then
            options[i].action = options[i].onSelect
        end
        if options[i].groups then
            local jobs = {}
            for k, v in pairs(options[i].groups) do
                if type(v) == 'string' then
                    jobs[v] = 0
                else
                    jobs = options[i].groups
                    break
                end
            end
            options[i].job = jobs
        end
        if options[i].items then
            options[i].item = options[i].items
        end
    end
    exports['core_focus']:AddTargetModel(models, {
        options = options,
        distance = options[1]?.distance or 2.0,
    })
end

--@param models: number | string | number[] | string[] | Array<number | string>
--@param optionNames: string | string[] [names of the options to remove]
Bridge.Target.removeModel = function(models, optionNames)
    exports['core_focus']:RemoveTargetModel(models, optionNames)
end

--@param netIds: number | number[]
--@param options: table [options for the target, see qb-target documentation for details]
Bridge.Target.addEntity = function(netIds, options)
    local entities = {}
    if type(netIds) == 'number' then
        entities[1] = NetworkGetEntityFromNetworkId(netIds)
    else
        for i = 1, #netIds do
            entities[i] = NetworkGetEntityFromNetworkId(netIds[i])
        end
    end

    for i = 1, #options do
        if options[i].onSelect then
            options[i].action = options[i].onSelect
        end
        if options[i].groups then
            local jobs = {}
            for k, v in pairs(options[i].groups) do
                if type(v) == 'string' then
                    jobs[v] = 0
                else
                    jobs = options[i].groups
                    break
                end
            end
            options[i].job = jobs
        end
        if options[i].items then
            options[i].item = options[i].items
        end
    end
    exports['core_focus']:AddTargetEntity(netIds, {
        options = options,
        distance = options[1]?.distance or 2.0,
    })
end

--@param netIds: number | number[]
--@param optionNames: string | string[] [names of the options to remove]
Bridge.Target.removeEntity = function(netIds, optionNames)
    local entities = {}
    if type(netIds) == 'number' then
        entities[1] = NetworkGetEntityFromNetworkId(netIds)
    else
        for i = 1, #netIds do
            entities[i] = NetworkGetEntityFromNetworkId(netIds[i])
        end
    end
    exports['core_focus']:RemoveTargetEntity(entities, optionNames)
end


--@param entities: number | number[]
--@param options: table [options for the target, see ox_target documentation for details]
Bridge.Target.addLocalEntity = function(entities, options)
    for i = 1, #options do
        if options[i].onSelect then
            options[i].action = options[i].onSelect
        end
        if options[i].groups then
            local jobs = {}
            for k, v in pairs(options[i].groups) do
                if type(v) == 'string' then
                    jobs[v] = 0
                else
                    jobs = options[i].groups
                    break
                end
            end
            options[i].job = jobs
        end
        if options[i].items then
            options[i].item = options[i].items
        end
    end
    exports['core_focus']:AddTargetEntity(entities, {
        options = options,
        distance = options[1]?.distance or 2.0,
    })
end

--@param entities: number | number[]
--@param optionNames: string | string[] [names of the options to remove]
Bridge.Target.removeLocalEntity = function(entities, optionNames)
    exports['core_focus']:RemoveTargetEntity(entities, optionNames)
end

--@param parameters: table [coords: vector3, name?: string, radius?: string, debug?: boolean, drawSprite?: boolean, options: table]
Bridge.Target.addSphereZone = function(parameters)
    for i = 1, #parameters.options do
        if parameters.options[i].onSelect then
            parameters.options[i].action = parameters.options[i].onSelect
        end
        if parameters.options[i].groups then
            local jobs = {}
            for k, v in pairs(parameters.options[i].groups) do
                if type(v) == 'string' then
                    jobs[v] = 0
                else
                    jobs = parameters.options[i].groups
                    break
                end
            end
            parameters.options[i].job = jobs
        end
        if parameters.options[i].items then
            parameters.options[i].item = parameters.options[i].items
        end
    end
    local invoker = GetInvokingResource() or GetCurrentResourceName()
    local targetName = ('%s_%s_%s'):format(invoker, 'sphere', tostring(math.random(11111111, 99999999)))
    exports['core_focus']:AddCircleZone(targetName, parameters.coords, parameters.radius or 1.0, {
        name = targetName,
        debugPoly = Config.Debug,
        drawSprite = parameters.drawSprite or false,
    }, {
        options = parameters.options,
        distance = parameters.options[1]?.distance or 2.0
    })
    return targetName
end

--@param id: number or string [id of the zone to remove]
Bridge.Target.removeSphereZone = function(id)
    exports['qb-target']:RemoveZone(id)
end

--@param parameters: table [coords: vector3, size?: vector3 | { x|length, y|width, z|height }, heading|rotation?: number, minZ?: number, maxZ?: number, debug?: boolean, options: table]
Bridge.Target.addBoxZone = function(parameters)
    for i = 1, #parameters.options do
        if parameters.options[i].onSelect then
            parameters.options[i].action = parameters.options[i].onSelect
        end
        if parameters.options[i].groups then
            local jobs = {}
            for k, v in pairs(parameters.options[i].groups) do
                if type(v) == 'string' then
                    jobs[v] = 0
                else
                    jobs = parameters.options[i].groups
                    break
                end
            end
            parameters.options[i].job = jobs
        end
        if parameters.options[i].items then
            parameters.options[i].item = parameters.options[i].items
        end
    end

    local size = parameters.size
    local length, width, height
    if type(size) == 'vector3' or (type(size) == 'table' and size.x) then
        length, width, height = size.x or size[1], size.y or size[2], size.z or size[3]
    elseif type(size) == 'table' then
        length, width, height = size.length or size[1], size.width or size[2], size.height or size[3]
    end

    length = (length or parameters.length or 1.0) + 0.0
    width = (width or parameters.width or 1.0) + 0.0
    height = (height or parameters.height or 2.0) + 0.0

    local heading = parameters.heading or parameters.rotation or 0.0
    local centerZ = parameters.coords.z
    local minZ = parameters.minZ or (centerZ - height / 2)
    local maxZ = parameters.maxZ or (centerZ + height / 2)

    local invoker = GetInvokingResource() or GetCurrentResourceName()
    local targetName = ('%s_%s_%s'):format(invoker, 'box', tostring(math.random(11111111, 99999999)))
    exports['core_focus']:AddBoxZone(targetName, parameters.coords, length, width, {
        name = targetName,
        heading = heading,
        minZ = minZ,
        maxZ = maxZ,
        debugPoly = parameters.debug or Config.Debug or false,
    }, {
        options = parameters.options,
        distance = parameters.options[1]?.distance or 2.0
    })
    return targetName
end

--@param id: number or string [id of the zone to remove]
Bridge.Target.removeBoxZone = function(id)
    exports['qb-target']:RemoveZone(id)
end