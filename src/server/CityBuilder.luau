--[[
    CityBuilder
    Ruta en Roblox Studio: ServerScriptService > CityBuilder
    Tipo: ModuleScript

    ORQUESTADOR de la ciudad. Construye, por codigo y de forma IDEMPOTENTE
    (borra sus contenedores antes de empezar, asi que reiniciar el script no
    duplica nada), una unica ciudad continua de 2000 x 2000 studs:

        1. Suelo urbano continuo (una sola superficie, por encima del Baseplate)
           + cinturon verde exterior. Nada de islas ni plataformas sueltas.
        2. Red viaria completa: avenidas, calles, circunvalacion, aceras
           continuas con bordillo en TODOS los bloques.
        3. Pintura de carretera: ejes discontinuos, lineas de borde, flechas,
           pasos de peatones, lineas de detencion y plazas de aparcamiento.
        4. Plaza central con spawn y zona de fumar (PlazaBuilder).
        5. Edificios variados por barrio (BuildingBuilder) y locales con
           interior (ShopBuilder).
        6. Parques y aparcamientos.
        7. Casas funcionales con dealer dentro + puertas de acceso (HouseBuilder)
           y arcos de barrio con su requisito de Puffs.
        8. Mobiliario urbano repartido (farolas, arboles, bancos, papeleras...).
           SIN coches decorativos: el patinete es el primer vehiculo jugable.

    La distribucion la decide CityLayout; toda la geometria comun vive en
    CityKit y las constantes en CityGrid (compartido con el servidor de juego).

    Requiere: BuildKit, CityKit, CityGrid, CityLayout, BuildingBuilder,
              ShopBuilder, PlazaBuilder, HouseBuilder, ZoneConfig, ShopConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGrid = require(Shared:WaitForChild("CityGrid"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local BuildKit = require(script.Parent:WaitForChild("BuildKit"))
local CityKit = require(script.Parent:WaitForChild("CityKit"))
local CityLayout = require(script.Parent:WaitForChild("CityLayout"))
local BuildingBuilder = require(script.Parent:WaitForChild("BuildingBuilder"))
local TowerBuilder = require(script.Parent:WaitForChild("TowerBuilder"))
local ShopBuilder = require(script.Parent:WaitForChild("ShopBuilder"))
local PlazaBuilder = require(script.Parent:WaitForChild("PlazaBuilder"))
local HouseBuilder = require(script.Parent:WaitForChild("HouseBuilder"))

local CityBuilder = {}

local M = Enum.Material
local C = Color3.fromRGB
local PAL = CityKit.Palette
local WALK = CityGrid.Levels.walk
local ROADW = 1.0
local GROUND_SIZE = 2040          -- por encima del Baseplate, sin sobresalir del limite de piezas
local BELT_IN = 814               -- borde exterior de las aceras de la ultima calle
local RING_HALF = CityGrid.Road.avenueWidth * 0.5

local CONTAINERS = {
    "HowToVape_Ground", "HowToVape_Roads", "HowToVape_Sidewalks", "HowToVape_Markings",
    "HowToVape_Plaza", "HowToVape_Buildings", "HowToVape_Shops", "HowToVape_Parks",
    "HowToVape_Parking", "HowToVape_Props", "HowToVape_Gates",
    -- Nombres historicos que HouseBuilder y otros sistemas esperan encontrar.
    -- Los dealers NO van en "Dealers": cada dealer NPC vive dentro del modelo de
    -- su casa (carpeta "Houses"), junto a su mostrador y su ProximityPrompt.
    "Houses", "Dealers",
}

local folders = {}

--[[ Los coches decorativos ya no se generan (ver CityKit). Esto limpia los que
     pudieran quedar incrustados en el place: busca por NOMBRE EXACTO para no
     borrar jamas objetos ajenos que solo se llamen parecido (por ejemplo
     "Cartel", "Carta", "Carretera"...). Destruye el modelo entero, asi que se
     llevan por delante sus ruedas y demas piezas. ]]
local LEGACY_CAR_MODELS = { ParkedCar = true, Car = true }

function CityBuilder.PurgeLegacyCars()
    local removed = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and LEGACY_CAR_MODELS[d.Name] then
            d:Destroy()
            removed += 1
        end
    end
    if removed > 0 then
        print(("[CityBuilder] Coches decorativos eliminados: %d"):format(removed))
    end
    return removed
end

local function makeContainers()
    for _, name in ipairs(CONTAINERS) do
        local existing = workspace:FindFirstChild(name)
        if existing then
            existing:Destroy()
        end
    end
    for _, name in ipairs(CONTAINERS) do
        local f = Instance.new("Folder")
        f.Name = name
        f.Parent = workspace
        folders[name] = f
    end
end

-- 1) SUELO ---------------------------------------------------------------------

local function buildGround(layout)
    local parent = folders["HowToVape_Ground"]
    -- Superficie urbana continua, ligeramente por encima del terreno por defecto.
    CityKit.Rect("GroundFill", -GROUND_SIZE * 0.5, -GROUND_SIZE * 0.5, GROUND_SIZE * 0.5, GROUND_SIZE * 0.5,
        CityGrid.Levels.base, 2.0, PAL.base, M.Concrete, parent, { canCollide = true })

    -- Suelo de cada manzana al mismo nivel que las aceras: asi los edificios y
    -- las casas apoyan sobre una superficie continua y no quedan flotando.
    -- Parques y aparcamientos se saltan porque ya construyen su propio suelo.
    for _, block in ipairs(layout.blocks) do
        if not block.special then
            local r = block.buildable
            local grass = block.profile.kind == "house" or block.profile.kind == "luxury"
            CityKit.Rect("LotGround", r.x1, r.z1, r.x2, r.z2, WALK, 1.2,
                grass and PAL.grass or PAL.concrete,
                grass and M.Grass or M.Concrete, parent, { canCollide = true })
        end
    end

    -- Cinturon verde exterior (entre las aceras de fuera y el borde del mapa).
    local outer = GROUND_SIZE * 0.5
    for _, side in ipairs({
        { BELT_IN, -BELT_IN, outer, BELT_IN },      -- este
        { -outer, -BELT_IN, -BELT_IN, BELT_IN },    -- oeste
        { -outer, BELT_IN, outer, outer },          -- norte
        { -outer, -outer, outer, -BELT_IN },        -- sur
    }) do
        CityKit.Rect("GreenBelt", side[1], side[2], side[3], side[4],
            CityGrid.Levels.base + 0.06, 0.4, PAL.grass, M.Grass, parent, { canCollide = true })
    end
end

-- 2) RED VIARIA ----------------------------------------------------------------

local plan
local function buildRoads()
    local parent = folders["HowToVape_Roads"]
    for i, s in ipairs(plan.slabs) do
        CityKit.Road(("Road_%d"):format(i), s.axis, s.line, s.from, s.to, s.width, parent)
    end
end

--[[ Aceras continuas (4 bandas por bloque, sin solaparse) + bordillo. ]]
local function buildSidewalks()
    local parent = folders["HowToVape_Sidewalks"]
    for _, b in ipairs(CityGrid.Blocks()) do
        for _, r in ipairs(CityGrid.SidewalkBands(b)) do
            CityKit.Rect("Sidewalk", r[1], r[2], r[3], r[4], WALK, 1.2, PAL.sidewalk, M.Concrete,
                parent, { canCollide = true })
        end
        -- Bordillo: resalte claro justo en el borde de la calzada.
        local hW, hE = CityGrid.HalfRoad(b.x1), CityGrid.HalfRoad(b.x2)
        local hS, hN = CityGrid.HalfRoad(b.z1), CityGrid.HalfRoad(b.z2)
        local ix1, ix2 = b.x1 + hW, b.x2 - hE
        local iz1, iz2 = b.z1 + hS, b.z2 - hN
        for _, c in ipairs({
            { ix1, iz1, ix2, iz1 + 1.4 },
            { ix1, iz2 - 1.4, ix2, iz2 },
            { ix1, iz1 + 1.4, ix1 + 1.4, iz2 - 1.4 },
            { ix2 - 1.4, iz1 + 1.4, ix2, iz2 - 1.4 },
        }) do
            CityKit.Rect("Curb", c[1], c[2], c[3], c[4], WALK + CityGrid.Levels.curbRise, 0.3,
                PAL.curb, M.Concrete, parent, {})
        end
    end
end
-- 3) PINTURA DE CARRETERA ------------------------------------------------------

local function buildMarkings()
    local parent = folders["HowToVape_Markings"]

    for _, span in ipairs(plan.spans) do
        local w = CityGrid.WidthOf(span.line)
        -- Eje discontinuo
        CityKit.DashedLine(span.axis, span.line, span.from, span.to, 0, parent)
        -- Lineas de borde continuas
        local edge = w * 0.5 - 1.6
        CityKit.SolidLine(span.axis, span.line, span.from, span.to, edge, parent)
        CityKit.SolidLine(span.axis, span.line, span.from, span.to, -edge, parent)
    end

    -- Pasos de peatones en los cruces de avenidas
    for _, it in ipairs(plan.intersections) do
        local wx = CityGrid.WidthOf(it.x)
        local wz = CityGrid.WidthOf(it.z)
        CityKit.Crosswalk("x", it.z, it.x - (wx * 0.5 + 6), wz, parent)
        CityKit.Crosswalk("x", it.z, it.x + (wx * 0.5 + 6), wz, parent)
        CityKit.Crosswalk("z", it.x, it.z - (wz * 0.5 + 6), wx, parent)
        CityKit.Crosswalk("z", it.x, it.z + (wz * 0.5 + 6), wx, parent)
    end

    -- Pasos de peatones y lineas de detencion en las bocas de la plaza
    local avenueW = CityGrid.Road.avenueWidth
    local off = CityGrid.Plaza.half + avenueW * 0.5 + 8
    for _, mouth in ipairs(plan.plazaMouths) do
        if mouth.axis == "z" then
            local z = mouth.z > 0 and off or -off
            CityKit.Crosswalk("z", 0, z, avenueW, parent)
            CityKit.StopBar("z", 0, off + 5, avenueW, parent)
        else
            local x = mouth.x > 0 and off or -off
            CityKit.Crosswalk("x", 0, x, avenueW, parent)
            CityKit.StopBar("x", 0, off + 5, avenueW, parent)
        end
    end

    -- Flechas de sentido en algunas avenidas
    for _, span in ipairs(plan.spans) do
        if CityGrid.IsAvenue(span.line) and (span.to - span.from) > 200 then
            local mid = (span.from + span.to) * 0.5
            CityKit.Arrow(span.axis, span.line, mid, 8, parent)
            CityKit.Arrow(span.axis, span.line, mid, -8, parent)
        end
    end
end

-- 4) PARQUES Y APARCAMIENTOS ---------------------------------------------------

