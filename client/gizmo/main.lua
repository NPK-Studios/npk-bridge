while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Gizmo] Loaded: object_gizmo (inline)')
end

local DataView = setmetatable({
    EndBig = '>',
    EndLittle = '<',
    Types = {
        Int8 = { code = 'i1' },
        Uint8 = { code = 'I1' },
        Int16 = { code = 'i2' },
        Uint16 = { code = 'I2' },
        Int32 = { code = 'i4' },
        Uint32 = { code = 'I4' },
        Int64 = { code = 'i8' },
        Uint64 = { code = 'I8' },
        Float32 = { code = 'f', size = 4 },
        Float64 = { code = 'd', size = 8 },
        LuaInt = { code = 'j' },
        UluaInt = { code = 'J' },
        LuaNum = { code = 'n' },
        String = { code = 'z', size = -1 },
    },
}, {
    __call = function(_, length) return DataView.ArrayBuffer(length) end
})
DataView.__index = DataView

function DataView.ArrayBuffer(length)
    return setmetatable({
        blob = string.blob(length),
        length = length,
        offset = 1,
        cangrow = true,
    }, DataView)
end

function DataView:Buffer() return self.blob end

local function ef(big) return (big and DataView.EndBig) or DataView.EndLittle end

local function packblob(self, offset, value, code)
    local packed = self.blob:blob_pack(offset, code, value)
    if self.cangrow or packed == self.blob then
        self.blob = packed
        self.length = packed:len()
        return true
    end
    return false
end

for label, datatype in pairs(DataView.Types) do
    if not datatype.size then
        datatype.size = string.packsize(datatype.code)
    elseif datatype.size >= 0 and string.packsize(datatype.code) ~= datatype.size then
        error(('Pack size of %s (%d) does not match cached length: (%d)'):format(label, string.packsize(datatype.code), datatype.size))
    end

    DataView['Get' .. label] = function(self, offset, endian)
        offset = offset or 0
        if offset >= 0 then
            local o = self.offset + offset
            local v = self.blob:blob_unpack(o, ef(endian) .. datatype.code)
            return v
        end
        return nil
    end

    DataView['Set' .. label] = function(self, offset, value, endian)
        if offset >= 0 and value then
            local o = self.offset + offset
            local v_size = (datatype.size < 0 and value:len()) or datatype.size
            if self.cangrow or ((o + (v_size - 1)) <= self.length) then
                if not packblob(self, o, value, ef(endian) .. datatype.code) then
                    error('cannot grow subview')
                end
            else
                error('cannot grow dataview')
            end
        end
        return self
    end
end

local L = {
    enable_cursor          = 'Włącz kursor',
    disable_cursor         = 'Wyłącz kursor',
    translate_mode         = 'Tryb przesuwania',
    rotate_mode            = 'Tryb obrotu',
    scale_mode             = 'Tryb skalowania',
    toggle_space           = 'Przestrzeń lokalna/światowa',
    snap_to_ground         = 'Przyciągnij do podłoża',
    done_editing           = 'Zakończ edycję',
}

local enableScale  = false
local isCursorActive = false
local gizmoEnabled = false
local currentMode  = 'Translate'
local isRelative   = false
local currentEntity

local function normalize(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)
    if length == 0 then return 0, 0, 0 end
    return x / length, y / length, z / length
end

local function makeEntityMatrix(entity)
    local f, r, u, a = GetEntityMatrix(entity)
    local view = DataView.ArrayBuffer(60)

    view:SetFloat32(0, r[1])
        :SetFloat32(4, r[2])
        :SetFloat32(8, r[3])
        :SetFloat32(12, 0)
        :SetFloat32(16, f[1])
        :SetFloat32(20, f[2])
        :SetFloat32(24, f[3])
        :SetFloat32(28, 0)
        :SetFloat32(32, u[1])
        :SetFloat32(36, u[2])
        :SetFloat32(40, u[3])
        :SetFloat32(44, 0)
        :SetFloat32(48, a[1])
        :SetFloat32(52, a[2])
        :SetFloat32(56, a[3])
        :SetFloat32(60, 1)

    return view
end

local function applyEntityMatrix(entity, view)
    local x1, y1, z1 = view:GetFloat32(16), view:GetFloat32(20), view:GetFloat32(24)
    local x2, y2, z2 = view:GetFloat32(0),  view:GetFloat32(4),  view:GetFloat32(8)
    local x3, y3, z3 = view:GetFloat32(32), view:GetFloat32(36), view:GetFloat32(40)
    local tx, ty, tz = view:GetFloat32(48), view:GetFloat32(52), view:GetFloat32(56)

    if not enableScale then
        x1, y1, z1 = normalize(x1, y1, z1)
        x2, y2, z2 = normalize(x2, y2, z2)
        x3, y3, z3 = normalize(x3, y3, z3)
    end

    SetEntityMatrix(entity,
        x1, y1, z1,
        x2, y2, z2,
        x3, y3, z3,
        tx, ty, tz
    )
end

local function getVectorText(kind)
    if not currentEntity then return ('ERR_NO_ENTITY_%s'):format(kind or 'UNK') end
    local label = (kind == 'coords' and 'Pozycja' or 'Rotacja')
    local vec = (kind == 'coords' and GetEntityCoords(currentEntity) or GetEntityRotation(currentEntity))
    return ('%s: %.2f, %.2f, %.2f'):format(label, vec.x, vec.y, vec.z)
