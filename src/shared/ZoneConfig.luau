--[[
    ZoneConfig
    Ruta en Roblox Studio: ReplicatedStorage > Shared > ZoneConfig
    Tipo: ModuleScript

    Define la ciudad: los 8 distritos, las CASAS funcionales (con sus dealers),
    las posiciones de puertas y el estilo visual.

    IMPORTANTE: este archivo es la unica fuente de verdad de posiciones. Tanto
    CityBuilder/HouseBuilder (servidor) como ShopService/AccessService
    (validacion por proximidad) y el cliente (mapa, prompts) leen de aqui, de
    forma que lo que se ve coincide con lo que el servidor valida.

    Layout: hub central (plaza + zona de fumadores + spawn) y 8 distritos
    repartidos en anillo (4 interiores + 4 esquinas). El jugador progresa del
    distrito sur (starter) girando en espiral hacia las esquinas exteriores.

    Los DEALERS estan DENTRO de las casas. Cada casa funcional tiene una puerta
    con coste de acceso en Puffs (ver EconomyConfig.HouseCosts).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local ZoneConfig = {}

local C = Color3.fromRGB
local M = Enum.Material

-- Zona de fumadores (hub central) --------------------------------------------
ZoneConfig.SmokingZone = {
    position = Vector3.new(0, 0, 0),
    radius = 150,
}

-- Parametros globales del mapa -------------------------------------------------
ZoneConfig.Layout = {
    groundSize = Vector3.new(2000, 4, 2000),
    groundColor = C(52, 58, 54),        -- verde urbano apagado
    roadColor = C(38, 40, 46),
    roadWidth = 60,
    sidewalkColor = C(120, 122, 128),
    hubRadius = 234,                    -- media lado de la plaza central
    districtSize = 440,                 -- lado del area construida de un distrito
    ringSpacing = 520,                  -- distancia del centro a cada distrito
}

-- Distritos -------------------------------------------------------------------
-- requirement = Puffs para "descubrir" el distrito (hito + recompensa). No
-- bloquea el paso: el mundo es explorable. El gating economico esta en las casas.
ZoneConfig.Districts = {
    starter_block = {
        id = "starter_block",
        name = "STARTER BLOCK",
        short = "STARTER",
        order = 1,
        center = Vector3.new(0, 0, 520),
        gatePosition = Vector3.new(0, 0, 390),
        color = C(120, 220, 140),
        description = "Barrio inicial. Casas sencillas, comercios y la plaza humilde.",
        style = {
            ground = C(64, 78, 60), sidewalk = C(130, 132, 136), road = C(42, 44, 50),
            wall = { C(196, 186, 160), C(170, 180, 170), C(200, 170, 150), C(150, 160, 175) },
            roof = { C(120, 70, 60), C(90, 90, 100), C(110, 90, 70) },
            accent = C(120, 220, 140), material = M.Brick,
            heightMin = 14, heightMax = 26, tree = true, fence = C(200, 200, 205),
            kind = "mixed", density = 0.7,
        },
    },
    suburban_east = {
        id = "suburban_east",
        name = "SUBURBAN EAST",
        short = "SUBURBAN E",
        order = 2,
        center = Vector3.new(520, 0, 0),
        gatePosition = Vector3.new(390, 0, 0),
        color = C(120, 200, 255),
        description = "Residencial de casas unifamiliares. Jardines, garajes y buzones.",
        style = {
            ground = C(78, 96, 66), sidewalk = C(140, 142, 146), road = C(44, 46, 52),
            wall = { C(220, 210, 190), C(190, 205, 210), C(205, 185, 175), C(180, 195, 180) },
            roof = { C(140, 80, 70), C(80, 90, 110), C(120, 100, 80) },
            accent = C(120, 200, 255), material = M.Brick,
            heightMin = 12, heightMax = 20, tree = true, fence = C(230, 230, 235),
            kind = "residential", density = 0.6,
        },
    },
    old_town = {
        id = "old_town",
        name = "OLD TOWN",
        short = "OLD TOWN",
        order = 3,
        center = Vector3.new(0, 0, -520),
        gatePosition = Vector3.new(0, 0, -390),
        color = C(210, 160, 90),
        description = "Callejones, edificios antiguos y pequenos negocios.",
        style = {
            ground = C(96, 88, 74), sidewalk = C(120, 112, 96), road = C(46, 42, 38),
            wall = { C(150, 130, 100), C(130, 115, 95), C(165, 140, 110), C(110, 100, 90) },
            roof = { C(90, 60, 50), C(70, 55, 45) },
            accent = C(210, 160, 90), material = M.Brick,
            heightMin = 20, heightMax = 40, tree = false, fence = C(90, 80, 70),
            kind = "mixed", density = 0.9,
        },
    },
    downtown = {
        id = "downtown",
        name = "DOWNTOWN",
        short = "DOWNTOWN",
        order = 4,
        center = Vector3.new(-520, 0, 0),
        gatePosition = Vector3.new(-390, 0, 0),
        color = C(150, 190, 255),
        description = "Oficinas, comercios, apartamentos y avenidas amplias.",
        style = {
            ground = C(70, 74, 82), sidewalk = C(150, 152, 158), road = C(40, 42, 48),
            wall = { C(120, 130, 150), C(150, 160, 175), C(100, 110, 130), C(170, 175, 185) },
            roof = { C(70, 75, 85) },
            accent = C(150, 190, 255), material = M.Concrete,
            heightMin = 50, heightMax = 110, tree = false, fence = C(110, 115, 125),
            kind = "commercial", density = 1.0,
        },
    },
    industrial = {
        id = "industrial",
        name = "INDUSTRIAL DISTRICT",
        short = "INDUSTRIAL",
        order = 5,
        center = Vector3.new(-520, 0, 520),
        gatePosition = Vector3.new(-390, 0, 520),
        color = C(200, 150, 70),
        description = "Almacenes, talleres, aparcamientos y naves.",
        style = {
            ground = C(74, 70, 64), sidewalk = C(120, 118, 112), road = C(44, 42, 40),
            wall = { C(120, 118, 112), C(100, 100, 104), C(140, 135, 120), C(90, 92, 96) },
            roof = { C(90, 92, 100), C(80, 82, 88) },
            accent = C(200, 150, 70), material = M.CorrodedMetal,
            heightMin = 24, heightMax = 55, tree = false, fence = C(150, 150, 155),
            kind = "industrial", density = 0.8,
        },
    },
    suburban_hills = {
        id = "suburban_hills",
        name = "SUBURBAN HILLS",
        short = "HILLS",
        order = 6,
        center = Vector3.new(520, 0, 520),
        gatePosition = Vector3.new(390, 0, 520),
        color = C(150, 230, 170),
        description = "Residencial exclusivo. Casas grandes, jardines y garajes.",
        style = {
            ground = C(84, 104, 70), sidewalk = C(150, 150, 152), road = C(48, 48, 54),
            wall = { C(235, 228, 210), C(210, 215, 205), C(220, 200, 185), C(200, 205, 215) },
            roof = { C(90, 70, 60), C(70, 80, 95) },
            accent = C(150, 230, 170), material = M.Brick,
            heightMin = 16, heightMax = 28, tree = true, fence = C(240, 240, 245),
            kind = "residential", density = 0.5,
        },
    },
    neon = {
        id = "neon",
        name = "NEON DISTRICT",
        short = "NEON",
        order = 7,
        center = Vector3.new(520, 0, -520),
        gatePosition = Vector3.new(390, 0, -520),
        color = C(255, 70, 190),
        description = "Urbano futurista. Carteles luminosos y torres modernas.",
        style = {
            ground = C(26, 22, 44), sidewalk = C(60, 56, 92), road = C(24, 20, 40),
            wall = { C(40, 30, 70), C(55, 30, 80), C(30, 40, 80), C(60, 40, 90) },
            roof = { C(20, 16, 40) },
            accent = C(255, 70, 190), material = M.SmoothPlastic,
            heightMin = 46, heightMax = 120, tree = false, fence = C(70, 60, 120),
            kind = "commercial", density = 1.0,
        },
    },
    elite_heights = {
        id = "elite_heights",
        name = "ELITE HEIGHTS",
        short = "ELITE",
        order = 8,
        center = Vector3.new(-520, 0, -520),
        gatePosition = Vector3.new(-390, 0, -520),
        color = C(255, 215, 130),
        description = "El barrio final: mansiones y los dealers de mayor nivel.",
        style = {
            ground = C(92, 88, 76), sidewalk = C(160, 155, 140), road = C(52, 50, 46),
            wall = { C(238, 232, 216), C(220, 214, 200), C(200, 195, 185), C(230, 220, 200) },
            roof = { C(110, 90, 60), C(80, 70, 60) },
            accent = C(255, 215, 130), material = M.Marble,
            heightMin = 22, heightMax = 40, tree = true, fence = C(220, 210, 180),
            kind = "residential", density = 0.45,
        },
    },
}

ZoneConfig.DistrictOrder = {
    "starter_block", "suburban_east", "old_town", "downtown",
    "industrial", "suburban_hills", "neon", "elite_heights",
}

-- Cada distrito tiene una puerta/arco en la calle que llega desde el hub.
-- Se calcula automaticamente hacia el centro de la ciudad si no se indica.
for _, id in ipairs(ZoneConfig.DistrictOrder) do
    local d = ZoneConfig.Districts[id]
    if not d.gatePosition then
        local dir = d.center.Unit
        d.gatePosition = d.center - dir * (ZoneConfig.Layout.districtSize * 0.5)
    end
    d.requirement = EconomyConfig.DistrictRequirements[id] or 0
end

-- Casas funcionales ------------------------------------------------------------
-- Cada una tiene dealer dentro. `h` es la altura de las paredes; `w`/`d` la
-- planta; `tier` define el mobiliario del interior; `facing` (grados) la
-- orientacion de la fachada (si es nil, CityBuilder la orienta al centro del
-- distrito). `mirror` voltea la fachada para variar sin cambiar el estilo.
ZoneConfig.Houses = {
    starter = {
        id = "starter", name = "CASA DE ROOKIE", district = "starter_block",
        position = Vector3.new(133.5, 0, 573), facing = 180,
        w = 30, d = 24, h = 12, tier = "poor", mirror = false, roofStyle = "flat",
        dealer = { name = "ROOKIE", color = C(120, 220, 150),
                   line = "Bienvenido. Aqui empieza todo. Los Puffs se hacen en la plaza." },
    },
    suburb_a = {
        id = "suburb_a", name = "CASA N.1", district = "suburban_east",
        position = Vector3.new(573, 0, -130), facing = -90,
        w = 30, d = 24, h = 12, tier = "poor", mirror = false, roofStyle = "gable",
        dealer = { name = "NICO", color = C(120, 200, 255),
                   line = "El CYBER es mi bestia. Pantalla y x3 Puffs." },
    },
    suburb_b = {
        id = "suburb_b", name = "CASA N.2", district = "suburban_east",
        position = Vector3.new(574, 0, 130), facing = -90,
        w = 34, d = 26, h = 13, tier = "mid", mirror = true, roofStyle = "gable",
        dealer = { name = "TARA", color = C(255, 170, 60),
                   line = "El HYPER tiene RGB y anillos. Vale cada Puff." },
    },
    suburb_c = {
        id = "suburb_c", name = "CASA N.3", district = "suburban_east",
        position = Vector3.new(653.5, 0, -55), facing = 0,
        w = 36, d = 28, h = 14, tier = "mid", mirror = false, roofStyle = "gable",
        dealer = { name = "SOL", color = C(180, 140, 255),
                   line = "El GALAXY es cosmos puro. Anillos orbitales incluidos." },
    },
    old_town = {
        id = "old_town", name = "TALLER ANTIGUO", district = "old_town",
        position = Vector3.new(133.5, 0, -574), facing = 0,
        w = 34, d = 26, h = 16, tier = "mid", mirror = true, roofStyle = "flat",
        dealer = { name = "BRUNO", color = C(210, 160, 90),
                   line = "Aqui construimos el TITAN. Cuerpo blindado de verdad." },
    },
    downtown = {
        id = "downtown", name = "APARTAMENTO 12B", district = "downtown",
        position = Vector3.new(-575, 0, 130), facing = 90,
        w = 34, d = 28, h = 16, tier = "rich", mirror = false, roofStyle = "flat",
        dealer = { name = "MIRA", color = C(150, 190, 255),
                   line = "PHANTOM para los discretos, PLASMA para los que brillan." },
    },
    industrial = {
        id = "industrial", name = "NAVE 9", district = "industrial",
        position = Vector3.new(-576, 0, 386.5), facing = 90,
        w = 38, d = 30, h = 16, tier = "mid", mirror = false, roofStyle = "flat",
        dealer = { name = "GRIT", color = C(200, 150, 70),
                   line = "QUANTUM: tecnologia de nave industrial. No preguntes." },
    },
    hills = {
        id = "hills", name = "VILLA ASCUA", district = "suburban_hills",
        position = Vector3.new(309, 0, 653.5), facing = -90,
        w = 38, d = 30, h = 16, tier = "rich", mirror = false, roofStyle = "gable",
        dealer = { name = "IGNIS", color = C(255, 120, 40),
                   line = "El INFERNO arde. Materiales oscuros, luz calida." },
    },
    hills_manor = {
        id = "hills_manor", name = "MANSION AURORA", district = "suburban_hills",
        position = Vector3.new(578, 0, 386.5), facing = -90,
        w = 44, d = 34, h = 18, tier = "luxury", mirror = true, roofStyle = "gable",
        dealer = { name = "AURA", color = C(150, 230, 200),
                   line = "AURORA: iridiscente, luminosa, unica." },
    },
    neon_house = {
        id = "neon_house", name = "LOFT OBSIDIAN", district = "neon",
        position = Vector3.new(309, 0, -653.5), facing = -90,
        w = 36, d = 30, h = 18, tier = "rich", mirror = false, roofStyle = "flat",
        dealer = { name = "ONYX", color = C(200, 190, 255),
                   line = "OBSIDIAN. Negro pulido y oro. Elegancia pura." },
    },
    neon_tower = {
        id = "neon_tower", name = "PISO NEBULA", district = "neon",
        position = Vector3.new(576, 0, -386.5), facing = -90,
        w = 38, d = 30, h = 18, tier = "luxury", mirror = true, roofStyle = "flat",
        dealer = { name = "NOVA", color = C(255, 120, 220),
                   line = "NEBULA: orbes, nubes y anillos. Otro nivel." },
    },
    elite = {
        id = "elite", name = "RESIDENCIA ECLIPSE", district = "elite_heights",
        position = Vector3.new(-577, 0, -386.5), facing = 90,
        w = 42, d = 32, h = 18, tier = "rich", mirror = false, roofStyle = "flat",
        dealer = { name = "SELENE", color = C(255, 215, 130),
                   line = "ECLIPSE. La esfera oscura con halo dorado." },
    },
    elite_manor = {
        id = "elite_manor", name = "PALACIO OMEGA", district = "elite_heights",
        position = Vector3.new(-313, 0, -653.5), facing = 90,
        w = 50, d = 38, h = 20, tier = "luxury", mirror = true, roofStyle = "gable",
        dealer = { name = "ORION", color = C(255, 200, 120),
                   line = "OMEGA. La pieza final. Coronas, nucleo solar, todo." },
    },
}

ZoneConfig.HouseOrder = {
    "starter", "suburb_a", "suburb_b", "suburb_c", "old_town", "downtown",
    "industrial", "hills", "hills_manor", "neon_house", "neon_tower",
    "elite", "elite_manor",
}

-- Aplica coste de acceso + orientacion por defecto a cada casa.
for _, id in ipairs(ZoneConfig.HouseOrder) do
    local house = ZoneConfig.Houses[id]
    house.requirement = EconomyConfig.HouseCosts[id] or 0
    if not house.facing then
        local d = ZoneConfig.Districts[house.district]
        local dx = d.center.X - house.position.X
        local dz = d.center.Z - house.position.Z
        house.facing = math.deg(math.atan2(dx, dz))
    end
end

-- Alias de compatibilidad: codigo existente usa ZoneConfig.Zones / .Order ----
ZoneConfig.Zones = ZoneConfig.Districts
ZoneConfig.Order = ZoneConfig.DistrictOrder

-- Dealers derivados de las casas (compatibilidad y conveniencia) --------------
-- Un dealer = una casa con dealer. `position` es la puerta/interior de la casa.
ZoneConfig.Dealers = {}
for _, id in ipairs(ZoneConfig.HouseOrder) do
    local house = ZoneConfig.Houses[id]
    ZoneConfig.Dealers[id] = {
        id = id,
        name = house.dealer.name,
        zone = house.district,
        house = id,
        position = house.position,
        bodyColor = house.dealer.color,
        line = house.dealer.line,
    }
end

-- Helpers ---------------------------------------------------------------------
function ZoneConfig.House(id)
    return ZoneConfig.Houses[id]
end

function ZoneConfig.District(id)
    return ZoneConfig.Districts[id]
end

--[[ Siguiente distrito por descubrir (por orden de progresion). ]]
function ZoneConfig.GetNextLocked(unlockedMap)
    for _, id in ipairs(ZoneConfig.DistrictOrder) do
        local zone = ZoneConfig.Districts[id]
        if not (unlockedMap and unlockedMap[id]) and zone.requirement > 0 then
            return zone
        end
    end
    return nil
end

--[[ Siguiente casa por desbloquear (por coste ascendente). ]]
function ZoneConfig.GetNextHouse(unlockedMap)
    local best, bestCost
    for _, id in ipairs(ZoneConfig.HouseOrder) do
        local house = ZoneConfig.Houses[id]
        if not (unlockedMap and unlockedMap[id]) then
            if not bestCost or house.requirement < bestCost then
                best, bestCost = house, house.requirement
            end
        end
    end
    return best
end

return ZoneConfig