local function buildParks(layout)
    local parent = folders["HowToVape_Parks"]
    for i, block in ipairs(layout.parks) do
        local r = block.buildable
        local rand = CityKit.Rng(500 + i * 977)
        CityKit.Rect("ParkGrass", r.x1, r.z1, r.x2, r.z2, WALK, 0.4, PAL.grass, M.Grass, parent,
            { canCollide = true })
        -- Sendero en cruz
        CityKit.Rect("ParkPath", r.cx - 4, r.z1, r.cx + 4, r.z2, WALK + 0.06, 0.12, PAL.dirt, M.Ground, parent, {})
        CityKit.Rect("ParkPath", r.x1, r.cz - 4, r.x2, r.cz + 4, WALK + 0.06, 0.12, PAL.dirt, M.Ground, parent, {})
        for k = 1, 6 do
            local ang = (k / 6) * math.pi * 2
            CityKit.Tree(Vector3.new(r.cx + math.cos(ang) * r.w * 0.3, WALK, r.cz + math.sin(ang) * r.d * 0.3),
                parent, 1.1, rand)
        end
        for k = 1, 4 do
            local ang = (k / 4) * math.pi * 2 + 0.6
            CityKit.Bench(Vector3.new(r.cx + math.cos(ang) * r.w * 0.2, WALK, r.cz + math.sin(ang) * r.d * 0.2),
                parent, math.deg(ang) + 180)
        end
        CityKit.Planter(Vector3.new(r.cx, WALK, r.cz), parent, rand)
    end
