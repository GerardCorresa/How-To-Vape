--[[
    CityKit
    Ruta en Roblox Studio: ServerScriptService > CityKit
    Tipo: ModuleScript

    Primitivas de construccion urbana reutilizadas por todos los modulos de la
    ciudad (CityBuilder, BuildingBuilder, ShopBuilder, PlazaBuilder). Reunirlas
    aqui evita duplicar codigo y garantiza que TODA la ciudad use los mismos
    niveles, materiales y criterios anti z-fighting.

    Solo servidor: el cliente nunca construye mapa.

    Requiere: BuildKit, CityGrid.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGrid = require(Shared:WaitForChild("CityGrid"))
local BuildKit = require(script.Parent:WaitForChild("BuildKit"))

local CityKit = {}

local M = Enum.Material
local C = Color3.fromRGB

CityKit.C = C
CityKit.M = M
CityKit.Grid = CityGrid
CityKit.Levels = CityGrid.Levels

-- Presupuesto de luces dinamicas ----------------------------------------------
-- Las PointLight son el gasto mas caro de una ciudad grande: cada una obliga al
-- motor a recalcular iluminacion. En vez de repartirlas al azar por todas las
-- fachadas, se asignan de un presupuesto global. Cuando se agota, los detalles
-- siguen brillando porque usan material Neon (que no cuesta nada).
local DEFAULT_LIGHT_BUDGET = 210
local lightBudget = DEFAULT_LIGHT_BUDGET

function CityKit.ResetLights(budget)
    lightBudget = budget or DEFAULT_LIGHT_BUDGET
end

function CityKit.AllowLight(cost)
    cost = cost or 1
    if lightBudget < cost then
        return false
    end
    lightBudget -= cost
    return true
end

function CityKit.LightsLeft()
    return lightBudget
end

-- Paleta urbana ---------------------------------------------------------------
CityKit.Palette = {
    asphalt = C(46, 48, 54),
    asphaltWorn = C(54, 56, 62),
    sidewalk = C(150, 152, 158),
    curb = C(178, 180, 186),
    tileA = C(196, 190, 178),
    tileB = C(158, 152, 142),
    tileAccent = C(120, 190, 220),
    plazaStone = C(208, 202, 190),
    grass = C(84, 122, 74),
    grassDark = C(66, 100, 62),
    dirt = C(126, 112, 92),
    paint = C(236, 236, 232),
    paintYellow = C(238, 204, 96),
    concrete = C(168, 168, 172),
    darkConcrete = C(96, 98, 104),
    base = C(74, 76, 82),
}

-- PRNG determinista (Park-Miller): mismo mapa en cada servidor ---------------
function CityKit.Rng(seed)
    local state = math.floor(seed) % 2147483647
    if state <= 0 then state += 2147483646 end
    return function()
        state = (state * 48271) % 2147483647
        return state / 2147483647
    end
end

function CityKit.Pick(rand, list)
    return list[math.clamp(math.floor(rand() * #list) + 1, 1, #list)]
end

function CityKit.Int(rand, a, b)
    return a + math.floor(rand() * (b - a + 1))
end

function CityKit.Float(rand, a, b)
    return a + rand() * (b - a)
end

function CityKit.Shade(color, factor)
    local h, s, v = color:ToHSV()
    return Color3.fromHSV(h, math.clamp(s * (1 + factor * 0.4), 0, 1), math.clamp(v * (1 + factor), 0, 1))
end

-- Primitivas basicas -----------------------------------------------------------

function CityKit.Model(name, parent)
    return BuildKit.Model(name, parent)
end

--[[ Rectangulo horizontal alineado a los ejes. `top` es la cara superior. ]]
function CityKit.Rect(name, x1, z1, x2, z2, top, thickness, color, material, parent, opts)
    local w = math.abs(x2 - x1)
    local d = math.abs(z2 - z1)
    if w < 0.05 or d < 0.05 then
        return nil
    end
    opts = opts or {}
    return BuildKit.Part({
        name = name,
        size = Vector3.new(w, thickness, d),
        cframe = CFrame.new((x1 + x2) * 0.5, top - thickness * 0.5, (z1 + z2) * 0.5),
        color = color,
        material = material or M.Concrete,
        canCollide = opts.canCollide == true,
        canQuery = opts.canQuery == true,
        castShadow = false,
        transparency = opts.transparency,
        parent = parent,
    })
end

--[[ Banda horizontal entre dos puntos (para calles en cualquier direccion). ]]
function CityKit.Strip(name, a, b, width, top, thickness, color, material, parent, opts)
    local mid = (a + b) * 0.5
    local len = (b - a).Magnitude
    if len < 0.05 then
        return nil
    end
    opts = opts or {}
    local dir = (b - a).Unit
    local y = top - thickness * 0.5
    return BuildKit.Part({
        name = name,
        size = Vector3.new(width, thickness, len),
        cframe = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X, y, mid.Z) + dir),
        color = color,
        material = material or M.Concrete,
        canCollide = opts.canCollide == true,
        canQuery = opts.canQuery == true,
        castShadow = false,
        transparency = opts.transparency,
        parent = parent,
    })
end

-- Carreteras y marcas ----------------------------------------------------------

--[[ Tramo de asfalto alineado a los ejes. `axis` = "x" (corre en X) o "z". ]]
function CityKit.Road(name, axis, line, from, to, width, parent)
    local L = CityGrid.Levels
    if axis == "x" then
        return CityKit.Rect(name, from, line - width * 0.5, to, line + width * 0.5,
            L.road, 1.0, CityKit.Palette.asphalt, M.Asphalt, parent, { canCollide = true })
    end
    return CityKit.Rect(name, line - width * 0.5, from, line + width * 0.5, to,
        L.road, 1.0, CityKit.Palette.asphalt, M.Asphalt, parent, { canCollide = true })
end

local function markRect(name, axis, line, from, to, width, offset, parent, color)
    local L = CityGrid.Levels
    local y = L.mark
    color = color or CityKit.Palette.paint
    if axis == "x" then
        return CityKit.Rect(name, from, line + offset - width * 0.5, to, line + offset + width * 0.5,
            y, 0.16, color, M.SmoothPlastic, parent, {})
    end
    return CityKit.Rect(name, line + offset - width * 0.5, from, line + offset + width * 0.5, to,
        y, 0.16, color, M.SmoothPlastic, parent, {})
end

--[[ Linea discontinua de carril. `axis` = eje en el que corre la calle. ]]
function CityKit.DashedLine(axis, line, from, to, offset, parent, dash, gap)
    dash = dash or 12
    gap = gap or 24
    local length = to - from
    if length <= 0 then
        return
    end
    local n = math.floor(length / (dash + gap))
    for i = 0, n - 1 do
        local a = from + i * (dash + gap)
        markRect("Dashed", axis, line, a, a + dash, 1.0, offset, parent)
    end
end

function CityKit.SolidLine(axis, line, from, to, offset, parent, color, width)
    return markRect("Solid", axis, line, from, to, width or 1.0, offset, parent, color)
end

--[[ Paso de peatones: franjas blancas perpendiculares a la calle que se cruza.
     `axis` es el eje de la calle por la que se cruza. ]]
function CityKit.Crosswalk(axis, line, at, roadWidth, parent)
    local stripes = math.max(3, math.floor(roadWidth / 9))
    local stripeW = roadWidth / (stripes * 1.6)
    local step = roadWidth / stripes
    for i = 0, stripes - 1 do
        local o = -roadWidth * 0.5 + step * (i + 0.5)
        markRect("Crosswalk", axis, line, at - 3.5, at + 3.5, stripeW, o, parent)
    end
end

--[[ Linea de detencion: barra blanca a traves de la calle, justo antes de un
     cruce. `at` es la posicion a lo largo de la calle. ]]
function CityKit.StopBar(axis, line, at, roadWidth, parent)
    local half = roadWidth * 0.5 - 1.5
    local n = 6
    for i = 0, n - 1 do
        local o = -half + (half * 2) * (i / (n - 1))
        markRect("Stop", axis, line, at, at + 1.6, 1.4, o, parent)
    end
end

--[[ Flecha de sentido de circulacion (rectangulo + punta de cuña). ]]
function CityKit.Arrow(axis, line, at, offset, parent)
    local y = CityGrid.Levels.mark
    local bodyLen, bodyW = 7, 1.6
    local head = 5
    local cf
    if axis == "x" then
        cf = CFrame.new(at, y - 0.08, line + offset)
    else
        cf = CFrame.new(line + offset, y - 0.08, at) * CFrame.Angles(0, math.rad(90), 0)
    end
    CityKit.Rect("ArrowBody", -bodyW * 0.5, at - bodyLen * 0.5, bodyW * 0.5, at + bodyLen * 0.5,
        y, 0.16, CityKit.Palette.paint, M.SmoothPlastic, parent, {})
    -- La punta: una pieza estrecha girada 45 grados da una lectura de flecha
    -- suficiente sin depender de geometria triangular.
    local tip = BuildKit.Part({
        name = "ArrowHead",
        size = Vector3.new(bodyW * 2.4, 0.16, head),
        color = CityKit.Palette.paint,
        material = M.SmoothPlastic,
        canCollide = false,
        canQuery = false,
        castShadow = false,
        cframe = (axis == "x" and CFrame.new(at + bodyLen * 0.5, y - 0.08, line + offset)
            or CFrame.new(line + offset, y - 0.08, at + bodyLen * 0.5) * CFrame.Angles(0, math.rad(90), 0)),
        parent = parent,
    })
    return tip
end

--[[ Plaza de aparcamiento: lineas perpendiculares + linea posterior. ]]
function CityKit.ParkingRow(x1, z1, x2, z2, slots, parent)
    local y = CityGrid.Levels.mark
    local horizontal = (x2 - x1) >= (z2 - z1)
    if horizontal then
        CityKit.Rect("ParkBack", x1, z1, x2, z1 + 0.9, y, 0.16, CityKit.Palette.paint, M.SmoothPlastic, parent, {})
        for i = 0, slots do
            local x = x1 + (x2 - x1) * (i / slots)
            CityKit.Rect("ParkLine", x - 0.45, z1, x + 0.45, z2, y, 0.16, CityKit.Palette.paint, M.SmoothPlastic, parent, {})
        end
    else
        CityKit.Rect("ParkBack", x1, z1, x1 + 0.9, z2, y, 0.16, CityKit.Palette.paint, M.SmoothPlastic, parent, {})
        for i = 0, slots do
            local z = z1 + (z2 - z1) * (i / slots)
            CityKit.Rect("ParkLine", x1, z - 0.45, x2, z + 0.45, y, 0.16, CityKit.Palette.paint, M.SmoothPlastic, parent, {})
        end
    end
end

-- Fachadas ---------------------------------------------------------------------

--[[ Ventana: marco + cristal. `cf` mira hacia el exterior (LookVector = fuera). ]]
function CityKit.Window(parent, cf, w, h, lit, frameColor)
    local frame = BuildKit.Part({
        name = "WinFrame", size = Vector3.new(w, h, 0.22),
        color = frameColor or C(232, 232, 230), material = M.SmoothPlastic,
        canCollide = false, canQuery = false, castShadow = false, cframe = cf, parent = parent,
    })
    local glass = BuildKit.Part({
        name = "WinGlass", size = Vector3.new(w - 0.5, h - 0.5, 0.28),
        color = lit and C(255, 226, 168) or C(112, 150, 178),
        material = lit and M.Neon or M.Glass,
        reflectance = lit and 0 or 0.35,
        transparency = lit and 0.05 or 0.35,
        canCollide = false, canQuery = false, castShadow = false,
        cframe = cf * CFrame.new(0, 0, 0.06), parent = parent,
    })
    if lit and CityKit.AllowLight() then
        local light = Instance.new("PointLight")
        light.Color = C(255, 226, 168)
        light.Brightness = 1.2
        light.Range = 16
        light.Shadows = false
        light.Parent = glass
    end
    return frame
end

--[[ Fila de ventanas a lo largo de una fachada. ]]
function CityKit.WindowRow(parent, origin, right, normal, count, spacing, w, h, litChance, rand)
    if count < 1 then
        return
    end
    local total = (count - 1) * spacing
    for i = 0, count - 1 do
        local offset = i * spacing - total * 0.5
        local pos = origin + right * offset
        local lit = litChance and rand and (rand() < litChance) or false
        CityKit.Window(parent, CFrame.lookAt(pos, pos + normal), w, h, lit)
    end
end

function CityKit.Door(parent, cf, w, h, color)
    return BuildKit.Part({
        name = "EntryDoor", size = Vector3.new(w, h, 0.3),
        color = color or C(96, 70, 48), material = M.Wood,
        canCollide = false, canQuery = false, castShadow = false,
        cframe = cf * CFrame.new(0, h * 0.5, 0), parent = parent,
    })
end

--[[ Toldo / marquesina sobre un escaparate. ]]
function CityKit.Awning(parent, cf, width, depth, color)
    local awn = BuildKit.Part({
        name = "Awning", size = Vector3.new(width, 0.5, depth),
        color = color, material = M.Fabric,
        canCollide = false, canQuery = false, castShadow = false,
        cframe = cf * CFrame.new(0, 0, depth * 0.5) * CFrame.Angles(math.rad(-16), 0, 0),
        parent = parent,
    })
    return awn
end

-- Propos urbanos ---------------------------------------------------------------

function CityKit.Tree(position, parent, scale, rand)
    scale = scale or 1
    local model = CityKit.Model("Tree", parent)
    local trunkH = 5 * scale
    BuildKit.Part({
        name = "Trunk", size = Vector3.new(0.9, trunkH, 0.9) * 1,
        color = C(96, 68, 44), material = M.Wood, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, trunkH * 0.5, 0)), parent = model,
    })
    local shades = { C(72, 122, 66), C(88, 136, 74), C(62, 106, 60) }
    local leaf = shades[math.clamp(math.floor((rand and rand() or 0.4) * 3) + 1, 1, 3)]
    BuildKit.Part({
        name = "Crown", shape = Enum.PartType.Ball, size = Vector3.new(6.4, 6.0, 6.4) * scale,
        color = leaf, material = M.Grass, canCollide = false, canQuery = false, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, trunkH + 2.2 * scale, 0)), parent = model,
    })
    return model
