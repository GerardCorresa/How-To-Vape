--[[
    VehicleFactory
    Ruta en Roblox Studio: ReplicatedStorage > Shared > VehicleFactory
    Tipo: ModuleScript

    Construye proceduralmente el modelo de cada vehiculo a partir de
    VehicleConfig. Es un modulo COMPARTIDO (ReplicatedStorage/Shared): lo usa el
    servidor para desplegar el vehiculo en el mundo y el cliente para las
    previsualizaciones 3D del menu.

    Convenciones IMPORTANTES (las usa el resto del sistema):
      * El plano del SUELO es y = 0 en espacio local y el Part primario ("Root",
        invisible) esta justo en ese origen. Por eso Model:PivotTo(cframe)
        coloca las ruedas exactamente sobre `cframe` y el modelo nunca aparece
        hundido ni flotando.
      * Las ruedas cuelgan de un Motor6D llamado "SpinMotor" (no de un
        WeldConstraint) para que el cliente pueda girarlas como animacion de
        conduccion sin que la fisica lo revierta. Llevan los atributos
        VehicleWheel = true y WheelRadius.
      * El asiento es un VehicleSeat invisible con el atributo VehicleSeat = true
        y el atributo DriveEnabled = false. El servidor lo enciende al montarse
        y lo apaga al bajarse (ver VehicleService).
      * Solo colisionan la plataforma y las ruedas; el resto es decorativo y sin
        masa, para que el vehiculo sea estable y no se enganche.

    Requiere: VehicleConfig (mismo directorio).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VehicleConfig"))

local VehicleFactory = {}

local PART_TYPE = {
    Block = Enum.PartType.Block,
    Cylinder = Enum.PartType.Cylinder,
    Ball = Enum.PartType.Ball,
}

local function weld(part, target)
    local w = Instance.new("WeldConstraint")
    w.Part0 = part
    w.Part1 = target
    w.Parent = part
end

--[[ Crea una pieza a partir de una especificacion.

     spec = {
        name, shape, size, pos, rot (grados), color, material,
        transparency, reflectance, collide, massless, density, friction,
        light = { color, brightness, range }, emissive,
     } ]]
local function piece(spec, parent)
    local part = Instance.new("Part")
    part.Name = spec.name
    part.Anchored = false
    part.CanCollide = spec.collide == true
    part.CanQuery = spec.collide == true
    part.CanTouch = spec.collide == true
    part.Massless = spec.massless ~= false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Size = spec.size
    part.Color = spec.color or Color3.fromRGB(200, 200, 200)
    part.Material = spec.material or Enum.Material.SmoothPlastic
    part.Transparency = spec.transparency or 0
    part.Reflectance = spec.reflectance or 0
    if spec.shape then
        part.Shape = PART_TYPE[spec.shape] or Enum.PartType.Block
    end
    local rot = spec.rot or Vector3.new(0, 0, 0)
    part.CFrame = CFrame.new(spec.pos or Vector3.new(0, 0, 0))
        * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
    if spec.collide then
        part.CustomPhysicalProperties = PhysicalProperties.new(
            spec.density or 1.2, spec.friction or 1.1, spec.elasticity or 0.05)
    end
    if spec.light then
        local l = spec.light
        local pl = Instance.new("PointLight")
        pl.Color = l.color or part.Color
        pl.Brightness = l.brightness or 1.6
        pl.Range = l.range or 14
        pl.Shadows = false
        pl.Parent = part
    end
    part.Parent = parent
    return part
end

--[[ Rueda: cilindro con el eje en X (el del mundo) + buje neon soldado.
     Devuelve el Part de la rueda (el que lleva el Motor6D). ]]
local function wheel(model, parent, name, radius, thickness, pos, color, hubColor)
    local w = piece({
        name = name, shape = "Cylinder",
        size = Vector3.new(thickness, radius * 2, radius * 2),
        pos = pos, color = color, material = Enum.Material.Rubber,
        collide = true, massless = false, density = 0.6, friction = 1.5,
    }, model)
    w:SetAttribute("VehicleWheel", true)
    w:SetAttribute("WheelRadius", radius)

    local hub = piece({
        name = name .. "Hub", shape = "Ball",
        size = Vector3.new(radius * 0.62, radius * 0.62, radius * 0.62),
        pos = pos, color = hubColor, material = Enum.Material.Neon,
    }, model)
    weld(hub, w)
    return w
end

-- Layouts ---------------------------------------------------------------------

--[[ PATINETE: plataforma baja, dos ruedas visibles, columna de direccion,
     manillar con puños, sillín alto (para que el personaje se siente encima de
     la plataforma con los pies sobre ella) y neon urbano. Mira hacia -Z. ]]
local function buildScooter(model, cfg)
    local accent = cfg.accent
    local accent2 = cfg.accent2
    local body = Color3.fromRGB(26, 28, 38)
    local dark = Color3.fromRGB(17, 19, 26)
    local metal = Color3.fromRGB(150, 158, 176)

    -- Raiz (pivote) en el plano del suelo.
    local root = piece({
        name = "Root", size = Vector3.new(0.4, 0.2, 0.4), pos = Vector3.new(0, 0, 0),
        transparency = 1,
    }, model)

    -- Plataforma de los pies.
    local deck = piece({
        name = "Deck", size = Vector3.new(2.4, 0.34, 2.7), pos = Vector3.new(0, 0.5, 0.3),
        color = body, material = Enum.Material.Metal,
        collide = true, massless = false, density = 1.6, friction = 1.1,
    }, model)
    piece({
        name = "DeckTape", size = Vector3.new(2.05, 0.06, 2.35), pos = Vector3.new(0, 0.68, 0.3),
        color = dark, material = Enum.Material.SmoothPlastic,
    }, model)
    piece({
        name = "Underglow", size = Vector3.new(2.1, 0.09, 2.5), pos = Vector3.new(0, 0.3, 0.3),
        color = accent2, material = Enum.Material.Neon, transparency = 0.05,
    }, model)

    -- Ruedas + horquilla + guardabarros.
    local front = wheel(model, model, "WheelFront", 0.5, 0.4, Vector3.new(0, 0.5, -1.5), dark, accent2)
    local rear = wheel(model, model, "WheelRear", 0.5, 0.4, Vector3.new(0, 0.5, 1.5), dark, accent2)
    piece({
        name = "ForkLeft", size = Vector3.new(0.14, 0.72, 0.44), pos = Vector3.new(-0.34, 0.82, -1.5),
        color = metal, material = Enum.Material.Metal,
    }, model)
    piece({
        name = "ForkRight", size = Vector3.new(0.14, 0.72, 0.44), pos = Vector3.new(0.34, 0.82, -1.5),
        color = metal, material = Enum.Material.Metal,
    }, model)
    piece({
        name = "FenderFront", size = Vector3.new(0.78, 0.12, 1.35), pos = Vector3.new(0, 1.06, -1.5),
        color = body, material = Enum.Material.Metal,
    }, model)

    -- Columna de direccion + manillar + puños.
    piece({
        name = "Column", size = Vector3.new(0.34, 1.8, 0.34), pos = Vector3.new(0, 1.85, -1.2),
        rot = Vector3.new(26, 0, 0), color = body, material = Enum.Material.Metal,
    }, model)
    piece({
        name = "ColumnGlow", size = Vector3.new(0.1, 1.6, 0.1), pos = Vector3.new(0, 1.85, -1.36),
        rot = Vector3.new(26, 0, 0), color = accent, material = Enum.Material.Neon,
    }, model)
    piece({
        name = "Handlebar", size = Vector3.new(2.2, 0.24, 0.24), pos = Vector3.new(0, 2.68, -0.8),
        color = metal, material = Enum.Material.Metal,
    }, model)
    piece({
        name = "GripLeft", shape = "Ball", size = Vector3.new(0.3, 0.3, 0.3),
        pos = Vector3.new(-1.0, 2.68, -0.8), color = dark, material = Enum.Material.SmoothPlastic,
    }, model)
    piece({
        name = "GripRight", shape = "Ball", size = Vector3.new(0.3, 0.3, 0.3),
        pos = Vector3.new(1.0, 2.68, -0.8), color = dark, material = Enum.Material.SmoothPlastic,
    }, model)
    piece({
        name = "Headlight", size = Vector3.new(0.46, 0.3, 0.22), pos = Vector3.new(0, 2.36, -1.02),
        color = accent, material = Enum.Material.Neon,
        light = { color = accent, brightness = 1.8, range = 16 },
    }, model)
    piece({
        name = "Dash", size = Vector3.new(0.46, 0.26, 0.1), pos = Vector3.new(0, 2.2, -0.9),
        color = accent2, material = Enum.Material.Neon,
    }, model)

    -- Cuerpo trasero (soporte del sillín) + detalles.
    piece({
        name = "Tower", size = Vector3.new(1.3, 1.3, 1.45), pos = Vector3.new(0, 1.33, 1.15),
        color = body, material = Enum.Material.Metal,
    }, model)
    piece({
        name = "TowerGlow", size = Vector3.new(1.34, 0.12, 1.49), pos = Vector3.new(0, 1.5, 1.15),
        color = accent, material = Enum.Material.Neon,
    }, model)
    piece({
        name = "SaddleBack", size = Vector3.new(1.05, 0.5, 0.2), pos = Vector3.new(0, 2.2, 1.72),
        color = dark, material = Enum.Material.SmoothPlastic,
    }, model)
    piece({
        name = "Taillight", size = Vector3.new(0.5, 0.18, 0.08), pos = Vector3.new(0, 0.94, 1.98),
        color = accent, material = Enum.Material.Neon,
    }, model)

    -- Sillín: VehicleSeat INVISIBLE. El personaje se sienta encima de la
    -- plataforma (los pies quedan a la altura de la tabla) y sin tocar el suelo.
    local seat = Instance.new("VehicleSeat")
    seat.Name = "Seat"
    seat.Anchored = false
    seat.CanCollide = false
    seat.CanQuery = false
    seat.CanTouch = false
    seat.Massless = true
    seat.Transparency = 1
    seat.Size = Vector3.new(1.5, 0.3, 1.4)
    seat.CFrame = CFrame.new(0, 1.85, 1.15)
    seat.TopSurface = Enum.SurfaceType.Smooth
    seat.BottomSurface = Enum.SurfaceType.Smooth
    -- La conduccion NO usa el motor interno del asiento: lo mueve el cliente de
    -- forma cinemática (ver VehicleController). Se deja a 0 para que no empuje
    -- por su cuenta.
    seat.MaxSpeed = 0
    seat.Torque = 0
    seat.TurnSpeed = 0
    seat.HeadsUpDisplay = false
    seat.Disabled = false
    seat:SetAttribute("VehicleSeat", true)
    seat.Parent = model

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "MountPrompt"
    prompt.ActionText = "SUBIR"
    prompt.ObjectText = cfg.name
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt:SetAttribute("PromptType", "Vehicle")
    prompt.Parent = seat

    -- Uniones: todo al Root salvo las ruedas (Motor6D para poder girarlas) y lo
    -- que ya viene unido de fabrica (buje -> rueda), que si no crearia un bucle
    -- rigido de restricciones.
    local function alreadyJointed(part)
        return part:FindFirstChildOfClass("WeldConstraint") ~= nil
            or part:FindFirstChildOfClass("Motor6D") ~= nil
    end
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("BasePart") and part ~= root and part ~= deck and part ~= front
            and part ~= rear and part ~= seat and not alreadyJointed(part) then
            weld(part, deck)
        end
    end
    weld(deck, root)
    weld(seat, deck)

    local function spinMotor(w)
        local m = Instance.new("Motor6D")
        m.Name = "SpinMotor"
        m.Part0 = deck
        m.Part1 = w
        m.C0 = deck.CFrame:Inverse() * w.CFrame
        m.C1 = CFrame.new()
        m.Parent = w
    end
    spinMotor(front)
    spinMotor(rear)

    return root
end

local Layouts = {
    scooter = buildScooter,
}

--[[ Construye el modelo de un vehiculo. Devuelve un Model sin parentar (o nil
     si el id no existe). El Part primario queda en el plano del suelo. ]]
function VehicleFactory.Build(vehicleId)
    local cfg = VehicleConfig.Get(vehicleId)
    if not cfg then
        return nil
    end
    local layout = Layouts[cfg.layout or ""]
    if not layout then
        return nil
    end

    local model = Instance.new("Model")
    model.Name = "Vehicle_" .. vehicleId
    model:SetAttribute("VehicleId", vehicleId)
    model:SetAttribute("DriveEnabled", false)

    local root = layout(model, cfg)
    model.PrimaryPart = root
    return model
end

return VehicleFactory
