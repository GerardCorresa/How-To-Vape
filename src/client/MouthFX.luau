--[[
    MouthFX
    Ruta en Roblox Studio: StarterPlayer > StarterPlayerScripts > MouthFX
    Tipo: ModuleScript (cliente)

    Humo de la boca: crea UN Attachment en la cabeza por personaje y dos
    ParticleEmitter (nube principal + dispersion secundaria). Los emisores se
    crean una sola vez y se reutilizan: no se instancian cosas por calada.

    Diseno:
      * Rate = 0: nada se emite solo. Todo sale por Emit(), asi que el humo
        aparece exactamente cuando la secuencia lo pide.
      * El Attachment vive en la cabeza, delante de la boca, y NO dentro de ella.
      * La direccion de salida se corrige con Acceleration (hacia delante +
        hacia arriba) calculada con la orientacion real de la cabeza en cada
        emision. Asi el plume sale bien aunque el eje del Attachment no
        coincida con lo que esperas de la convencion de ParticleEmitter.
      * LockedToPart = false: las particulas se quedan en el mundo y no siguen
        a la cabeza cuando el jugador se mueve.

    Requiere: AnimConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimConfig"))

local MouthFX = {}

local cache = {}   -- [Model(character)] = { attachment, main, secondary }

local ATTR_NAME = "VapeMouthFX"

local function numberSequence(points)
    local keys = {}
    for _, p in ipairs(points) do
        table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
    end
    return NumberSequence.new(keys)
end

local function buildEmitter(name, spec, texture, parent)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = name
    emitter.Color = ColorSequence.new(spec.color or Color3.fromRGB(230, 230, 230))
    emitter.Size = numberSequence(spec.size)
    emitter.Transparency = numberSequence(spec.transparency)
    emitter.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
    emitter.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
    emitter.Rotation = NumberRange.new(spec.rotation[1], spec.rotation[2])
    emitter.RotSpeed = NumberRange.new(spec.rotSpeed[1], spec.rotSpeed[2])
    emitter.SpreadAngle = Vector2.new(spec.spread, spec.spread)
    emitter.Drag = spec.drag
    emitter.Rate = 0                 -- solo emision manual
    emitter.LightEmission = 0.05
    emitter.LightInfluence = 0.95
    emitter.LockedToPart = false
    emitter.Texture = texture or ""
    emitter.Parent = parent
    return emitter
end

-- Posicion del humo: delante de la boca, en el espacio local de la cabeza.
local function mouthLocal(head)
    local cfg = AnimConfig.Mouth
    return Vector3.new(
        cfg.Offset.X * head.Size.X,
        cfg.Offset.Y * head.Size.Y,
        -(cfg.Offset.Z * head.Size.Z + cfg.Clearance)
    )
end

function MouthFX.ensure(character)
    if cache[character] then
        return cache[character]
    end
    local head = character:FindFirstChild("Head")
    if not head then
        return nil
    end

    local attachment = Instance.new("Attachment")
    attachment.Name = ATTR_NAME
    attachment.Position = mouthLocal(head)
    -- Rotacion identidad: el -Z del Attachment ya coincide con el frente de la
    -- cabeza. La direccion real del humo la fuerza Acceleration en emit().
    attachment.Parent = head

    local smoke = AnimConfig.Smoke
    local fx = {
        attachment = attachment,
        main = buildEmitter("PuffMain", smoke.Main, smoke.Texture, attachment),
        secondary = buildEmitter("PuffSecondary", smoke.Secondary, smoke.Texture, attachment),
        head = head,
    }
    cache[character] = fx
    return fx
end

--[[ Emite el humo de la boca. Debe llamarse en el marcador de expulsion. ]]
function MouthFX.emit(character)
    local head = character:FindFirstChild("Head")
    if not head then
        return
    end
    local fx = MouthFX.ensure(character)
    if not fx then
        return
    end

    -- Reajusta la posicion por si el avatar ha cambiado de escala.
    fx.attachment.Position = mouthLocal(head)

    local smoke = AnimConfig.Smoke
    -- Deriva real: hacia donde mira la cabeza + un poco hacia arriba.
    local accel = head.CFrame.LookVector * smoke.Forward + Vector3.new(0, smoke.Up, 0)
    fx.main.Acceleration = accel
    fx.secondary.Acceleration = accel

    fx.main:Emit(smoke.Main.count)
    fx.secondary:Emit(smoke.Secondary.count)
end

function MouthFX.clear(character)
    cache[character] = nil
end

return MouthFX