end

local function textUILoop()
    Citizen.CreateThread(function()
        while gizmoEnabled do
            Citizen.Wait(100)

            local scaleLine = (enableScale and ('[S]     - %s  \n'):format(L.scale_mode)) or ''
            local modeLine  = ('Tryb: %s | %s  \n'):format(currentMode, isRelative and 'Lokalna' or 'Światowa')

            lib.showTextUI(
                modeLine ..
                getVectorText('coords') .. '  \n' ..
                getVectorText('rotation') .. '  \n' ..
                ('[G]     - %s  \n'):format(isCursorActive and L.disable_cursor or L.enable_cursor) ..
                ('[W]     - %s  \n'):format(L.translate_mode) ..
                ('[R]     - %s  \n'):format(L.rotate_mode) ..
                scaleLine ..
                ('[Q]     - %s  \n'):format(L.toggle_space) ..
                ('[LALT]  - %s  \n'):format(L.snap_to_ground) ..
                ('[ENTER] - %s  \n'):format(L.done_editing)
            )
        end
        lib.hideTextUI()
    end)
end

local function gizmoLoop(entity)
    if not gizmoEnabled then return LeaveCursorMode() end

    EnterCursorMode()
    isCursorActive = true

    if IsEntityAPed(entity) then
        SetEntityAlpha(entity, 200)
    else
        SetEntityDrawOutline(entity, true)
    end

    while gizmoEnabled and DoesEntityExist(entity) do
        Citizen.Wait(0)
        if IsControlJustPressed(0, 47) then
            if isCursorActive then
                LeaveCursorMode()
                isCursorActive = false
            else
                EnterCursorMode()
                isCursorActive = true
            end
        end
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 140, true)
        DisablePlayerFiring(cache.playerId, true)

        local matrixBuffer = makeEntityMatrix(entity)
        local changed = Citizen.InvokeNative(0xEB2EDCA2, matrixBuffer:Buffer(), 'Editor1', Citizen.ReturnResultAnyway())
        if changed then
            applyEntityMatrix(entity, matrixBuffer)
        end
    end

    if isCursorActive then LeaveCursorMode() end
    isCursorActive = false

    if DoesEntityExist(entity) then
        if IsEntityAPed(entity) then SetEntityAlpha(entity, 255) end
        SetEntityDrawOutline(entity, false)
    end

    gizmoEnabled = false
    currentEntity = nil
end

Bridge.Gizmo = {}

Bridge.Gizmo.use = function(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    if gizmoEnabled then return nil end

    gizmoEnabled = true
    currentEntity = entity
    textUILoop()
    gizmoLoop(entity)

    return {
        handle   = entity,
        coords   = GetEntityCoords(entity),
        rotation = GetEntityRotation(entity),
        heading  = GetEntityHeading(entity),
    }
end

Bridge.Gizmo.cancel = function()
    gizmoEnabled = false
end

Bridge.Gizmo.isActive = function()
    return gizmoEnabled
end

lib.addKeybind({
    name = 'npkbridge_gizmoSelect',
    description = 'Gizmo: zaznacz oś',
    defaultMapper = 'MOUSE_BUTTON',
    defaultKey = 'MOUSE_LEFT',
    onPressed = function() if gizmoEnabled then ExecuteCommand('+gizmoSelect') end end,
    onReleased = function() ExecuteCommand('-gizmoSelect') end,
})

lib.addKeybind({
    name = 'npkbridge_gizmoTranslation',
    description = 'Gizmo: tryb przesuwania',
    defaultKey = 'W',
    onPressed = function()
        if not gizmoEnabled then return end
        currentMode = 'Translate'
        ExecuteCommand('+gizmoTranslation')
    end,
    onReleased = function() ExecuteCommand('-gizmoTranslation') end,
})

lib.addKeybind({
    name = 'npkbridge_gizmoRotation',
    description = 'Gizmo: tryb obrotu',
    defaultKey = 'R',
    onPressed = function()
        if not gizmoEnabled then return end
        currentMode = 'Rotate'
        ExecuteCommand('+gizmoRotation')
    end,
    onReleased = function() ExecuteCommand('-gizmoRotation') end,
})

lib.addKeybind({
    name = 'npkbridge_gizmoLocal',
    description = 'Gizmo: przełącz przestrzeń',
    defaultKey = 'Q',
    onPressed = function()
        if not gizmoEnabled then return end
        isRelative = not isRelative
        ExecuteCommand('+gizmoLocal')
    end,
    onReleased = function() ExecuteCommand('-gizmoLocal') end,
})

lib.addKeybind({
    name = 'npkbridge_gizmoClose',
    description = 'Gizmo: zakończ edycję',
    defaultKey = 'RETURN',
    onReleased = function()
        if gizmoEnabled then gizmoEnabled = false end
    end,
})

lib.addKeybind({
    name = 'npkbridge_gizmoSnap',
    description = 'Gizmo: przyciągnij do podłoża',
    defaultKey = 'LMENU',
    onPressed = function()
        if not gizmoEnabled then return end
        if currentEntity and DoesEntityExist(currentEntity) then
            PlaceObjectOnGroundProperly_2(currentEntity)
        end
    end,
})