end

local function buildParking(layout)
    local parent = folders["HowToVape_Parking"]
    for _, block in ipairs(layout.parkings) do
        local r = block.buildable
        CityKit.Rect("LotAsphalt", r.x1, r.z1, r.x2, r.z2, CityGrid.Levels.road, 0.8, PAL.asphaltWorn,
            M.Asphalt, parent, { canCollide = true })
        -- dos filas de plazas enfrentadas (solo pintura: sin coches decorativos)
        local rowD = r.d * 0.36
        CityKit.ParkingRow(r.x1, r.cz - rowD, r.x2, r.cz - rowD * 0.15, 7, parent)
        CityKit.ParkingRow(r.x1, r.cz + rowD * 0.15, r.x2, r.cz + rowD, 7, parent)
    end
end

-- 5) EDIFICIOS Y LOCALES -------------------------------------------------------

--[[ Reparte los 21 locales por el anillo comercial, dando una vuelta completa
     para que no se amontonen todos en el mismo lado de la plaza. ]]
local function pickShopLots(layout)
    local byBlock = {}
    for _, lot in ipairs(layout.lots) do
        if (lot.profile.shops or 0) >= 0.3 then
            local key = tostring(lot.block.cx) .. ":" .. tostring(lot.block.cz)
            byBlock[key] = byBlock[key] or { block = lot.block, lots = {} }
            table.insert(byBlock[key].lots, lot)
        end
    end
    local blocks = {}
    for _, entry in pairs(byBlock) do
        local ang = math.atan2(entry.block.cz, entry.block.cx)
        entry.angle = ang
        blocks[#blocks + 1] = entry
    end
    table.sort(blocks, function(a, b)
        return a.angle < b.angle
    end)

    local chosen = {}
    local cursor = 1
    local i = 1
    while #chosen < #ShopConfig.Order and #blocks > 0 do
        local entry = blocks[cursor]
        local lot = entry.lots[i]
        if lot then
            chosen[#chosen + 1] = lot
        end
        cursor += 1
        if cursor > #blocks then
            cursor = 1
            i += 1
        end
        if i > 5 then
            break
        end
    end
    return chosen
end

local function buildBuildingsAndShops(layout)
    local bParent = folders["HowToVape_Buildings"]
    local sParent = folders["HowToVape_Shops"]

    local shopLots = pickShopLots(layout)
    local isShop = {}
    for i, lot in ipairs(shopLots) do
        isShop[lot] = ShopConfig.Order[i]
    end

    local shops, buildings, towers = 0, 0, 0
    local processed = 0
    for _, lot in ipairs(layout.lots) do
        local shopId = isShop[lot]
        local ok, err
        if shopId then
            ok, err = pcall(ShopBuilder.Build, lot, shopId, sParent, lot.style)
            if ok then
                shops += 1
            else
                warn("[CityBuilder] Local " .. shopId .. " fallo: " .. tostring(err))
            end
        elseif lot.profile.tower then
            ok, err = pcall(TowerBuilder.Build, lot, bParent)
            if ok then
                towers += 1
            else
                warn("[CityBuilder] Torre fallo: " .. tostring(err))
            end
        else
            ok, err = pcall(BuildingBuilder.Build, lot, bParent)
            if ok then
                buildings += 1
            else
                warn("[CityBuilder] Edificio fallo: " .. tostring(err))
            end
        end

        -- Ceder el hilo cada cierto numero de solares: construir una ciudad
        -- grande de golpe bloquearia el servidor durante varios segundos.
        processed += 1
        if processed % 24 == 0 then
            task.wait()
        end
    end
    print(("[CityBuilder] %d edificios, %d rascacielos y %d locales construidos.")
        :format(buildings, towers, shops))
end

-- 6) CASAS FUNCIONALES Y ARCOS -------------------------------------------------

local function buildHouseDistrict()
    for _, houseId in ipairs(ZoneConfig.HouseOrder) do
        local house = ZoneConfig.Houses[houseId]
        local district = ZoneConfig.Districts[house.district]
        local ok, err = pcall(HouseBuilder.Build, house, district, WALK)
        if not ok then
            warn("[CityBuilder] Fallo construyendo la casa " .. houseId .. ": " .. tostring(err))
        end
    end
end

local function buildGates()
    local parent = folders["HowToVape_Gates"]
    for _, id in ipairs(ZoneConfig.DistrictOrder) do
        local zone = ZoneConfig.Districts[id]
        local pos = zone.gatePosition
        local towardHub = -Vector3.new(pos.X, 0, pos.Z).Unit
        local cf = CFrame.lookAt(pos, pos + towardHub)
        local roadW = CityGrid.Road.avenueWidth

        local model = CityKit.Model("Gate_" .. id, parent)
        for _, sx in ipairs({ -1, 1 }) do
            BuildKit.Part({
                name = "Post", size = Vector3.new(2.6, 28, 2.6), color = zone.color, material = M.Neon,
                canCollide = false, castShadow = false,
                cframe = cf * CFrame.new(sx * (roadW * 0.5 + 5), 14, 0), parent = model,
            })
        end
        BuildKit.Part({
            name = "Beam", size = Vector3.new(roadW + 14, 2.4, 2.6), color = zone.color, material = M.Neon,
            canCollide = false, castShadow = false, cframe = cf * CFrame.new(0, 28.6, 0), parent = model,
        })

        local signPos = (cf * CFrame.new(0, 20, 0)).Position
        local req = zone.requirement > 0 and ("Descubrir: %d Puffs"):format(zone.requirement) or "Acceso libre"
        CityKit.SignBoard(model, signPos, cf.LookVector, Vector3.new(34, 8, 0.8),
            C(16, 20, 28), zone.name .. "\n" .. req, zone.color)
    end
end

-- 7) MOBILIARIO URBANO ---------------------------------------------------------

