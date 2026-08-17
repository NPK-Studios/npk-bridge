while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Anim] Loaded')
end

Bridge.Anim = {}

---@param dict string
---@param timeout? number  Approx milliseconds to wait (default 10000).
---@return string dict
Bridge.Anim.RequestDict = function(dict, timeout)
    if HasAnimDictLoaded(dict) then return dict end

    if not DoesAnimDictExist(dict) then
        error(("attempted to load invalid anim dict '%s'"):format(dict))
    end

    return Bridge.libs.streamingRequest(RequestAnimDict, HasAnimDictLoaded, 'anim dict', dict, timeout or 10000)
end

---@param data table
--- ped:          number?   Entity to play on (defaults to local player).
--- dict:         string    Animation dictionary.
--- name:         string    Animation name.
--- blendIn:      number?   Default 8.0
--- blendOut:     number?   Default -8.0
--- duration:     number?   Length in ms; -1 plays full animation. Default -1.
--- flag:         number?   Animation flag. Default 49 (upper body, looped, allow movement).
--- playbackRate: number?   Default 0.0
--- lockX:        boolean?  Default false
--- lockY:        boolean?  Default false
--- lockZ:        boolean?  Default false
--- freeze:       boolean?  Freezes ped during animation. Default false.
--- wait:         boolean?  If true, blocks until duration elapses. Default false.
---@return boolean started
Bridge.Anim.Play = function(data)
    if not data or not data.dict or not data.name then return false end

    local ped = data.ped or cache.ped or PlayerPedId()
    if not DoesEntityExist(ped) then return false end

    Bridge.Anim.RequestDict(data.dict)

    if data.freeze then
        FreezeEntityPosition(ped, true)
    end

    TaskPlayAnim(
        ped,
        data.dict,
        data.name,
        data.blendIn or 8.0,
        data.blendOut or -8.0,
        data.duration or -1,
        data.flag or 49,
        data.playbackRate or 0.0,
        data.lockX or false,
        data.lockY or false,
        data.lockZ or false
    )

    RemoveAnimDict(data.dict)

    if data.wait and data.duration and data.duration > 0 then
        Citizen.Wait(data.duration)
        if data.freeze then
            FreezeEntityPosition(ped, false)
        end
        Bridge.Anim.Stop(ped, data.dict, data.name, data.blendOut or -8.0)
    end

    return true
end

---@param ped? number
---@param dict? string
---@param name? string
---@param blendOut? number
Bridge.Anim.Stop = function(ped, dict, name, blendOut)
    ped = ped or cache.ped or PlayerPedId()
    if not DoesEntityExist(ped) then return end

    if dict and name then
        StopAnimTask(ped, dict, name, blendOut or -4.0)
    else
        ClearPedTasks(ped)
    end
end

---@param ped? number
---@param dict string
---@param name string
---@return boolean
Bridge.Anim.IsPlaying = function(ped, dict, name)
    ped = ped or cache.ped or PlayerPedId()
    if not DoesEntityExist(ped) then return false end
    return IsEntityPlayingAnim(ped, dict, name, 3)
end

---@param data table
--- ped:    number?   Entity to attach to (defaults to local player).
--- model:  string|number   Prop model.
--- bone:   number?   Bone index. Default 28422 (right hand).
--- offset: vector3?  Position offset. Default vec3(0,0,0).
--- rot:    vector3?  Rotation offset. Default vec3(0,0,0).
---@return number prop  Created prop entity (0 on failure).
Bridge.Anim.AttachProp = function(data)
    if not data or not data.model then return 0 end

    local ped = data.ped or cache.ped or PlayerPedId()
    if not DoesEntityExist(ped) then return 0 end

    local model = Bridge.libs.requestModel(data.model)
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    local bone = data.bone or 28422
    local offset = data.offset or vec3(0.0, 0.0, 0.0)
    local rot = data.rot or vec3(0.0, 0.0, 0.0)

    AttachEntityToEntity(
        prop, ped, GetPedBoneIndex(ped, bone),
        offset.x, offset.y, offset.z,
        rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(model)
    return prop
end

---@param prop number
Bridge.Anim.RemoveProp = function(prop)
    if prop and prop ~= 0 and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteObject(prop)
    end
end