end

function CityKit.Bush(position, parent, scale)
    scale = scale or 1
    return BuildKit.Part({
        name = "Bush", shape = Enum.PartType.Ball, size = Vector3.new(2.8, 2.2, 2.8) * scale,
        color = C(76, 124, 70), material = M.Grass, canCollide = false, canQuery = false, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, 1.0 * scale, 0)), parent = parent,
    })
end

function CityKit.Lamppost(position, color, parent, height, lit)
    height = height or 16
    local model = CityKit.Model("Lamppost", parent)
    BuildKit.Part({
        name = "Pole", size = Vector3.new(0.6, height, 0.6), color = C(48, 48, 54),
        material = M.Metal, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, height * 0.5, 0)), parent = model,
    })
    local head = BuildKit.Part({
        name = "Head", size = Vector3.new(1.5, 1.0, 1.5), color = color or C(255, 226, 170),
        material = M.Neon, canCollide = false, canQuery = false, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, height + 0.4, 0)), parent = model,
    })
    -- La luz es opcional: en una ciudad grande conviene reservarla para las
    -- farolas mas visibles y no llenar la escena de luces dinamicas.
    if lit ~= false and CityKit.AllowLight() then
        local light = Instance.new("PointLight")
        light.Color = color or C(255, 226, 170)
        light.Brightness = 1.6
        light.Range = 30
        light.Shadows = false
        light.Parent = head
    end
    return model
