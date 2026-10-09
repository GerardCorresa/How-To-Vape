--[[
    BuildingBuilder
    Ruta en Roblox Studio: ServerScriptService > BuildingBuilder
    Tipo: ModuleScript

    Construye UN edificio completo sobre un solar (`lot`) segun el perfil del
    barrio. Cada tipo tiene silueta, materiales, ventanas y detalles propios,
    para que la ciudad no sea una caja repetida:

        house       casas de 1-2 plantas con jardin, valla, tejado a dos aguas
        lowrise     manzana baja mixta: local en planta baja + 2-3 alturas
        brick       edificio antiguo de ladrillo con cornisas y balcones
        mixed       comercial/residencial con escaparate en planta baja
        office      oficina/rascacielos de cristal con bandas de ventanas
        industrial  nave baja con costillas metalicas, conductos y chimenea
        neon        torre oscura con tiras de neon y rotulo luminoso
        luxury      villa grande con columnas, porche y ventanales

    Todos los edificios son solidos (CanCollide) y anclados. El interior solo se
    detalla en los locales principales (ver ShopBuilder).

    Requiere: BuildKit, CityKit, CityGrid.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGrid = require(Shared:WaitForChild("CityGrid"))

local BuildKit = require(script.Parent:WaitForChild("BuildKit"))
local CityKit = require(script.Parent:WaitForChild("CityKit"))

local BuildingBuilder = {}

local M = Enum.Material
local C = Color3.fromRGB
local WALK = CityGrid.Levels.walk

local YAW = { north = 0, east = 90, south = 180, west = -90 }

local GLASS = C(120, 168, 196)
local DARKGLASS = C(44, 56, 72)
local TRIM = C(226, 226, 222)
local STEEL = C(126, 130, 138)

local function part(model, name, size, color, material, cf, collide, castShadow)
    return BuildKit.Part({
        name = name, size = size, color = color, material = material, cframe = cf,
        canCollide = collide ~= false,
        castShadow = castShadow == true,
        parent = model,
    })
end

-- Ventanas ---------------------------------------------------------------------

--[[ Ventanas individuales sobre una fachada (para pocas plantas). ]]
local function individualWindows(model, cf, w, d, floors, floorH, litChance, rand)
    local perFront = math.clamp(math.floor(w / 14), 2, 4)
    local perSide = math.clamp(math.floor(d / 16), 1, 3)
    for f = 1, floors do
        local y = f * floorH
        local lit = rand() < litChance
        local origin = cf * Vector3.new(0, y, d * 0.5)
        CityKit.WindowRow(model, origin, cf.RightVector, cf.LookVector,
            perFront, w / (perFront + 1) * 1.0, 3.0, 3.6, litChance * 0.5, rand)
        -- Lateral derecho (tambien da a calle en muchas manzanas)
        local sideOrigin = cf * Vector3.new(w * 0.5, y, 0)
        CityKit.WindowRow(model, sideOrigin, cf.LookVector, cf.RightVector,
            perSide, d / (perSide + 1) * 1.0, 2.6, 3.4, litChance * 0.35, rand)
    end
end

--[[ Bandas de ventana por planta (para torres: muchos pisos, pocas piezas). ]]
local function bandWindows(model, cf, w, d, floors, floorH, litChance, rand)
    local halfW, halfD = w * 0.5, d * 0.5
    for f = 1, floors do
        local y = f * floorH
        -- Forjado visible (una pieza por planta)
        part(model, "Slab", Vector3.new(w + 0.7, 0.7, d + 0.7), CityKit.Shade(TRIM, -0.35), M.Concrete,
            cf * CFrame.new(0, y - floorH * 0.5, 0), false, false)
        local lit = rand() < litChance
        local glass = lit and C(255, 226, 168) or GLASS
        local material = lit and M.Neon or M.Glass
        -- Cuatro fachadas: una banda de cristal cada una
        for _, side in ipairs({
            { Vector3.new(0, y, halfD), Vector3.new(0, 0, 1), Vector3.new(w - 1.2, 4.4, 0.35) },
            { Vector3.new(0, y, -halfD), Vector3.new(0, 0, -1), Vector3.new(w - 1.2, 4.4, 0.35) },
            { Vector3.new(halfW, y, 0), Vector3.new(1, 0, 0), Vector3.new(0.35, 4.4, d - 1.2) },
            { Vector3.new(-halfW, y, 0), Vector3.new(-1, 0, 0), Vector3.new(0.35, 4.4, d - 1.2) },
        }) do
            BuildKit.Part({
                name = "GlassBand", size = side[3], color = glass, material = material,
                transparency = lit and 0.05 or 0.32, reflectance = lit and 0 or 0.35,
                canCollide = false, canQuery = false, castShadow = false,
                cframe = cf * CFrame.new(side[1]), parent = model,
            })
        end
    end
end

--[[ Fachada de huecos con pilastras: ventanas individuales agrupadas entre
     franjas verticales de fabrica. Da volumen a las manzanas de 3-9 plantas
     con muy pocas piezas (una pilastra es una sola pieza para toda la altura). ]]
local function piersFacade(model, cf, w, d, floors, floorH, litChance, rand, wall)
    local h = floors * floorH
    local pierColor = CityKit.Shade(wall, -0.14)
    local nP = math.clamp(math.floor(w / 16), 2, 5)
    for i = 1, nP do
        local x = -w * 0.5 + (w / (nP + 1)) * i
        part(model, "Pier", Vector3.new(1.1, h, 1.1), pierColor, M.Concrete,
            cf * CFrame.new(x, h * 0.5, d * 0.5 + 0.5), false, false)
    end
    -- Franja horizontal (cornisa de planta baja) y remate superior
    part(model, "Belt", Vector3.new(w + 0.8, 0.9, d + 0.8), pierColor, M.Concrete,
        cf * CFrame.new(0, floorH * 1.6, 0), false, false)
    -- Ventanas: una fila por planta
    local perFront = math.clamp(math.floor(w / 11), 2, 6)
    for f = 2, floors do
        local lit = rand() < litChance
        CityKit.WindowRow(model, cf * Vector3.new(0, f * floorH, d * 0.5 + 0.1), cf.RightVector,
            cf.LookVector, perFront, w / (perFront + 1), 3.4, 4.0, lit and litChance or litChance * 0.4, rand)
    end
end

-- Detalles ---------------------------------------------------------------------

local function roofAC(model, cf, w, d, rand)
    local n = CityKit.Int(rand, 1, 3)
    for _ = 1, n do
        local x = CityKit.Float(rand, -w * 0.3, w * 0.3)
        local z = CityKit.Float(rand, -d * 0.3, d * 0.3)
        part(model, "ACUnit", Vector3.new(4, 2.2, 3.4), C(150, 152, 156), M.Metal,
            cf * CFrame.new(x, 1.2, z), true, true)
    end
end

local function rooftopDetails(model, cf, w, d, rand, tall)
    part(model, "Parapet", Vector3.new(w + 1.2, 1.4, d + 1.2), CityKit.Shade(TRIM, -0.45), M.Concrete,
        cf * CFrame.new(0, 0.2, 0), false, false)
    roofAC(model, cf * CFrame.new(0, 1.0, 0), w, d, rand)
    if tall and rand() < 0.6 then
        part(model, "Mast", Vector3.new(0.5, 12, 0.5), STEEL, M.Metal,
            cf * CFrame.new(w * 0.2, 6, -d * 0.2), false, false)
        local beacon = part(model, "Beacon", Vector3.new(1.0, 1.0, 1.0), C(255, 70, 70), M.Neon,
            cf * CFrame.new(w * 0.2, 12.4, -d * 0.2), false, false)
        if CityKit.AllowLight() then
            local light = Instance.new("PointLight")
            light.Color = C(255, 70, 70)
            light.Brightness = 1.4
            light.Range = 22
            light.Shadows = false
            light.Parent = beacon
        end
    end
    if rand() < 0.5 then
        part(model, "WaterTank", Vector3.new(4.6, 5.0, 4.6), C(140, 132, 118), M.CorrugatedMetal,
            cf * CFrame.new(-w * 0.22, 3.5, d * 0.18), true, true)
    end
end

--[[ Aparcamiento en altura: forjados abiertos, columnas y pretiles. Es una
     pieza urbana clasica (parking) y muy barata en numero de objetos. ]]
local function parkingDecks(model, cf, w, d, floors, floorH, wall, accent)
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            part(model, "GarageColumn", Vector3.new(3.0, floors * floorH, 3.0), CityKit.Shade(wall, -0.2), M.Concrete,
                cf * CFrame.new(sx * (w * 0.5 - 1.5), floors * floorH * 0.5, sz * (d * 0.5 - 1.5)), true, true)
        end
    end
    part(model, "GarageCore", Vector3.new(w * 0.26, floors * floorH, d * 0.26), CityKit.Shade(wall, -0.28), M.Concrete,
        cf * CFrame.new(0, floors * floorH * 0.5, -d * 0.24), true, true)
    for f = 1, floors do
        local y = f * floorH
        part(model, "Deck", Vector3.new(w + 1.2, 0.9, d + 1.2), CityKit.Shade(wall, -0.1), M.Concrete,
            cf * CFrame.new(0, y, 0), true, true)
        for _, side in ipairs({
            { Vector3.new(0, y + 1.8, d * 0.5 + 0.6), Vector3.new(w + 1.2, 2.6, 0.5) },
            { Vector3.new(0, y + 1.8, -d * 0.5 - 0.6), Vector3.new(w + 1.2, 2.6, 0.5) },
            { Vector3.new(w * 0.5 + 0.6, y + 1.8, 0), Vector3.new(0.5, 2.6, d + 1.2) },
            { Vector3.new(-w * 0.5 - 0.6, y + 1.8, 0), Vector3.new(0.5, 2.6, d + 1.2) },
        }) do
            part(model, "DeckRail", side[2], accent, M.Metal, cf * CFrame.new(side[1]), false, false)
        end
    end
    -- Rampa helicoidal simple (decorativa) y rotulo.
    part(model, "Ramp", Vector3.new(w * 0.4, 0.6, d * 1.1), CityKit.Shade(wall, -0.16), M.Concrete,
        cf * CFrame.new(w * 0.4, 2.2, 0) * CFrame.Angles(math.rad(-9), 0, 0), false, false)
    CityKit.SignBoard(model, (cf * CFrame.new(0, floors * floorH + 2.6, d * 0.5 + 1.4)).Position,
        cf.LookVector, Vector3.new(w * 0.7, 4, 0.5), CityKit.Shade(accent, -0.6), "PARKING", accent)
end

--[[ Jardin delantero de una casa: valla en el borde del solar (con hueco de
     entrada), camino hasta la puerta, arbol y buzon. Todo queda DENTRO del
     solar, asi que las casas vecinas no se pisan. ]]
local function frontYard(model, cfLot, w, frontEdge, houseFront, fenceColor, rand)
    local depth = frontEdge - houseFront
    if depth < 5 then
        return
    end
    local midZ = (frontEdge + houseFront) * 0.5

    -- Camino de entrada hasta la puerta
    part(model, "Path", Vector3.new(4.5, 0.25, depth), C(168, 166, 158), M.Concrete,
        cfLot * CFrame.new(-w * 0.14, 0.12, midZ), false, false)

    -- Valla frontal (con hueco para el camino)
    local count = math.max(2, math.floor(w / 7))
    for i = 0, count do
        local x = -w * 0.5 + w * (i / count)
        if math.abs(x) > 3.5 then
            part(model, "YardFence", Vector3.new(0.4, 3.0, 0.4), fenceColor, M.Wood,
                cfLot * CFrame.new(x, 1.5, frontEdge - 1.4), false, false)
        end
    end
    -- Vallas laterales
    for _, sx in ipairs({ -w * 0.5, w * 0.5 }) do
        local n = math.max(1, math.floor(depth / 8))
        for i = 1, n do
            part(model, "YardFence", Vector3.new(0.4, 3.0, 0.4), fenceColor, M.Wood,
                cfLot * CFrame.new(sx, 1.5, houseFront + depth * (i / (n + 1))), false, false)
        end
    end

    CityKit.Tree((cfLot * CFrame.new(w * 0.33, 0, midZ + 1)).Position, model, 0.9, rand)
    part(model, "Mailbox", Vector3.new(0.6, 0.6, 1.0), C(60, 60, 70), M.Metal,
        cfLot * CFrame.new(w * 0.3, 2.6, frontEdge - 1.6), false, false)
    part(model, "MailboxPost", Vector3.new(0.22, 2.4, 0.22), C(90, 70, 50), M.Wood,
        cfLot * CFrame.new(w * 0.3, 1.2, frontEdge - 1.6), false, false)
end

local function gableRoof(model, cf, w, d, rise, color, material)
    local half = d * 0.5 + 0.9
    local angle = math.atan(rise / half)
    local slant = math.sqrt(half * half + rise * rise)
    for _, s in ipairs({ 1, -1 }) do
        part(model, "Roof", Vector3.new(w + 2.0, 0.6, slant), color, material,
            cf * CFrame.new(0, rise * 0.5, s * half * 0.5) * CFrame.Angles(s * angle, 0, 0), false, true)
    end
    part(model, "Gable", Vector3.new(w + 0.6, rise, 0.6), CityKit.Shade(color, 0.25), material,
        cf * CFrame.new(0, rise * 0.5, d * 0.5), false, true)
end

-- Constructor principal ----------------------------------------------------------

function BuildingBuilder.Build(lot, parent)
    local profile = lot.profile
    local style = lot.style
    local kind = profile.kind
    local rand = CityKit.Rng(math.floor(lot.cx) * 73856093 + math.floor(lot.cz) * 19349663 + 7)

    -- Variedad dentro de la misma manzana: el perfil puede ofrecer varias
    -- siluetas y cada solar elige la suya (fachada urbana variada, no repetida).
    if profile.kinds then
        kind = CityKit.Pick(rand, profile.kinds)
    end
    local variant = CityKit.Int(rand, 1, 3)

    local w = math.max(20, lot.w - 3)
    local d = math.max(20, lot.d - 3)
    local floors = CityKit.Int(rand, profile.floors[1], profile.floors[2])
    if kind == "garage" then
        floors = math.max(3, floors)
    end
    local floorH = (kind == "office" or kind == "neon") and 7 or 6
    local h = floors * floorH

    local wall = CityKit.Pick(rand, style.wall or { C(180, 180, 180) })
    local roofColor = CityKit.Pick(rand, style.roof or { C(95, 95, 100) })
    local accent = style.accent or C(120, 200, 255)

    local model = CityKit.Model("Building_" .. kind, parent)
    local cfLot = CFrame.new(lot.cx, WALK, lot.cz) * CFrame.Angles(0, math.rad(YAW[lot.facing] or 0), 0)
    local cf = cfLot
    local yardFront = nil
    local yardStart = nil

    -- Las casas se retrasan al fondo del solar: asi tienen jardin delantero
    -- (camino, valla, arbol) sin invadir el solar vecino.
    if kind == "house" or kind == "luxury" then
        local dHouse = math.min(d, (kind == "luxury") and 30 or 24)
        local oz = -(d - dHouse) * 0.5
        yardFront = d * 0.5
        d = dHouse
        yardStart = oz + d * 0.5
        cf = cfLot * CFrame.new(0, 0, oz)
    end

    -- Cuerpo
    local material = style.material or M.Concrete
    if kind == "office" then material = M.Concrete
    elseif kind == "neon" then material = M.Metal
    elseif kind == "industrial" then material = M.CorrugatedMetal
    elseif kind == "brick" then material = M.Brick
    elseif kind == "apartment" then material = (variant == 2) and M.Brick or M.Concrete
    elseif kind == "hotel" then material = M.Concrete
    elseif kind == "garage" then material = M.Concrete
    elseif kind == "luxury" then material = M.Marble
    end
    -- Cuerpo macizo (los aparcamientos se resuelven con forjados abiertos)
    if kind ~= "garage" then
        part(model, "Body", Vector3.new(w, h, d), wall, material, cf * CFrame.new(0, h * 0.5, 0), true, true)

        -- Zocalo / planta baja
        part(model, "Base", Vector3.new(w + 0.6, 2.2, d + 0.6), CityKit.Shade(wall, -0.2), M.Concrete,
            cf * CFrame.new(0, 1.1, 0), false, false)
    end

    -- Acceso: vestibulo decorativo (estos edificios NO se pueden visitar, asi
    -- que no se les pone puerta "funcional": un frente de cristal y una
    -- marquesina dejan claro que solo son fachada urbana).
    if kind ~= "garage" and kind ~= "industrial" and kind ~= "house" then
        local lobbyW = math.min(w * 0.5, kind == "hotel" and 16 or 11)
        part(model, "Lobby", Vector3.new(lobbyW, 5.2, 0.4), C(158, 196, 216), M.Glass,
            cf * CFrame.new(-w * 0.16, 2.8, d * 0.5 + 0.1), false, false)
        part(model, "LobbyFrame", Vector3.new(lobbyW + 1.6, 0.6, 0.9), CityKit.Shade(wall, -0.32), M.Metal,
            cf * CFrame.new(-w * 0.16, 5.7, d * 0.5 + 0.2), false, false)
        part(model, "Canopy", Vector3.new(lobbyW + 3.4, 0.6, 3.6), CityKit.Shade(wall, -0.42), M.Metal,
            cf * CFrame.new(-w * 0.16, 6.4, d * 0.5 + 1.6), false, false)
    end

    -- Escaparate en planta baja para manzanas mixtas y comercios de barrio
    if kind == "mixed" or kind == "lowrise" or kind == "brick" or kind == "hotel" then
        part(model, "Storefront", Vector3.new(w * 0.46, 4.2, 0.35), GLASS, M.Glass,
            cf * CFrame.new(w * 0.22, 3.0, d * 0.5 + 0.08), false, false)
    end

    -- Ventanas: la silueta de la fachada cambia con la variante del solar.
    local litChance = profile.lit or 0.3
    if kind ~= "garage" then
        if variant == 3 and floors >= 2 and floors <= 6 then
            piersFacade(model, cf, w, d, floors, floorH, litChance, rand, wall)
        elseif floors >= 4 then
            bandWindows(model, cf, w, d, floors, floorH, litChance, rand)
        else
            individualWindows(model, cf, w, d, floors, floorH, litChance, rand)
        end
    end

    -- Balcones en residencial de varias alturas
    if (kind == "mixed" or kind == "brick" or kind == "lowrise" or kind == "apartment" or kind == "hotel")
        and floors >= 3 then
        local balconyCount = (kind == "apartment") and 3 or 2
        for f = 2, floors do
            for i = 1, balconyCount do
                local sx = -0.34 + (0.68 / math.max(1, balconyCount - 1)) * (i - 1)
                if balconyCount == 1 then
                    sx = 0
                end
                part(model, "Balcony", Vector3.new(w * 0.24, 0.4, 2.2), CityKit.Shade(wall, -0.12), M.Concrete,
                    cf * CFrame.new(w * sx, f * floorH - 0.6, d * 0.5 + 0.9), true, true)
                part(model, "BalconyRail", Vector3.new(w * 0.24, 1.3, 0.2), C(60, 60, 66), M.Metal,
                    cf * CFrame.new(w * sx, f * floorH + 0.15, d * 0.5 + 1.9), false, false)
            end
        end
    end

    -- Tejados y remates
    local topY = h
    if kind == "house" then
        gableRoof(model, cf * CFrame.new(0, topY, 0), w, d, math.max(3, d * 0.22), roofColor, M.Slate)
        -- Jardin delantero: camino, valla, arbol y buzon (dentro del solar)
        frontYard(model, cfLot, w, yardFront, yardStart, C(226, 226, 230), rand)
    elseif kind == "luxury" then
        gableRoof(model, cf * CFrame.new(0, topY, 0), w, d, math.max(4, d * 0.26), roofColor, M.Slate)
        for _, sx in ipairs({ -0.3, 0, 0.3 }) do
            part(model, "Column", Vector3.new(1.6, h * 0.55, 1.6), CityKit.Shade(wall, 0.12), M.Marble,
                cf * CFrame.new(w * sx, h * 0.28, d * 0.5 + 2.6), true, true)
        end
        part(model, "PorchRoof", Vector3.new(w + 2, 0.9, 6), roofColor, M.Slate,
            cf * CFrame.new(0, h * 0.56 + 1.2, d * 0.5 + 2.6), true, true)
        rooftopDetails(model, cf * CFrame.new(0, topY - 0.4, 0), w, d, rand, false)
        frontYard(model, cfLot, w, yardFront, yardStart, C(220, 210, 180), rand)
    elseif kind == "industrial" then
        part(model, "RoofDeck", Vector3.new(w + 1.4, 0.8, d + 1.4), C(112, 116, 122), M.CorrugatedMetal,
            cf * CFrame.new(0, topY + 0.4, 0), true, true)
        for i = -2, 2 do
            part(model, "Rib", Vector3.new(w + 1.6, h * 0.86, 0.5), CityKit.Shade(wall, -0.12), M.CorrugatedMetal,
                cf * CFrame.new(0, h * 0.45, i * (d / 5)), false, false)
        end
        part(model, "Chimney", Vector3.new(3.2, 16, 3.2), C(104, 100, 96), M.CorrodedMetal,
            cf * CFrame.new(w * 0.3, topY + 8, -d * 0.25), true, true)
        part(model, "Dock", Vector3.new(w * 0.5, 3.6, 1.2), C(96, 96, 100), M.Metal,
            cf * CFrame.new(-w * 0.2, 1.8, d * 0.5 + 0.8), true, true)
    elseif kind == "neon" then
        rooftopDetails(model, cf * CFrame.new(0, topY + 0.6, 0), w, d, rand, true)
        for _, sx in ipairs({ -0.42, 0.42 }) do
            part(model, "NeonStrip", Vector3.new(0.5, h * 0.9, 0.5), accent, M.Neon,
                cf * CFrame.new(w * sx, h * 0.5, d * 0.5 + 0.3), false, false)
        end
        CityKit.SignBoard(model, (cf * CFrame.new(0, topY - 4.5, d * 0.5 + 0.6)).Position,
            cf.LookVector, Vector3.new(w * 0.8, 5, 0.5), CityKit.Shade(accent, -0.55), "NEON", accent)
    elseif kind == "office" then
        rooftopDetails(model, cf * CFrame.new(0, topY + 0.8, 0), w, d, rand, true)
        part(model, "Crown", Vector3.new(w + 1.6, 2.2, d + 1.6), accent, M.Neon,
            cf * CFrame.new(0, topY - 1.0, 0), false, false)
    elseif kind == "garage" then
        parkingDecks(model, cf, w, d, floors, floorH, wall, accent)
    elseif kind == "hotel" then
        -- Hotel: remate con rotulo luminoso y apartamentos en la azotea.
        part(model, "Cornice", Vector3.new(w + 1.8, 1.6, d + 1.8), CityKit.Shade(wall, -0.22), M.Concrete,
            cf * CFrame.new(0, topY + 0.4, 0), false, true)
        rooftopDetails(model, cf * CFrame.new(0, topY + 1.2, 0), w, d, rand, false)
        CityKit.SignBoard(model, (cf * CFrame.new(0, topY + 6.5, d * 0.5 + 1.0)).Position,
            cf.LookVector, Vector3.new(w * 0.72, 5.5, 0.6), CityKit.Shade(accent, -0.62), "HOTEL", accent)
        part(model, "NeonEdge", Vector3.new(w + 0.6, 0.8, d + 0.6), accent, M.Neon,
            cf * CFrame.new(0, topY + 1.6, 0), false, false)
    elseif kind == "apartment" then
        -- Bloque de viviendas: remate plano con casetones y depositos.
        part(model, "Cornice", Vector3.new(w + 1.4, 1.4, d + 1.4), CityKit.Shade(wall, -0.2), M.Concrete,
            cf * CFrame.new(0, topY + 0.2, 0), false, true)
        rooftopDetails(model, cf * CFrame.new(0, topY + 1.0, 0), w, d, rand, floors >= 6)
        part(model, "StairHead", Vector3.new(w * 0.3, 7, d * 0.3), CityKit.Shade(wall, -0.12), M.Concrete,
            cf * CFrame.new(w * 0.22, topY + 4.5, -d * 0.22), false, false)
    else
        part(model, "Cornice", Vector3.new(w + 1.6, 1.2, d + 1.6), CityKit.Shade(wall, -0.18), M.Concrete,
            cf * CFrame.new(0, topY - 0.4, 0), false, true)
        rooftopDetails(model, cf * CFrame.new(0, topY + 0.4, 0), w, d, rand, floors >= 5)
    end

    -- Aire acondicionado y tuberias en fachada
    if rand() < 0.6 then
        for i = 1, CityKit.Int(rand, 1, 2) do
            local x = CityKit.Float(rand, -w * 0.35, w * 0.35)
            local y = CityKit.Float(rand, h * 0.3, h * 0.8)
            part(model, "WallAC", Vector3.new(2.4, 1.8, 1.6), C(158, 160, 164), M.Metal,
                cf * CFrame.new(x, y, d * 0.5 + 0.8), false, false)
        end
    end
    if floors >= 4 and rand() < 0.5 then
        part(model, "Pipe", Vector3.new(0.5, h * 0.9, 0.5), C(96, 92, 88), M.Metal,
            cf * CFrame.new(w * 0.46, h * 0.45, d * 0.44), false, false)
    end

    model:SetAttribute("Kind", kind)
    return model
end

return BuildingBuilder
