--[[
    PlazaBuilder
    Ruta en Roblox Studio: ServerScriptService > PlazaBuilder
    Tipo: ModuleScript

    Construye la PLAZA CENTRAL: punto de aparicion de todos los jugadores y
    zona de fumar principal. Es el nudo del que salen las cuatro avenidas.

        * suelo de baldosas con varias capas de material (sin z-fighting),
        * disco de la ZONA DE FUMADORES (radio = ZoneConfig.SmokingZone.radius),
        * fuente, bancos, maceteros, arboles, farolas, papeleras, hidrante,
        * carteles de la ciudad y zona de TUTORIAL con paneles explicativos,
        * SpawnLocation integrado y mirando al centro.

    Requiere: BuildKit, CityKit, CityGrid, ZoneConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGrid = require(Shared:WaitForChild("CityGrid"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

local BuildKit = require(script.Parent:WaitForChild("BuildKit"))
local CityKit = require(script.Parent:WaitForChild("CityKit"))

local PlazaBuilder = {}

local M = Enum.Material
local C = Color3.fromRGB
local WALK = CityGrid.Levels.walk
local HALF = CityGrid.Plaza.half
local PAL = CityKit.Palette
local SMOKE_R = ZoneConfig.SmokingZone.radius
local SMOKE_EDGE = SMOKE_R + 8

local function disc(name, center, radius, top, thickness, color, material, parent, transparency)
    return BuildKit.Part({
        name = name, shape = Enum.PartType.Cylinder,
        size = Vector3.new(thickness, radius * 2, radius * 2),
        color = color, material = material,
        transparency = transparency,
        canCollide = false, canQuery = false, castShadow = false,
        cframe = CFrame.new(center.X, top - thickness * 0.5, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
        parent = parent,
    })
end

--[[ Suelo de la plaza: capas a alturas ligeramente distintas para que no
     aparezcan parpadeos entre superficies. ]]
local function buildFloor(parent, rand)
    CityKit.Rect("PlazaBase", -HALF, -HALF, HALF, HALF, WALK, 1.2, PAL.plazaStone, M.Concrete, parent,
        { canCollide = true })

    -- Cuadrantes con damero de baldosas
    for _, qx in ipairs({ -1, 1 }) do
        for _, qz in ipairs({ -1, 1 }) do
            local cx = qx * HALF * 0.5
            local cz = qz * HALF * 0.5
            local qh = HALF * 0.5
            for i = 0, 1 do
                for j = 0, 1 do
                    local c = ((i + j) % 2 == 0) and PAL.tileA or PAL.tileB
                    CityKit.Rect("PlazaTile",
                        cx - qh + i * qh, cz - qh + j * qh,
                        cx - qh + (i + 1) * qh, cz - qh + (j + 1) * qh,
                        WALK + 0.03, 0.12, c, M.Slate, parent, {})
                end
            end
        end
    end

    -- Bandas en cruz (itinerarios principales desde las 4 avenidas)
    CityKit.Rect("PlazaBand", -HALF, -13, HALF, 13, WALK + 0.06, 0.12, PAL.tileAccent, M.Marble, parent, {})
    CityKit.Rect("PlazaBand", -13, -HALF, 13, HALF, WALK + 0.06, 0.12, PAL.tileAccent, M.Marble, parent, {})

    -- Anillos concentricos
    disc("PlazaRing", Vector3.new(0, 0, 0), 98, WALK + 0.09, 0.12, PAL.tileA, M.Marble, parent)
    disc("PlazaRing", Vector3.new(0, 0, 0), 90, WALK + 0.10, 0.12, PAL.tileB, M.Slate, parent)
    disc("PlazaRing", Vector3.new(0, 0, 0), 46, WALK + 0.12, 0.12, PAL.tileAccent, M.Marble, parent)

    -- Zona verde en las esquinas
    for _, qx in ipairs({ -1, 1 }) do
        for _, qz in ipairs({ -1, 1 }) do
            CityKit.Rect("PlazaGrass",
                qx * HALF - 74, qz * HALF - 74, qx * HALF - 8, qz * HALF - 8,
                WALK + 0.04, 0.2, PAL.grass, M.Grass, parent, {})
        end
    end

    -- Disco de la ZONA DE FUMADORES (donde el servidor valida las caladas)
    local r = ZoneConfig.SmokingZone.radius
    disc("SmokingFloor", Vector3.new(0, 0, 0), r, WALK + 0.16, 0.14, C(90, 200, 255), M.Neon, parent, 0.72)
    disc("SmokingRim", Vector3.new(0, 0, 0), r + 1.4, WALK + 0.18, 0.1, C(150, 235, 255), M.Neon, parent, 0.35)
    disc("SmokingRim", Vector3.new(0, 0, 0), r - 1.4, WALK + 0.18, 0.1, C(150, 235, 255), M.Neon, parent, 0.35)
end

--[[ Fuente central. ]]
local function buildFountain(parent)
    disc("FountainBase", Vector3.new(0, 0, 0), 26, WALK + 0.4, 0.9, C(176, 174, 168), M.Marble, parent)
    disc("FountainLip", Vector3.new(0, 0, 0), 23, WALK + 1.5, 0.4, C(150, 148, 144), M.Marble, parent)
    disc("FountainWater", Vector3.new(0, 0, 0), 19.5, WALK + 1.5, 0.3, C(120, 200, 240), M.Glass, parent, 0.35)
    BuildKit.Part({
        name = "FountainPillar", shape = Enum.PartType.Cylinder, size = Vector3.new(9, 4.6, 4.6),
        color = C(190, 188, 180), material = M.Marble, castShadow = false,
        cframe = CFrame.new(0, WALK + 4.2, 0) * CFrame.Angles(0, 0, math.rad(90)), parent = parent,
    })
    disc("FountainTop", Vector3.new(0, 0, 0), 7, WALK + 9.2, 0.5, C(190, 188, 180), M.Marble, parent)
end

--[[ Mobiliario repartido en anillos alrededor del centro. ]]
local function buildFurniture(parent, rand)
    -- Bancos
    for i = 1, 12 do
        local ang = (i / 12) * math.pi * 2
        local p = Vector3.new(math.cos(ang) * 178, WALK, math.sin(ang) * 178)
        CityKit.Bench(p, parent, math.deg(ang) + 180)
    end
    for i = 1, 8 do
        local ang = (i / 8) * math.pi * 2 + 0.4
        local p = Vector3.new(math.cos(ang) * 120, WALK, math.sin(ang) * 120)
        CityKit.Bench(p, parent, math.deg(ang) + 180)
    end

    -- Maceteros y arboles
    for i = 1, 16 do
        local ang = (i / 16) * math.pi * 2 + 0.2
        local p = Vector3.new(math.cos(ang) * 158, WALK, math.sin(ang) * 158)
        if i % 2 == 0 then
            CityKit.Planter(p, parent, rand)
        else
            CityKit.Tree(p, parent, 1.05, rand)
        end
    end
    for i = 1, 10 do
        local ang = (i / 10) * math.pi * 2
        local p = Vector3.new(math.cos(ang) * 214, WALK, math.sin(ang) * 214)
        CityKit.Tree(p, parent, 1.2, rand)
    end

    -- Farolas (con luz solo las del anillo exterior para no cargar la escena)
    for i = 1, 12 do
        local ang = (i / 12) * math.pi * 2 + 0.26
        local p = Vector3.new(math.cos(ang) * 200, WALK, math.sin(ang) * 200)
        CityKit.Lamppost(p, C(150, 225, 255), parent, 15, i % 2 == 0)
    end

    -- Papeleras e hidrantes
    for i = 1, 8 do
        local ang = (i / 8) * math.pi * 2 + 0.7
        CityKit.TrashCan(Vector3.new(math.cos(ang) * 146, WALK, math.sin(ang) * 146), parent)
    end
    CityKit.Hydrant(Vector3.new(-96, WALK, 150), parent)
    CityKit.Hydrant(Vector3.new(96, WALK, -150), parent)
end

--[[ Carteles y zona de tutorial. ]]
local function buildSignage(parent)
    -- Rotulo principal de la ciudad, en el borde norte mirando al centro
    CityKit.SignBoard(parent, Vector3.new(0, WALK + 20, HALF - 6), Vector3.new(0, 0, -1),
        Vector3.new(76, 16, 1.2), C(18, 22, 32), "HOW TO VAPE", C(120, 220, 255))
    CityKit.SignBoard(parent, Vector3.new(0, WALK + 11, HALF - 6), Vector3.new(0, 0, -1),
        Vector3.new(60, 3.6, 1.0), C(18, 22, 32), "PLAZA CENTRAL  ·  ZONA DE FUMADORES", C(200, 235, 255),
        Enum.Font.GothamBold)

    -- Rotulo de la zona de fumadores
    CityKit.SignBoard(parent, Vector3.new(-SMOKE_EDGE, WALK + 12, -HALF + 8), Vector3.new(0, 0, 1),
        Vector3.new(52, 6, 1.0), C(20, 34, 44), "PULSA PUFF AQUI PARA GANAR PUFFS", C(150, 235, 255))

    -- Paneles de tutorial en el cuadrante noreste
    local steps = {
        { "1. CONSIGUE PUFFS", "Entra en el circulo azul y pulsa el boton PUFF. Cuanto mejor sea tu vaper, mas Puffs por calada." },
        { "2. ENCUENTRA DEALERS", "Los dealers viven DENTRO de las casas. Sigue las calles y busca los rotulos de las fachadas." },
        { "3. ABRE LAS CASAS", "Cada puerta pide Puffs. Se pagan UNA vez: el acceso queda para siempre en tu cuenta." },
        { "4. MEJORA TU VAPER", "Hay 15 dispositivos repartidos por los 8 barrios. Cada uno multiplica tus Puffs." },
    }
    local boardColor = C(24, 30, 42)
    for i, s in ipairs(steps) do
        local z = 60 + (i - 1) * 34
        local x = 120
        local pos = Vector3.new(x, WALK + 9, z)
        CityKit.SignBoard(parent, pos, Vector3.new(-1, 0, -0.15), Vector3.new(46, 9, 1.0), boardColor,
            s[1] .. "\n" .. s[2], C(230, 240, 255), Enum.Font.GothamMedium)
        BuildKit.Part({
            name = "TutorialPost", size = Vector3.new(1.0, 8, 1.0), color = C(70, 74, 84), material = M.Metal,
            castShadow = false, cframe = CFrame.new(x, WALK + 4, z - 3), parent = parent,
        })
    end
end

local function rOffset()
    return SMOKE_EDGE
end

--[[ Construye la plaza completa y el punto de aparicion. ]]

function PlazaBuilder.Build(parent)
    local rand = CityKit.Rng(20261009)

    parent = parent or workspace.Plaza or workspace
    buildFloor(parent, rand)
    buildFountain(parent)
    buildFurniture(parent, rand)
    buildSignage(parent)

    -- SpawnLocation integrado y mirando al centro de la ciudad.
    local existing = workspace:FindFirstChild("SpawnLocation")
    if existing then
        existing:Destroy()
    end
    local sp = Instance.new("SpawnLocation")
    sp.Name = "SpawnLocation"
    sp.Anchored = true
    sp.Size = Vector3.new(18, 1.2, 18)
    sp.CFrame = CFrame.lookAt(CityGrid.Plaza.spawn + Vector3.new(0, WALK + 0.6, 0), Vector3.new(0, WALK + 0.6, 0))
    sp.TopSurface = Enum.SurfaceType.Smooth
    sp.BottomSurface = Enum.SurfaceType.Smooth
    sp.Color = C(70, 200, 255)
    sp.Material = M.Neon
    sp.Transparency = 0.15
    sp.Duration = 0
    sp.Parent = workspace

    -- Base del spawn para que no quede flotando
    CityKit.Rect("SpawnPad", -14, 182, 14, 210, WALK + 0.2, 0.3, C(120, 210, 240), M.Neon, parent, {})
end

return PlazaBuilder