end

function CityKit.Bench(position, parent, facing)
    local model = CityKit.Model("Bench", parent)
    local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(facing or 0), 0)
    BuildKit.Part({
        name = "Seat", size = Vector3.new(6.0, 0.3, 1.8), color = C(126, 88, 52), material = M.Wood,
        castShadow = false, cframe = cf * CFrame.new(0, 1.4, 0), parent = model,
    })
    BuildKit.Part({
        name = "Back", size = Vector3.new(6.0, 1.6, 0.25), color = C(126, 88, 52), material = M.Wood,
        castShadow = false, cframe = cf * CFrame.new(0, 2.2, -0.8), parent = model,
    })
    for _, sx in ipairs({ -2.4, 2.4 }) do
        BuildKit.Part({
            name = "Leg", size = Vector3.new(0.3, 1.4, 1.6), color = C(70, 70, 76), material = M.Metal,
            castShadow = false, cframe = cf * CFrame.new(sx, 0.7, 0), parent = model,
        })
    end
    return model
end

function CityKit.TrashCan(position, parent)
    local model = CityKit.Model("TrashCan", parent)
    BuildKit.Part({
        name = "Body", shape = Enum.PartType.Cylinder, size = Vector3.new(3.0, 2.4, 2.4),
        color = C(58, 62, 68), material = M.Metal, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        parent = model,
    })
    return model