local function buildProps()
    local parent = folders["HowToVape_Props"]
    local rand = CityKit.Rng(4242)
    local b = CityGrid.Blocks()
    for i, block in ipairs(b) do
        if not block.plaza then
            local s = CityGrid.Road.sidewalk
            local hS, hN = CityGrid.HalfRoad(block.z1), CityGrid.HalfRoad(block.z2)
            local hW, hE = CityGrid.HalfRoad(block.x1), CityGrid.HalfRoad(block.x2)
            -- Farolas en los lados sur y norte (con luz solo una de cada tres)
            CityKit.Lamppost(Vector3.new(block.cx, WALK, block.z1 + hS + s * 0.5), C(255, 226, 170),
                parent, 14, i % 3 == 0)
            CityKit.Lamppost(Vector3.new(block.cx, WALK, block.z2 - hN - s * 0.5), C(255, 226, 170),
                parent, 14, i % 4 == 0)
            CityKit.Lamppost(Vector3.new(block.x1 + hW + s * 0.5, WALK, block.cz), C(255, 226, 170),
                parent, 14, i % 5 == 0)
            CityKit.Lamppost(Vector3.new(block.x2 - hE - s * 0.5, WALK, block.cz), C(255, 226, 170),
                parent, 14, false)

            -- Arboles en las aceras de los barrios residenciales
            local profile = CityLayout.ProfileOf(CityLayout.DistrictOf(block.cx, block.cz))
            if profile.kind == "house" or profile.kind == "luxury" then
                CityKit.Tree(Vector3.new(block.cx + 14, WALK, block.z1 + hS + s * 0.5), parent, 0.95, rand)
            end
        end
    end

    -- Avenidas: SOLO mobiliario urbano. Antes se aparcaban aqui coches
    -- decorativos; se han eliminado por completo del juego (ver
    -- CityBuilder.PurgeLegacyCars). El patinete es el primer vehiculo.

    -- Papeleras sobre aceras reales (nunca en la calzada)
    local s = CityGrid.Road.sidewalk
    local placed = 0
    for _, block in ipairs(CityGrid.Blocks()) do
        if not block.plaza and placed < 12 then
            local hW = CityGrid.HalfRoad(block.x1)
            CityKit.TrashCan(Vector3.new(block.x1 + hW + s * 0.5, WALK, block.cz), parent)
            placed += 1
        end
    end
