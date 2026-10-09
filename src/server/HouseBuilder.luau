--[[
    HouseBuilder
    Ruta en Roblox Studio: ServerScriptService > HouseBuilder
    Tipo: ModuleScript

    Construye una CASA FUNCIONAL completa a partir de su definicion en
    ZoneConfig.Houses:

      * Exterior: fachada, tejado, ventanas, jardin, camino, valla, arbol, buzon.
      * Puerta funcional: una Part solida con atributos ClosedCFrame/OpenCFrame.
        El servidor la deja CERRADA y con colision. Cada cliente la abre en
        LOCAL para el jugador que ya la desbloqueo (ver DoorClient): asi el
        acceso es por jugador, permanente y sin coste repetido, sin replicar
        nada por la red ni usar grupos de colision (imposible por jugador).
      * Interior amueblado segun `house.tier`, con distribucion despejada para
        no quedarse atrapado.
      * Dealer NPC dentro, con cartel y ProximityPrompt de tienda.

    Coordenadas locales: +Y arriba, +Z es la FACHADA (mira al centro del
    distrito, por donde llega el jugador). El modelo se gira con `facing`.

    Requiere: BuildKit, ZoneConfig, VapeConfig.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildKit = require(script.Parent:WaitForChild("BuildKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

local HouseBuilder = {}

local M = Enum.Material
local C = Color3.fromRGB

local function pick(list, seed)
    return list[((seed - 1) % #list) + 1]
end

-- Mobiliario -------------------------------------------------------------------
local function furnish(model, base, house, style, accent)
    local w, d = house.w, house.d
    local floorY = 0.6
    local tier = house.tier or "mid"
    local wood = C(120, 86, 58)
    local darkWood = C(70, 50, 34)
    local cloth = C(90, 96, 120)

    local function L(x, y, z)
        return base * CFrame.new(x, y, z)
    end

    -- Alfombra
    if tier ~= "poor" then
        BuildKit.Part({ name = "Rug", size = Vector3.new(w * 0.42, 0.06, d * 0.34),
            color = C(120, 60, 80), material = M.Fabric, canCollide = false, castShadow = false,
            cframe = L(0, floorY + 0.03, 0), parent = model })
    end

    -- Sofa contra la pared izquierda
    local sofaZ = 0
    BuildKit.Part({ name = "SofaBase", size = Vector3.new(2.2, 1.0, 6),
        color = cloth, material = M.Fabric, castShadow = true,
        cframe = L(-w / 2 + 1.8, floorY + 0.5, sofaZ), parent = model })
    BuildKit.Part({ name = "SofaBack", size = Vector3.new(0.5, 1.6, 6),
        color = cloth, material = M.Fabric,
        cframe = L(-w / 2 + 0.8, floorY + 1.1, sofaZ), parent = model })

    -- Mesa de centro
    BuildKit.Part({ name = "TableTop", size = Vector3.new(2.6, 0.2, 3.2),
        color = wood, material = M.Wood,
        cframe = L(-w / 2 + 5.2, floorY + 1.3, sofaZ), parent = model })
    for _, z in ipairs({ -1.2, 1.2 }) do
        BuildKit.Part({ name = "TableLeg", size = Vector3.new(0.2, 1.3, 0.2),
            color = darkWood, material = M.Wood, castShadow = false,
            cframe = L(-w / 2 + 5.2, floorY + 0.65, sofaZ + z), parent = model })
    end

    -- TV / estanteria en la pared izquierda opuesta
    BuildKit.Part({ name = "TVStand", size = Vector3.new(1.2, 1.6, 5),
        color = darkWood, material = M.Wood,
        cframe = L(w / 2 - 1.4, floorY + 0.8, sofaZ), parent = model })
    BuildKit.Part({ name = "TV", size = Vector3.new(0.2, 2.0, 3.6),
        color = C(12, 12, 16), material = M.Metal, castShadow = false,
        cframe = L(w / 2 - 1.9, floorY + 2.4, sofaZ), parent = model })

    -- Estanteria / libreria
    if tier == "rich" or tier == "luxury" then
        BuildKit.Part({ name = "Shelf", size = Vector3.new(4, 0.3, 1.2),
            color = wood, material = M.Wood,
            cframe = L(w / 2 - 2.5, floorY + 3.4, -d / 2 + 1.6), parent = model })
        BuildKit.Part({ name = "Shelf", size = Vector3.new(4, 0.3, 1.2),
            color = wood, material = M.Wood,
            cframe = L(w / 2 - 2.5, floorY + 2.2, -d / 2 + 1.6), parent = model })
    end

    -- Mesa alta + taburetes (tier alto)
    if tier == "luxury" then
        BuildKit.Part({ name = "Island", size = Vector3.new(1.6, 1.6, 4.4),
            color = C(230, 228, 224), material = M.Marble,
            cframe = L(-w / 2 + 3.4, floorY + 0.8, d / 2 - 3.4), parent = model })
        for _, x in ipairs({ -w / 2 + 5.2, -w / 2 + 2.2 }) do
            BuildKit.Part({ name = "Stool", size = Vector3.new(0.9, 1.4, 0.9),
                color = darkWood, material = M.Wood,
                cframe = L(x, floorY + 0.7, d / 2 - 2.2), parent = model })
        end
    end

    -- Planta decorativa
    BuildKit.Part({ name = "Pot", size = Vector3.new(1.0, 1.2, 1.0),
        color = C(150, 90, 70), material = M.Brick, castShadow = false,
        cframe = L(w / 2 - 2.2, floorY + 0.6, d / 2 - 2.2), parent = model })
    BuildKit.Part({ name = "PlantLeaves", shape = Enum.PartType.Ball, size = Vector3.new(2.6, 2.6, 2.6),
        color = C(70, 130, 72), material = M.Grass, canCollide = false, castShadow = false,
        cframe = L(w / 2 - 2.2, floorY + 2.6, d / 2 - 2.2), parent = model })

    -- Luz de techo
    local lamp = BuildKit.Part({ name = "CeilingLamp", size = Vector3.new(1.2, 0.3, 1.2),
        color = accent, material = M.Neon, canCollide = false, castShadow = false,
        cframe = L(0, floorY + house.h - 0.8, 0), parent = model })
    local light = Instance.new("PointLight")
    light.Color = tier == "poor" and C(255, 220, 170) or accent
    light.Brightness = 2.4
    light.Range = math.max(w, d) * 1.6
    light.Shadows = false
    light.Parent = lamp
end

-- Dealer NPC -------------------------------------------------------------------
local function buildDealer(model, base, house, style, accent)
    local w, d = house.w, house.d
    local floorY = 0.6
    local dealer = house.dealer

    local function L(x, y, z)
        return base * CFrame.new(x, y, z)
    end

    -- Mostrador entre la puerta y el dealer (despeja el paso)
    BuildKit.Part({ name = "Counter", size = Vector3.new(6, 1.4, 1.6),
        color = C(80, 62, 44), material = M.Wood,
        cframe = L(0, floorY + 0.7, -d / 2 + 4.2), parent = model })

    local footY = floorY + 0.0
    local bodyY = footY + 1.2
    BuildKit.Part({ name = "Legs", size = Vector3.new(1.8, 2.4, 1),
        color = C(40, 40, 48), material = M.SmoothPlastic,
        cframe = L(0, footY + 1.2, -d / 2 + 2.6), parent = model })
    local torso = BuildKit.Part({ name = "Torso", size = Vector3.new(2, 2.6, 1),
        color = dealer.color, material = M.SmoothPlastic,
        cframe = L(0, footY + 3.7, -d / 2 + 2.6), parent = model })
    BuildKit.Part({ name = "Head", size = Vector3.new(1.3, 1.3, 1.3),
        color = C(235, 200, 170), material = M.SmoothPlastic,
        cframe = L(0, footY + 5.7, -d / 2 + 2.6), parent = model })
    BuildKit.Part({ name = "Halo", size = Vector3.new(1.8, 0.3, 1.8),
        color = accent, material = M.Neon, canCollide = false, castShadow = false,
        cframe = L(0, footY + 6.7, -d / 2 + 2.6), parent = model })

    -- El prompt va en el mostrador: se interactua de frente, sin atravesar al NPC.
    local counter = model:FindFirstChild("Counter")
    BuildKit.FloatingLabel(torso, "DEALER " .. dealer.name, dealer.line, dealer.color)
    if counter then
        BuildKit.Prompt(counter, "Abrir tienda", "Dealer", house.id, 0)
    end
    return torso
end

-- Fachada / estructura ----------------------------------------------------------
local function buildShell(model, base, house, style)
    local w, d, h = house.w, house.d, house.h
    local t = 0.8                     -- grosor de pared
    local floorY = 0.6                -- altura del suelo interior
    local dw = 5                      -- ancho de la puerta
    local dh = 9                      -- alto de la puerta

    local wallColor = pick(style.wall, #house.id)
    local roofColor = pick(style.roof, #house.id)

    local function L(x, y, z)
        return base * CFrame.new(x, y, z)
    end

    -- Cimentacion + suelo interior
    BuildKit.Part({ name = "Foundation", size = Vector3.new(w + 2, 0.6, d + 2),
        color = C(120, 118, 112), material = M.Concrete,
        cframe = L(0, 0.3, 0), parent = model })
    BuildKit.Part({ name = "Floor", size = Vector3.new(w, 0.3, d),
        color = C(150, 120, 88), material = M.Wood,
        cframe = L(0, floorY - 0.15, 0), parent = model })

    -- Paredes (la frontal se parte para dejar el hueco de la puerta)
    local side = (w - dw) / 2
    local sideX = (dw + side) / 2
    BuildKit.Part({ name = "WallFrontL", size = Vector3.new(side, h, t),
        color = wallColor, material = style.material,
        cframe = L(-sideX, floorY + h / 2, d / 2), parent = model })
    BuildKit.Part({ name = "WallFrontR", size = Vector3.new(side, h, t),
        color = wallColor, material = style.material,
        cframe = L(sideX, floorY + h / 2, d / 2), parent = model })
    -- Dintel (encima de la puerta)
    BuildKit.Part({ name = "WallHeader", size = Vector3.new(dw, h - dh, t),
        color = wallColor, material = style.material,
        cframe = L(0, floorY + dh + (h - dh) / 2, d / 2), parent = model })
    BuildKit.Part({ name = "WallBack", size = Vector3.new(w, h, t),
        color = wallColor, material = style.material,
        cframe = L(0, floorY + h / 2, -d / 2), parent = model })
    BuildKit.Part({ name = "WallLeft", size = Vector3.new(t, h, d),
        color = wallColor, material = style.material,
        cframe = L(-w / 2, floorY + h / 2, 0), parent = model })
    BuildKit.Part({ name = "WallRight", size = Vector3.new(t, h, d),
        color = wallColor, material = style.material,
        cframe = L(w / 2, floorY + h / 2, 0), parent = model })

    -- Ventanas
    BuildKit.Window(model, L(-sideX, floorY + h * 0.6, d / 2 + 0.1), Vector3.new(side * 0.6, h * 0.34, 0.3))
    BuildKit.Window(model, L(sideX, floorY + h * 0.6, d / 2 + 0.1), Vector3.new(side * 0.6, h * 0.34, 0.3))
    BuildKit.Window(model, L(-w / 2 - 0.1, floorY + h * 0.6, 0), Vector3.new(0.3, h * 0.34, d * 0.42))
    BuildKit.Window(model, L(w / 2 + 0.1, floorY + h * 0.6, 0), Vector3.new(0.3, h * 0.34, d * 0.42))
    BuildKit.Window(model, L(0, floorY + h * 0.6, -d / 2 - 0.1), Vector3.new(w * 0.4, h * 0.34, 0.3))

    -- Tejado
    if house.roofStyle == "gable" then
        local half = d / 2 + 0.8
        local angle = math.rad(28)
        local rise = math.tan(angle) * half
        local slant = half / math.cos(angle)
        local topY = floorY + h
        for _, sign in ipairs({ 1, -1 }) do
            BuildKit.Part({ name = "Roof", size = Vector3.new(w + 2.2, 0.4, slant),
                color = roofColor, material = M.Slate, castShadow = true,
                cframe = L(0, topY + rise / 2, sign * half / 2) * CFrame.Angles(sign * angle, 0, 0),
                parent = model })
        end
        -- Fronton (triangulo aproximado con una pieza)
        BuildKit.Part({ name = "GableWall", size = Vector3.new(w + 0.4, rise, 0.5),
            color = wallColor, material = style.material,
            cframe = L(0, topY + rise / 2, d / 2), parent = model })
    else
        local topY = floorY + h
        BuildKit.Part({ name = "RoofSlab", size = Vector3.new(w + 1.6, 0.6, d + 1.6),
            color = roofColor, material = M.Concrete,
            cframe = L(0, topY + 0.3, 0), parent = model })
        for _, cfg in ipairs({
            { Vector3.new(w + 1.6, 1.2, 0.4), Vector3.new(0, topY + 1.1, d / 2 + 0.6) },
            { Vector3.new(w + 1.6, 1.2, 0.4), Vector3.new(0, topY + 1.1, -d / 2 - 0.6) },
            { Vector3.new(0.4, 1.2, d + 1.6), Vector3.new(w / 2 + 0.6, topY + 1.1, 0) },
            { Vector3.new(0.4, 1.2, d + 1.6), Vector3.new(-w / 2 - 0.6, topY + 1.1, 0) },
        }) do
            BuildKit.Part({ name = "Parapet", size = cfg[1], color = roofColor, material = M.Concrete,
                cframe = L(cfg[2].X, cfg[2].Y, cfg[2].Z), parent = model })
        end
    end

    -- Puerta funcional
    local hingeLocal = CFrame.new(-dw / 2, floorY, d / 2)
    local doorCenterLocal = CFrame.new(0, floorY + dh / 2, d / 2)
    local hingeWorld = base * hingeLocal
    local closedCF = base * doorCenterLocal
    local swing = house.mirror and 110 or -110
    local openCF = hingeWorld * CFrame.Angles(0, math.rad(swing), 0) * (hingeWorld:Inverse() * closedCF)

    local door = BuildKit.Part({
        name = "Door",
        size = Vector3.new(dw - 0.6, dh - 0.4, 0.4),
        color = C(90, 62, 40), material = M.Wood,
        canCollide = true,             -- bloquea hasta que el jugador la desbloquee
        cframe = closedCF,
        parent = model,
    })
    door:SetAttribute("HouseId", house.id)
    door:SetAttribute("ClosedCFrame", closedCF)
    door:SetAttribute("OpenCFrame", openCF)
    CollectionService:AddTag(door, "HouseDoor")
    BuildKit.Prompt(door, "Abrir casa", "House", house.id, 0)

    -- Jardin delantero: camino, valla, arbol, buzon
    BuildKit.Part({ name = "Path", size = Vector3.new(4, 0.2, 8),
        color = C(170, 168, 160), material = M.Concrete, canCollide = false, castShadow = false,
        cframe = L(0, 0.15, d / 2 + 5), parent = model })
    local yard = house.w / 2 + 4
    BuildKit.Fence(base * CFrame.new(-yard, 0, d / 2 + 2), 18, model, style.fence)
    BuildKit.Fence(base * CFrame.new(yard, 0, d / 2 + 2), 18, model, style.fence)
    BuildKit.Tree(base * CFrame.new(-yard + 2, 0, d / 2 + 6).Position, model, 1)
    BuildKit.Part({ name = "Mailbox", size = Vector3.new(0.5, 0.5, 0.9),
        color = C(60, 60, 70), material = M.Metal, castShadow = false,
        cframe = L(3, 1.6, d / 2 + 3) * CFrame.Angles(0, 0, math.rad(0)), parent = model })
    BuildKit.Part({ name = "MailboxPost", size = Vector3.new(0.2, 1.6, 0.2),
        color = C(90, 70, 50), material = M.Wood, castShadow = false,
        cframe = L(3, 0.8, d / 2 + 3), parent = model })
end

--[[ Construye la casa completa. Devuelve (model, doorPart).
     `groundY` eleva la casa hasta la rasante de la ciudad (aceras/solares), ya
     que las posiciones de ZoneConfig son 2D (Y = 0) para la logica de juego. ]]
function HouseBuilder.Build(house, district, groundY)
    local base = CFrame.new(house.position + Vector3.new(0, groundY or 0, 0))
        * CFrame.Angles(0, math.rad(house.facing or 0), 0)
    local style = district.style
    local accent = house.dealer.color

    local container = workspace:FindFirstChild("Houses")
    if not container then
        container = Instance.new("Folder")
        container.Name = "Houses"
        container.Parent = workspace
    end
    local model = BuildKit.Model("House_" .. house.id, container)
    model:SetAttribute("HouseId", house.id)
    model:SetAttribute("District", house.district)
    CollectionService:AddTag(model, "House")

    buildShell(model, base, house, style)
    furnish(model, base, house, style, accent)
    buildDealer(model, base, house, style, accent)

    -- Cartel exterior con el nombre de la casa y el coste de acceso.
    -- La cara Front del SurfaceGui tiene la normal en la direccion del
    -- LookVector, asi que el LookVector debe apuntar HACIA el lector (que
    -- esta delante, en +Z local): lookAt(signPos, signPos + frontDir).
    local signPos = base * CFrame.new(0, house.h + 4, house.d / 2 + 1.2)
    local frontDir = base:VectorToWorldSpace(Vector3.new(0, 0, 1))
    local signCF = CFrame.lookAt(signPos.Position, signPos.Position + frontDir)
    local cost = house.requirement > 0 and ("Acceso: %d Puffs"):format(house.requirement) or "Acceso libre"
    BuildKit.Sign(("%s\n%s"):format(house.name, cost), signCF, accent, model, Vector3.new(12, 4, 0.6))

    local door = model:FindFirstChild("Door", true)
    return model, door
end

return HouseBuilder