end

function CityKit.Planter(position, parent, rand)
    local model = CityKit.Model("Planter", parent)
    BuildKit.Part({
        name = "Box", size = Vector3.new(4.4, 1.6, 4.4), color = C(160, 150, 134),
        material = M.Concrete, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, 0.8, 0)), parent = model,
    })
    CityKit.Bush(position + Vector3.new(0, 1.2, 0), model, 1.1)
    return model
end

function CityKit.Hydrant(position, parent)
    return BuildKit.Part({
        name = "Hydrant", shape = Enum.PartType.Cylinder, size = Vector3.new(2.2, 1.0, 1.0),
        color = C(198, 62, 54), material = M.Metal, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        parent = parent,
    })
end

--[[ NOTA: aqui vivia CityKit.ParkedCar, el generador de coches decorativos.
     El diseno actual NO quiere coches repartidos por la ciudad: el patinete
     (VehicleConfig/VehicleFactory + VehicleService) es el primer vehiculo
     jugable. Se ha eliminado el generador para que no vuelva a crearlos y
     CityBuilder.PurgeLegacyCars() limpia los que pudieran quedar en el place.
     Se conservan carreteras, aceras, plazas de aparcamiento y demas mobiliario. ]]

--[[ Cartel de negocio: panel + texto legible (SurfaceGui). `toward` es la
     direccion hacia el lector. ]]
function CityKit.SignBoard(parent, position, toward, size, bg, text, textColor, font)
    local cf = CFrame.lookAt(position, position + toward)
    local board = BuildKit.Part({
        name = "SignBoard", size = size, color = bg or C(22, 24, 30), material = M.SmoothPlastic,
        canCollide = false, canQuery = false, castShadow = false, cframe = cf, parent = parent,
    })
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.CanvasSize = Vector2.new(640, 200)
    gui.Parent = board
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = font or Enum.Font.GothamBlack
    label.Text = text
    label.TextColor3 = textColor or C(255, 255, 255)
    label.TextScaled = true
    label.TextWrapped = true
    label.Parent = gui
    return board
end

return CityKit