end

-- MONTAJE ----------------------------------------------------------------------

function CityBuilder.Build()
    local t0 = os.clock()

    makeContainers()
    CityKit.ResetLights()
    CityBuilder.PurgeLegacyCars()

    -- Baseplate por defecto fuera (nuestra superficie la sustituye)
    local defaultPlate = workspace:FindFirstChild("Baseplate")
    if defaultPlate and defaultPlate:IsA("BasePart") then
        defaultPlate:Destroy()
    end

    plan = CityLayout.RoadPlan()
    local layout = CityLayout.Generate()

    buildGround(layout)
    buildRoads()
    buildSidewalks()
    buildMarkings()

    PlazaBuilder.Build(folders["HowToVape_Plaza"])

    buildParks(layout)
    buildParking(layout)
    buildBuildingsAndShops(layout)
    buildHouseDistrict()
    buildGates()
    buildProps()

    -- Ambiente
    Lighting.Ambient = C(72, 74, 88)
    Lighting.OutdoorAmbient = C(96, 98, 116)
    Lighting.Brightness = 2.4
    Lighting.ClockTime = 17.4
    Lighting.FogEnd = 1600
    Lighting.FogColor = C(128, 146, 182)
    Lighting.EnvironmentDiffuseScale = 0.4
    Lighting.EnvironmentSpecularScale = 0.4

    -- Streaming: imprescindible en un mapa grande. Solo puede activarse antes
    -- de que entren jugadores; si el entorno no lo permite, se ignora.
    pcall(function()
        if not workspace.StreamingEnabled then
            workspace.StreamingEnabled = true
        end
        -- Radio amplio: los rascacielos del centro deben verse desde lejos.
        workspace.StreamingTargetRadius = 1100
    end)

    -- La zona de fumadores la valida PuffService a partir de estos atributos.
    workspace:SetAttribute("SmokingZonePosition", ZoneConfig.SmokingZone.position)
    workspace:SetAttribute("SmokingZoneRadius", ZoneConfig.SmokingZone.radius)
    workspace:SetAttribute("CityBuilt", true)

    local dt = os.clock() - t0
    local parts = 0
    for _, name in ipairs(CONTAINERS) do
        if folders[name] then
            parts += #folders[name]:GetDescendants()
        end
    end
    print(("[CityBuilder] Ciudad densa lista en %.1fs: 8 barrios, %d locales y %d casas con dealer (%d objetos, %d luces).")
        :format(dt, #ShopConfig.Order, #ZoneConfig.HouseOrder, parts, 210 - CityKit.LightsLeft()))
end

return CityBuilder
