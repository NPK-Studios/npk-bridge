-- Narzedzia siedza pod glownym obiektem API (Bridge.libs), zeby bridge
-- wystawial JEDNA globalna zmienna zamiast dwoch.
Bridge = Bridge or {}
Bridge.libs = Bridge.libs or {}

---@async
---@param request function
---@param hasLoaded function
---@param assetType string
---@param asset string | number
---@param timeout? number
function Bridge.libs.streamingRequest(request, hasLoaded, assetType, asset, timeout, ...)
    if hasLoaded(asset) then return asset end

    request(asset, ...)

    local deadline = GetGameTimer() + (timeout or 30000)
    repeat
        Citizen.Wait(0)
    until hasLoaded(asset) or GetGameTimer() > deadline

    if not hasLoaded(asset) then
        error(("failed to load %s '%s' - too many loaded assets, oversized or invalid asset"):format(assetType, asset))
    end

    return asset
end

---@param model number | string
---@param timeout? number  Approx milliseconds to wait (default 10000).
---@return number model
function Bridge.libs.requestModel(model, timeout)
    if type(model) ~= 'number' then model = joaat(model) end
    if HasModelLoaded(model) then return model end

    if not IsModelValid(model) and not IsModelInCdimage(model) then
        error(("attempted to load invalid model '%s'"):format(model))
    end

    return Bridge.libs.streamingRequest(RequestModel, HasModelLoaded, 'model', model, timeout or 10000)
end

Bridge.libs.raycast = Bridge.libs.raycast or {}

local StartShapeTestLosProbe              = StartShapeTestLosProbe
local GetShapeTestResultIncludingMaterial = GetShapeTestResultIncludingMaterial

local function getForwardVector()
    local rot   = GetFinalRenderedCamRot(2)
    local rad_x = math.rad(rot.x)
    local rad_z = math.rad(rot.z)
    return vec3(
        -math.sin(rad_z) * math.abs(math.cos(rad_x)),
         math.cos(rad_z) * math.abs(math.cos(rad_x)),
         math.sin(rad_x)
    )
end

---@param coords vector3
---@param destination vector3
---@param flags integer?   Shapetest flags. Defaults to 511 (all).
---@param ignore integer?  Shapetest ignore flags. Defaults to 4 (no collision).
---@return boolean hit
---@return number entityHit
---@return vector3 endCoords
---@return vector3 surfaceNormal
---@return number materialHash
function Bridge.libs.raycast.fromCoords(coords, destination, flags, ignore)
    local playerPed = (cache and cache.ped) or PlayerPedId()
    local handle = StartShapeTestLosProbe(
        coords.x,       coords.y,       coords.z,
        destination.x,  destination.y,  destination.z,
        flags or 511, playerPed, ignore or 4
    )

    while true do
        Wait(0)
        local retval, hit, endCoords, surfaceNormal, material, entityHit = GetShapeTestResultIncludingMaterial(handle)
        if retval ~= 1 then
            return hit, entityHit, endCoords, surfaceNormal, material
        end
    end
end

---@param flags integer?    Shapetest flags. Defaults to 511 (all).
---@param ignore integer?   Shapetest ignore flags. Defaults to 4.
---@param distance number?  Ray distance. Defaults to 10.
---@return boolean hit
---@return number entityHit
---@return vector3 endCoords
---@return vector3 surfaceNormal
---@return number materialHash
function Bridge.libs.raycast.fromCamera(flags, ignore, distance)
    local coords      = GetFinalRenderedCamCoord()
    local destination = coords + getForwardVector() * (distance or 10)
    return Bridge.libs.raycast.fromCoords(GetFinalRenderedCamCoord(), destination, flags, ignore)
end

Bridge.libs.raycast.cam = Bridge.libs.raycast.fromCamera
