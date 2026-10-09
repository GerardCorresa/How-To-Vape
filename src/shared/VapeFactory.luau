--[[
    VapeFactory
    Ruta en Roblox Studio: ReplicatedStorage > Shared > VapeFactory
    Tipo: ModuleScript

    Construye proceduralmente el modelo de cada vape a partir de VapeConfig.
    Genera Blocks/Cylinders/Balls, luces, particulas, pantallas y anillos
    giratorios, y los suelda al Part primario.

    Es un modulo COMPARTIDO: lo usa el servidor (EquipmentService) para poner
    el vape en la mano del personaje y el cliente (previsualizacion en tienda
    e inventario). Por eso vive en ReplicatedStorage/Shared.

    Animaciones: en lugar de mover piezas por red, marcamos los Part con
    atributos (SpinSpeed, RGBSpeed). El cliente local anima esos Part, asi el
    servidor no gasta CPU replicando transformaciones cada frame.

    Requiere: VapeConfig (mismo directorio).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VapeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VapeConfig"))

local VapeFactory = {}

local PART_TYPE = {
    Block = Enum.PartType.Block,
    Cylinder = Enum.PartType.Cylinder,
    Ball = Enum.PartType.Ball,
}

local function makeWeld(part, target)
    local w = Instance.new("WeldConstraint")
    w.Part0 = part
    w.Part1 = target
    w.Parent = part
end

local function configurePart(part, spec, scale)
    scale = scale or 1
    part.Name = spec.name
    part.Anchored = false
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Size = spec.size * scale
    part.Color = spec.color or Color3.fromRGB(200, 200, 200)
    part.Material = spec.material or Enum.Material.SmoothPlastic
    part.Transparency = spec.transparency or 0
    part.Reflectance = spec.reflectance or 0
    if spec.shape then
        part.Shape = PART_TYPE[spec.shape] or Enum.PartType.Block
    end
    local pos = (spec.pos or Vector3.new(0, 0, 0)) * scale
    local rot = spec.rot or Vector3.new(0, 0, 0)
    part.CFrame = CFrame.new(pos)
        * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
end

-- Extras opcionales de una pieza --------------------------------------------
local function addExtras(part, spec, scale)
    scale = scale or 1
    if spec.emitter then
        local e = spec.emitter
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "VapeSmoke"
        pe.Color = ColorSequence.new(e.color or Color3.new(1, 1, 1))
        pe.Size = NumberSequence.new((e.size or 0.6) * scale)
        pe.Speed = e.speed or NumberRange.new(3, 7)
        pe.Lifetime = e.lifetime or NumberRange.new(0.4, 1.0)
        pe.Rate = e.rate or 0
        pe.SpreadAngle = Vector2.new(18, 18)
        pe.LightEmission = 0.6
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.25),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.Parent = part
    end

    if spec.light then
        local l = spec.light
        local pl = Instance.new("PointLight")
        pl.Color = l.color or Color3.new(1, 1, 1)
        pl.Brightness = l.brightness or 2
        pl.Range = (l.range or 10) * math.max(1, scale)
        pl.Shadows = false
        pl.Parent = part
    end

    if spec.screen then
        local s = spec.screen
        local gui = Instance.new("SurfaceGui")
        gui.Name = "VapeScreen"
        gui.Face = Enum.NormalId.Front
        gui.LightInfluence = 0
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 60
        gui.Parent = part

        local bg = Instance.new("Frame")
        bg.Size = UDim2.fromScale(1, 1)
        bg.BackgroundColor3 = s.background or Color3.fromRGB(5, 20, 25)
        bg.BorderSizePixel = 0
        bg.Parent = gui

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code
        label.Text = s.text or "VAPE"
        label.TextColor3 = s.color or Color3.new(0, 1, 1)
        label.TextScaled = true
        label.TextStrokeTransparency = 0.5
        label.Parent = bg
    end

    if spec.spin then
        part:SetAttribute("SpinSpeed", spec.spin)
    end
    if spec.rgb then
        part:SetAttribute("RGBSpeed", spec.rgb)
    end
end

--[[
    Crea el modelo de un vape. Devuelve un Model sin parentar (o nil si el id
    no existe). El Part primario queda centrado en el origen del modelo; el
    equipamiento lo mueve con PivotTo.
]]
function VapeFactory.Build(vapeId)
    local cfg = VapeConfig.Vapes[vapeId]
    if not cfg or not cfg.model then
        return nil
    end

    local model = Instance.new("Model")
    model.Name = "Vape_" .. vapeId
    model:SetAttribute("VapeId", vapeId)

    local scale = (cfg.hold and cfg.hold.scale) or 1
    model:SetAttribute("VapeScale", scale)

    local primary = nil
    local children = {}

    -- Piezas sueltas
    for _, spec in ipairs(cfg.model.parts or {}) do
        local part = Instance.new("Part")
        configurePart(part, spec, scale)
        addExtras(part, spec, scale)
        part.Parent = model
        table.insert(children, part)
        if spec.primary then
            primary = part
        end
    end

    if not primary then
        primary = children[1]
    end

    -- Anillos giratorios (hub invisible + segmentos soldados)
    for _, group in ipairs(cfg.model.groups or {}) do
        local hub = Instance.new("Part")
        hub.Name = group.name .. "_Hub"
        hub.Anchored = false
        hub.CanCollide = false
        hub.CanQuery = false
        hub.CanTouch = false
        hub.Massless = true
        hub.Size = Vector3.new(0.1, 0.1, 0.1)
        hub.Transparency = 1
        local rot = group.rot or Vector3.new(0, 0, 0)
        hub.CFrame = CFrame.new((group.pos or Vector3.new(0, 0, 0)) * scale)
            * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
        hub:SetAttribute("SpinSpeed", group.spin or 2)
        hub.Parent = model

        -- El hub se une con Motor6D (no WeldConstraint) para que el cliente
        -- pueda animar su giro sin que la fisica lo revierta.
        local motor = Instance.new("Motor6D")
        motor.Name = "SpinMotor"
        motor.Part0 = primary
        motor.Part1 = hub
        motor.C0 = primary.CFrame:Inverse() * hub.CFrame
        motor.C1 = CFrame.new()
        motor.Parent = hub

        local count = group.count or 8
        local radius = (group.radius or 0.5) * scale
        local segSize = (group.segSize or Vector3.new(0.1, 0.1, 0.1)) * scale
        for i = 1, count do
            local angle = (i / count) * math.pi * 2
            local seg = Instance.new("Part")
            seg.Name = group.name .. "_Seg" .. i
            seg.Anchored = false
            seg.CanCollide = false
            seg.CanQuery = false
            seg.CanTouch = false
            seg.Massless = true
            seg.Shape = Enum.PartType.Block
            seg.Size = segSize
            seg.Color = group.segColor or Color3.new(1, 1, 1)
            seg.Material = Enum.Material.Neon
            seg.CFrame = hub.CFrame
                * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                * CFrame.Angles(0, -angle, 0)
            seg.Parent = model
            makeWeld(seg, hub)
        end
    end

    -- Suelda las piezas sueltas al primario
    for _, part in ipairs(children) do
        if part ~= primary then
            makeWeld(part, primary)
        end
    end

    model.PrimaryPart = primary
    return model
end

return VapeFactory
