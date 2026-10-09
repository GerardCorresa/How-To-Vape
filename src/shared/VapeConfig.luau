--[[
    VapeConfig
    Ruta en Roblox Studio: ReplicatedStorage > Shared > VapeConfig
    Tipo: ModuleScript

    Define los 15 dispositivos: modelo geometrico, posicion en la mano y
    metadatos. El precio y el multiplicador NO se escriben aqui: se inyectan
    desde EconomyConfig al final del archivo, para que la economia tenga una
    unica fuente de verdad.

    Campos de cada vape:
        id            identificador unico (string)
        name          nombre visible
        house         casa funcional que lo vende (ver ZoneConfig.Houses)
        district      distrito recomendado (informativo)
        description   texto para la tienda
        hold          { offset:Vector3, rot:Vector3(grados), scale:number }
        model.parts   lista de piezas
        model.groups  grupos animados (anillos que giran)

    Campos de una pieza:
        name, primary, shape ("Block"|"Cylinder"|"Ball"), size:Vector3,
        pos:Vector3, rot:Vector3(grados), color:Color3, material:Enum.Material,
        transparency, reflectance,
        emitter  = { color, size, speed:NumberRange, lifetime:NumberRange, rate }
        light    = { color, brightness, range }
        screen   = { text, color, background }
        rgb      = number (velocidad del ciclo de color)

    IMPORTANTE (para la animacion): la pieza "Mouthpiece" debe ser siempre la
    mas ALTA del modelo. EquipmentService mide la caja envolvente y usa ese
    punto como punta del dispositivo; si otra pieza sobresale, la punta queda
    mal y el vaper no llega bien a la boca.

    `hold.scale` escala el modelo entero (tamano y posiciones). El animador
    mantiene automaticamente los modelos grandes lejos de la cara.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local VapeConfig = {}

local C = Color3.fromRGB
local M = Enum.Material

VapeConfig.Order = EconomyConfig.VapeOrder

VapeConfig.Vapes = {

    -- ===================================================================== 1
    basic = {
        id = "basic",
        name = "BASIC VAPE",
        house = nil,               -- lo tiene todo el mundo por defecto
        district = "starter_block",
        description = "Dispositivo sencillo y discreto. Ideal para empezar.",
        hold = { offset = Vector3.new(0, -0.15, -0.35), rot = Vector3.new(-8, 0, 18), scale = 1 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.22, 1.0, 0.22),
                  pos = Vector3.new(0, 0, 0), color = C(35, 35, 42), material = M.SmoothPlastic },
                { name = "Grip", shape = "Block", size = Vector3.new(0.24, 0.30, 0.24),
                  pos = Vector3.new(0, -0.32, 0), color = C(22, 22, 26), material = M.Metal },
                { name = "Led", shape = "Block", size = Vector3.new(0.06, 0.06, 0.24),
                  pos = Vector3.new(0, -0.05, 0), color = C(120, 255, 150), material = M.Neon },
                { name = "Mouthpiece", shape = "Block", size = Vector3.new(0.13, 0.20, 0.13),
                  pos = Vector3.new(0, 0.58, 0), color = C(15, 15, 18), material = M.SmoothPlastic,
                  emitter = { color = C(210, 225, 220), size = 0.55,
                              speed = NumberRange.new(3, 6), lifetime = NumberRange.new(0.4, 0.9), rate = 0 } },
            },
        },
    },

    -- ===================================================================== 2
    neon = {
        id = "neon",
        name = "NEON VAPE",
        house = "starter",
        district = "starter_block",
        description = "Mod compacto con tiras luminosas y un halo de color.",
        hold = { offset = Vector3.new(0, -0.2, -0.4), rot = Vector3.new(-8, 0, 16), scale = 1 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.42, 1.15, 0.30),
                  pos = Vector3.new(0, 0, 0), color = C(40, 20, 60), material = M.SmoothPlastic, reflectance = 0.05 },
                { name = "StripeL", shape = "Block", size = Vector3.new(0.06, 0.95, 0.32),
                  pos = Vector3.new(-0.24, 0, 0), color = C(0, 220, 255), material = M.Neon },
                { name = "StripeR", shape = "Block", size = Vector3.new(0.06, 0.95, 0.32),
                  pos = Vector3.new(0.24, 0, 0), color = C(255, 40, 180), material = M.Neon },
                { name = "GlowPanel", shape = "Block", size = Vector3.new(0.30, 0.80, 0.05),
                  pos = Vector3.new(0, 0, 0.17), color = C(120, 240, 255), material = M.Neon, transparency = 0.25 },
                { name = "Core", shape = "Block", size = Vector3.new(0.12, 0.60, 0.12),
                  pos = Vector3.new(0, 0, -0.16), color = C(0, 220, 255), material = M.Neon,
                  light = { color = C(0, 200, 255), brightness = 2, range = 10 } },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.36, 0.18, 0.18),
                  pos = Vector3.new(0, 0.75, 0), rot = Vector3.new(0, 0, 90), color = C(25, 10, 40), material = M.SmoothPlastic,
                  emitter = { color = C(140, 240, 255), size = 0.6,
                              speed = NumberRange.new(4, 8), lifetime = NumberRange.new(0.5, 1.0), rate = 0 } },
            },
        },
    },

    -- ===================================================================== 3
    cyber = {
        id = "cyber",
        name = "CYBER VAPE",
        house = "suburb_a",
        district = "suburban_east",
        description = "Diseno futurista con pantalla digital y rotor de energia.",
        hold = { offset = Vector3.new(0, -0.25, -0.45), rot = Vector3.new(-10, 0, 16), scale = 1 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.50, 1.50, 0.42),
                  pos = Vector3.new(0, 0, 0), color = C(30, 34, 42), material = M.Metal, reflectance = 0.15 },
                { name = "ScreenBezel", shape = "Block", size = Vector3.new(0.42, 0.70, 0.06),
                  pos = Vector3.new(0, 0.15, 0.22), color = C(10, 10, 12), material = M.SmoothPlastic },
                { name = "Screen", shape = "Block", size = Vector3.new(0.34, 0.58, 0.03),
                  pos = Vector3.new(0, 0.15, 0.26), color = C(0, 0, 0), material = M.SmoothPlastic,
                  screen = { text = "CYBER", color = C(0, 255, 220), background = C(5, 20, 25) } },
                { name = "EdgeTop", shape = "Block", size = Vector3.new(0.52, 0.05, 0.44),
                  pos = Vector3.new(0, 0.76, 0), color = C(0, 230, 255), material = M.Neon },
                { name = "EdgeBot", shape = "Block", size = Vector3.new(0.52, 0.05, 0.44),
                  pos = Vector3.new(0, -0.76, 0), color = C(0, 230, 255), material = M.Neon },
                { name = "Antenna", shape = "Cylinder", size = Vector3.new(0.5, 0.05, 0.05),
                  pos = Vector3.new(0, 1.02, -0.16), rot = Vector3.new(0, 0, 90), color = C(190, 200, 215), material = M.Metal },
                { name = "AntennaTip", shape = "Ball", size = Vector3.new(0.10, 0.10, 0.10),
                  pos = Vector3.new(0, 1.27, -0.16), color = C(0, 255, 200), material = M.Neon,
                  light = { color = C(0, 255, 200), brightness = 2, range = 9 } },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.32, 0.16, 0.16),
                  pos = Vector3.new(0, 0.88, 0.06), rot = Vector3.new(0, 0, 90), color = C(18, 20, 26), material = M.SmoothPlastic,
                  emitter = { color = C(120, 255, 235), size = 0.65,
                              speed = NumberRange.new(4, 9), lifetime = NumberRange.new(0.5, 1.1), rate = 0 } },
            },
            groups = {
                { name = "Rotor", pos = Vector3.new(0, -0.55, 0), rot = Vector3.new(0, 0, 0), spin = 3.0,
                  count = 8, radius = 0.34, segSize = Vector3.new(0.10, 0.06, 0.14), segColor = C(0, 230, 255) },
            },
        },
    },

    -- ===================================================================== 4
    hyper = {
        id = "hyper",
        name = "HYPER VAPE",
        house = "suburb_b",
        district = "suburban_east",
        description = "Bloque grande con barras RGB y anillos giratorios.",
        hold = { offset = Vector3.new(0, -0.35, -0.55), rot = Vector3.new(-12, 0, 14), scale = 1 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.70, 2.00, 0.60),
                  pos = Vector3.new(0, 0, 0), color = C(18, 18, 22), material = M.Metal, reflectance = 0.3 },
                { name = "RGBBarL", shape = "Block", size = Vector3.new(0.12, 1.60, 0.12),
                  pos = Vector3.new(-0.34, 0, 0), color = C(255, 255, 255), material = M.Neon, rgb = 1 },
                { name = "RGBBarR", shape = "Block", size = Vector3.new(0.12, 1.60, 0.12),
                  pos = Vector3.new(0.34, 0, 0), color = C(255, 255, 255), material = M.Neon, rgb = 1 },
                { name = "RGBBarC", shape = "Block", size = Vector3.new(0.12, 1.60, 0.12),
                  pos = Vector3.new(0, 0, -0.32), color = C(255, 255, 255), material = M.Neon, rgb = 1 },
                { name = "TopCap", shape = "Block", size = Vector3.new(0.75, 0.15, 0.65),
                  pos = Vector3.new(0, 1.07, 0), color = C(30, 30, 36), material = M.Metal, reflectance = 0.4 },
                { name = "Core", shape = "Ball", size = Vector3.new(0.30, 0.30, 0.30),
                  pos = Vector3.new(0, 0, 0.34), color = C(255, 255, 255), material = M.Neon, rgb = 1,
                  light = { color = C(255, 255, 255), brightness = 3, range = 14 } },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.40, 0.20, 0.20),
                  pos = Vector3.new(0, 1.28, 0), rot = Vector3.new(0, 0, 90), color = C(20, 20, 25), material = M.SmoothPlastic,
                  emitter = { color = C(255, 255, 255), size = 0.8,
                              speed = NumberRange.new(5, 11), lifetime = NumberRange.new(0.6, 1.3), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.55, 0), rot = Vector3.new(0, 0, 0), spin = 2.2,
                  count = 10, radius = 0.5, segSize = Vector3.new(0.10, 0.08, 0.18), segColor = C(0, 200, 255) },
                { name = "RingB", pos = Vector3.new(0, -0.35, 0), rot = Vector3.new(0, 0, 0), spin = -3.0,
                  count = 10, radius = 0.5, segSize = Vector3.new(0.10, 0.08, 0.18), segColor = C(255, 60, 180) },
            },
        },
    },

    -- ===================================================================== 5
    galaxy = {
        id = "galaxy",
        name = "GALAXY VAPE",
        house = "suburb_c",
        district = "suburban_east",
        description = "Nucleo cosmico y anillos orbitales. Salto visual grande.",
        hold = { offset = Vector3.new(0, -0.45, -0.7), rot = Vector3.new(-12, 0, 12), scale = 1 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.95, 2.60, 0.80),
                  pos = Vector3.new(0, 0, 0), color = C(25, 15, 55), material = M.Metal, reflectance = 0.35 },
                { name = "GoldTrimTop", shape = "Block", size = Vector3.new(1.00, 0.12, 0.85),
                  pos = Vector3.new(0, 1.12, 0), color = C(240, 190, 80), material = M.Metal, reflectance = 0.5 },
                { name = "GoldTrimBot", shape = "Block", size = Vector3.new(1.00, 0.12, 0.85),
                  pos = Vector3.new(0, -1.12, 0), color = C(240, 190, 80), material = M.Metal, reflectance = 0.5 },
                { name = "Core", shape = "Ball", size = Vector3.new(0.50, 0.50, 0.50),
                  pos = Vector3.new(0, 0, 0.42), color = C(180, 120, 255), material = M.Neon,
                  light = { color = C(200, 150, 255), brightness = 3, range = 16 } },
                { name = "Star1", shape = "Ball", size = Vector3.new(0.07, 0.07, 0.07),
                  pos = Vector3.new(-0.3, 0.6, 0.42), color = C(255, 255, 200), material = M.Neon },
                { name = "Star2", shape = "Ball", size = Vector3.new(0.06, 0.06, 0.06),
                  pos = Vector3.new(0.32, -0.4, 0.42), color = C(200, 220, 255), material = M.Neon },
                { name = "Star3", shape = "Ball", size = Vector3.new(0.05, 0.05, 0.05),
                  pos = Vector3.new(0.1, 0.9, 0.45), color = C(255, 220, 255), material = M.Neon },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.44, 0.24, 0.24),
                  pos = Vector3.new(0, 1.45, 0), rot = Vector3.new(0, 0, 90), color = C(40, 25, 70), material = M.SmoothPlastic,
                  emitter = { color = C(210, 160, 255), size = 0.9,
                              speed = NumberRange.new(6, 12), lifetime = NumberRange.new(0.7, 1.5), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.6, 0), rot = Vector3.new(0, 0, 0), spin = 1.5,
                  count = 12, radius = 0.72, segSize = Vector3.new(0.09, 0.09, 0.09), segColor = C(240, 190, 80) },
                { name = "RingB", pos = Vector3.new(0, 0, 0), rot = Vector3.new(28, 0, 0), spin = -1.2,
                  count = 12, radius = 0.85, segSize = Vector3.new(0.08, 0.08, 0.08), segColor = C(160, 120, 255) },
                { name = "RingC", pos = Vector3.new(0, -0.6, 0), rot = Vector3.new(-28, 0, 0), spin = 0.9,
                  count = 12, radius = 0.72, segSize = Vector3.new(0.08, 0.08, 0.08), segColor = C(120, 180, 255) },
            },
        },
    },

    -- ===================================================================== 6
    titan = {
        id = "titan",
        name = "TITAN VAPE",
        house = "old_town",
        district = "old_town",
        description = "Cuerpo cilindrico voluminoso y acabado de taller industrial.",
        hold = { offset = Vector3.new(0, -0.42, -0.62), rot = Vector3.new(-10, 0, 12), scale = 1.1 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Cylinder", size = Vector3.new(2.00, 0.95, 0.95),
                  pos = Vector3.new(0, 0, 0), rot = Vector3.new(0, 0, 90), color = C(58, 60, 66), material = M.Metal, reflectance = 0.25 },
                { name = "CapTop", shape = "Cylinder", size = Vector3.new(0.34, 1.10, 1.10),
                  pos = Vector3.new(0, 1.10, 0), rot = Vector3.new(0, 0, 90), color = C(80, 84, 92), material = M.DiamondPlate, reflectance = 0.3 },
                { name = "CapBot", shape = "Cylinder", size = Vector3.new(0.34, 1.05, 1.05),
                  pos = Vector3.new(0, -1.10, 0), rot = Vector3.new(0, 0, 90), color = C(70, 74, 82), material = M.DiamondPlate },
                { name = "BandA", shape = "Cylinder", size = Vector3.new(0.20, 1.02, 1.02),
                  pos = Vector3.new(0, 0.32, 0), rot = Vector3.new(0, 0, 90), color = C(255, 140, 40), material = M.Neon },
                { name = "BandB", shape = "Cylinder", size = Vector3.new(0.20, 1.02, 1.02),
                  pos = Vector3.new(0, -0.32, 0), rot = Vector3.new(0, 0, 90), color = C(255, 140, 40), material = M.Neon },
                { name = "Vent", shape = "Block", size = Vector3.new(0.50, 0.90, 0.10),
                  pos = Vector3.new(0, 0, -0.52), color = C(30, 32, 36), material = M.Metal },
                { name = "BoltA", shape = "Block", size = Vector3.new(0.10, 0.10, 0.10),
                  pos = Vector3.new(0.36, 1.10, 0.36), color = C(20, 20, 24), material = M.Metal },
                { name = "BoltB", shape = "Block", size = Vector3.new(0.10, 0.10, 0.10),
                  pos = Vector3.new(-0.36, 1.10, -0.36), color = C(20, 20, 24), material = M.Metal },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.40, 0.30, 0.30),
                  pos = Vector3.new(0, 1.42, 0), rot = Vector3.new(0, 0, 90), color = C(24, 24, 28), material = M.SmoothPlastic,
                  emitter = { color = C(255, 190, 120), size = 0.85,
                              speed = NumberRange.new(5, 10), lifetime = NumberRange.new(0.6, 1.2), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.7, 0), rot = Vector3.new(0, 0, 0), spin = 1.1,
                  count = 10, radius = 0.62, segSize = Vector3.new(0.10, 0.08, 0.14), segColor = C(255, 140, 40) },
            },
        },
    },

    -- ===================================================================== 7
    phantom = {
        id = "phantom",
        name = "PHANTOM VAPE",
        house = "downtown",
        district = "downtown",
        description = "Silueta afinada, acabado oscuro y un brillo fantasma.",
        hold = { offset = Vector3.new(0, -0.35, -0.55), rot = Vector3.new(-10, 0, 14), scale = 1.05 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.36, 1.95, 0.32),
                  pos = Vector3.new(0, 0, 0), color = C(12, 12, 18), material = M.Metal, reflectance = 0.15 },
                { name = "EdgeL", shape = "Block", size = Vector3.new(0.04, 1.85, 0.34),
                  pos = Vector3.new(-0.18, 0, 0), color = C(150, 90, 255), material = M.Neon },
                { name = "EdgeR", shape = "Block", size = Vector3.new(0.04, 1.85, 0.34),
                  pos = Vector3.new(0.18, 0, 0), color = C(150, 90, 255), material = M.Neon },
                { name = "Visor", shape = "Block", size = Vector3.new(0.30, 0.10, 0.34),
                  pos = Vector3.new(0, 0.55, 0), color = C(190, 140, 255), material = M.Neon, transparency = 0.2 },
                { name = "Core", shape = "Ball", size = Vector3.new(0.24, 0.24, 0.24),
                  pos = Vector3.new(0, 0, 0.22), color = C(170, 110, 255), material = M.Neon,
                  light = { color = C(160, 110, 255), brightness = 2.2, range = 12 } },
                { name = "Shard", shape = "Ball", size = Vector3.new(0.14, 0.14, 0.14),
                  pos = Vector3.new(0, 0.92, 0.2), color = C(210, 180, 255), material = M.Neon },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.34, 0.16, 0.16),
                  pos = Vector3.new(0, 1.18, 0), rot = Vector3.new(0, 0, 90), color = C(16, 16, 22), material = M.SmoothPlastic,
                  emitter = { color = C(190, 150, 255), size = 0.7,
                              speed = NumberRange.new(4, 9), lifetime = NumberRange.new(0.6, 1.3), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, -0.75, 0), rot = Vector3.new(0, 0, 0), spin = 0.8,
                  count = 8, radius = 0.34, segSize = Vector3.new(0.06, 0.06, 0.10), segColor = C(150, 100, 255) },
            },
        },
    },

    -- ===================================================================== 8
    plasma = {
        id = "plasma",
        name = "PLASMA VAPE",
        house = "industrial",
        district = "industrial",
        description = "Geometria angular con arcos electricos decorativos.",
        hold = { offset = Vector3.new(0, -0.4, -0.6), rot = Vector3.new(-11, 0, 13), scale = 1.05 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.54, 1.55, 0.46),
                  pos = Vector3.new(0, 0, 0), color = C(16, 22, 30), material = M.Metal, reflectance = 0.2 },
                { name = "ArcTL", shape = "Block", size = Vector3.new(0.07, 1.00, 0.07),
                  pos = Vector3.new(-0.27, 0.18, 0.24), rot = Vector3.new(0, 0, 34), color = C(80, 230, 255), material = M.Neon },
                { name = "ArcTR", shape = "Block", size = Vector3.new(0.07, 1.00, 0.07),
                  pos = Vector3.new(0.27, 0.18, 0.24), rot = Vector3.new(0, 0, -34), color = C(80, 230, 255), material = M.Neon },
                { name = "ArcBL", shape = "Block", size = Vector3.new(0.07, 1.00, 0.07),
                  pos = Vector3.new(-0.27, -0.18, 0.24), rot = Vector3.new(0, 0, -34), color = C(255, 80, 200), material = M.Neon },
                { name = "ArcBR", shape = "Block", size = Vector3.new(0.07, 1.00, 0.07),
                  pos = Vector3.new(0.27, -0.18, 0.24), rot = Vector3.new(0, 0, 34), color = C(255, 80, 200), material = M.Neon },
                { name = "Core", shape = "Ball", size = Vector3.new(0.30, 0.30, 0.30),
                  pos = Vector3.new(0, 0, 0.26), color = C(160, 240, 255), material = M.Neon,
                  light = { color = C(120, 220, 255), brightness = 2.6, range = 13 } },
                { name = "TipA", shape = "Ball", size = Vector3.new(0.10, 0.10, 0.10),
                  pos = Vector3.new(0, 0.95, -0.2), color = C(120, 240, 255), material = M.Neon },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.32, 0.16, 0.16),
                  pos = Vector3.new(0, 1.12, 0), rot = Vector3.new(0, 0, 90), color = C(14, 18, 24), material = M.SmoothPlastic,
                  emitter = { color = C(140, 230, 255), size = 0.75,
                              speed = NumberRange.new(5, 10), lifetime = NumberRange.new(0.6, 1.2), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.55, 0), rot = Vector3.new(0, 0, 0), spin = 3.0,
                  count = 8, radius = 0.5, segSize = Vector3.new(0.07, 0.06, 0.12), segColor = C(90, 230, 255) },
                { name = "RingB", pos = Vector3.new(0, -0.55, 0), rot = Vector3.new(0, 0, 0), spin = -3.0,
                  count = 8, radius = 0.5, segSize = Vector3.new(0.07, 0.06, 0.12), segColor = C(255, 90, 200) },
            },
        },
    },

    -- ===================================================================== 9
    quantum = {
        id = "quantum",
        name = "QUANTUM VAPE",
        house = "industrial",
        district = "industrial",
        description = "Nucleo tecnologico con pantalla y anillos en contrarrotacion.",
        hold = { offset = Vector3.new(0, -0.45, -0.65), rot = Vector3.new(-11, 0, 13), scale = 1.1 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.52, 1.60, 0.46),
                  pos = Vector3.new(0, 0, 0), color = C(24, 28, 38), material = M.Metal, reflectance = 0.25 },
                { name = "Bezel", shape = "Block", size = Vector3.new(0.44, 0.60, 0.05),
                  pos = Vector3.new(0, 0.20, 0.24), color = C(8, 10, 14), material = M.SmoothPlastic },
                { name = "Screen", shape = "Block", size = Vector3.new(0.36, 0.50, 0.03),
                  pos = Vector3.new(0, 0.20, 0.27), color = C(0, 0, 0), material = M.SmoothPlastic,
                  screen = { text = "QUANTUM", color = C(120, 255, 220), background = C(4, 18, 20) } },
                { name = "RailL", shape = "Block", size = Vector3.new(0.06, 1.40, 0.50),
                  pos = Vector3.new(-0.27, 0, 0), color = C(120, 255, 220), material = M.Neon, rgb = 2 },
                { name = "RailR", shape = "Block", size = Vector3.new(0.06, 1.40, 0.50),
                  pos = Vector3.new(0.27, 0, 0), color = C(120, 255, 220), material = M.Neon, rgb = 2 },
                { name = "Antenna", shape = "Cylinder", size = Vector3.new(0.5, 0.05, 0.05),
                  pos = Vector3.new(0, 0.90, -0.2), rot = Vector3.new(0, 0, 90), color = C(190, 200, 215), material = M.Metal },
                { name = "AntennaTip", shape = "Ball", size = Vector3.new(0.09, 0.09, 0.09),
                  pos = Vector3.new(0, 1.12, -0.2), color = C(120, 255, 220), material = M.Neon,
                  light = { color = C(120, 255, 220), brightness = 2, range = 9 } },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.32, 0.16, 0.16),
                  pos = Vector3.new(0, 1.28, 0), rot = Vector3.new(0, 0, 90), color = C(16, 20, 26), material = M.SmoothPlastic,
                  emitter = { color = C(150, 255, 230), size = 0.8,
                              speed = NumberRange.new(5, 10), lifetime = NumberRange.new(0.6, 1.2), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.6, 0), rot = Vector3.new(0, 0, 0), spin = 2.0,
                  count = 10, radius = 0.6, segSize = Vector3.new(0.08, 0.07, 0.14), segColor = C(120, 255, 220) },
                { name = "RingB", pos = Vector3.new(0, -0.6, 0), rot = Vector3.new(0, 0, 0), spin = -2.0,
                  count = 10, radius = 0.6, segSize = Vector3.new(0.08, 0.07, 0.14), segColor = C(90, 160, 255) },
            },
        },
    },

    -- ===================================================================== 10
    inferno = {
        id = "inferno",
        name = "INFERNO VAPE",
        house = "hills",
        district = "suburban_hills",
        description = "Materiales oscuros y acentos luminosos calidos.",
        hold = { offset = Vector3.new(0, -0.48, -0.7), rot = Vector3.new(-12, 0, 12), scale = 1.15 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.56, 1.75, 0.50),
                  pos = Vector3.new(0, 0, 0), color = C(20, 10, 8), material = M.Metal, reflectance = 0.2 },
                { name = "VentA", shape = "Block", size = Vector3.new(0.42, 0.06, 0.05),
                  pos = Vector3.new(0, 0.52, 0.26), color = C(255, 120, 40), material = M.Neon },
                { name = "VentB", shape = "Block", size = Vector3.new(0.42, 0.06, 0.05),
                  pos = Vector3.new(0, 0.24, 0.26), color = C(255, 120, 40), material = M.Neon },
                { name = "VentC", shape = "Block", size = Vector3.new(0.42, 0.06, 0.05),
                  pos = Vector3.new(0, -0.04, 0.26), color = C(255, 120, 40), material = M.Neon },
                { name = "VentD", shape = "Block", size = Vector3.new(0.42, 0.06, 0.05),
                  pos = Vector3.new(0, -0.32, 0.26), color = C(255, 120, 40), material = M.Neon },
                { name = "Core", shape = "Ball", size = Vector3.new(0.32, 0.32, 0.32),
                  pos = Vector3.new(0, 0, 0.28), color = C(255, 150, 60), material = M.Neon,
                  light = { color = C(255, 130, 50), brightness = 2.8, range = 14 } },
                { name = "TopFin", shape = "Block", size = Vector3.new(0.5, 0.10, 0.5),
                  pos = Vector3.new(0, 0.95, 0), color = C(34, 18, 14), material = M.Metal },
                { name = "Ember", shape = "Ball", size = Vector3.new(0.08, 0.08, 0.08),
                  pos = Vector3.new(0, 1.05, 0.2), color = C(255, 210, 120), material = M.Neon },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.36, 0.18, 0.18),
                  pos = Vector3.new(0, 1.24, 0), rot = Vector3.new(0, 0, 90), color = C(22, 12, 10), material = M.SmoothPlastic,
                  emitter = { color = C(255, 170, 90), size = 0.9,
                              speed = NumberRange.new(6, 12), lifetime = NumberRange.new(0.7, 1.4), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.55, 0), rot = Vector3.new(0, 0, 0), spin = 2.6,
                  count = 10, radius = 0.56, segSize = Vector3.new(0.08, 0.07, 0.14), segColor = C(255, 130, 50) },
                { name = "RingB", pos = Vector3.new(0, -0.55, 0), rot = Vector3.new(0, 0, 0), spin = -2.6,
                  count = 10, radius = 0.56, segSize = Vector3.new(0.08, 0.07, 0.14), segColor = C(255, 70, 40) },
            },
        },
    },

    -- ===================================================================== 11
    aurora = {
        id = "aurora",
        name = "AURORA VAPE",
        house = "hills_manor",
        district = "suburban_hills",
        description = "Acabado iridiscente y luces de colores en cascada.",
        hold = { offset = Vector3.new(0, -0.5, -0.72), rot = Vector3.new(-12, 0, 12), scale = 1.15 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.52, 1.7, 0.46),
                  pos = Vector3.new(0, 0, 0), color = C(210, 220, 235), material = M.SmoothPlastic, reflectance = 0.55 },
                { name = "StripeCyan", shape = "Block", size = Vector3.new(0.06, 1.55, 0.48),
                  pos = Vector3.new(-0.21, 0, 0), color = C(90, 255, 230), material = M.Neon },
                { name = "StripeViolet", shape = "Block", size = Vector3.new(0.06, 1.55, 0.48),
                  pos = Vector3.new(-0.07, 0, 0), color = C(170, 120, 255), material = M.Neon },
                { name = "StripePink", shape = "Block", size = Vector3.new(0.06, 1.55, 0.48),
                  pos = Vector3.new(0.07, 0, 0), color = C(255, 120, 220), material = M.Neon },
                { name = "StripeGreen", shape = "Block", size = Vector3.new(0.06, 1.55, 0.48),
                  pos = Vector3.new(0.21, 0, 0), color = C(140, 255, 160), material = M.Neon },
                { name = "TopTrim", shape = "Block", size = Vector3.new(0.58, 0.10, 0.52),
                  pos = Vector3.new(0, 0.9, 0), color = C(235, 240, 250), material = M.Metal, reflectance = 0.5 },
                { name = "Core", shape = "Ball", size = Vector3.new(0.26, 0.26, 0.26),
                  pos = Vector3.new(0, 0, 0.27), color = C(255, 255, 255), material = M.Neon,
                  light = { color = C(200, 230, 255), brightness = 2.6, range = 13 } },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.34, 0.16, 0.16),
                  pos = Vector3.new(0, 1.2, 0), rot = Vector3.new(0, 0, 90), color = C(40, 44, 56), material = M.SmoothPlastic,
                  emitter = { color = C(210, 235, 255), size = 0.85,
                              speed = NumberRange.new(5, 10), lifetime = NumberRange.new(0.6, 1.3), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.62, 0), rot = Vector3.new(0, 0, 0), spin = 1.7,
                  count = 12, radius = 0.5, segSize = Vector3.new(0.07, 0.07, 0.12), segColor = C(120, 240, 255) },
                { name = "RingB", pos = Vector3.new(0, -0.62, 0), rot = Vector3.new(0, 0, 0), spin = -1.7,
                  count = 12, radius = 0.5, segSize = Vector3.new(0.07, 0.07, 0.12), segColor = C(255, 150, 230) },
            },
        },
    },

    -- ===================================================================== 12
    obsidian = {
        id = "obsidian",
        name = "OBSIDIAN VAPE",
        house = "neon_house",
        district = "neon",
        description = "Premium negro pulido con detalles dorados y nucleo blanco.",
        hold = { offset = Vector3.new(0, -0.5, -0.72), rot = Vector3.new(-12, 0, 12), scale = 1.15 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.48, 1.65, 0.42),
                  pos = Vector3.new(0, 0, 0), color = C(10, 10, 12), material = M.Metal, reflectance = 0.5 },
                { name = "GoldTop", shape = "Block", size = Vector3.new(0.52, 0.07, 0.46),
                  pos = Vector3.new(0, 0.86, 0), color = C(240, 195, 90), material = M.Metal, reflectance = 0.6 },
                { name = "GoldBot", shape = "Block", size = Vector3.new(0.52, 0.07, 0.46),
                  pos = Vector3.new(0, -0.86, 0), color = C(240, 195, 90), material = M.Metal, reflectance = 0.6 },
                { name = "Core", shape = "Ball", size = Vector3.new(0.24, 0.24, 0.24),
                  pos = Vector3.new(0, 0.12, 0.24), color = C(255, 255, 255), material = M.Neon,
                  light = { color = C(255, 250, 235), brightness = 2.6, range = 13 } },
                { name = "Logo", shape = "Block", size = Vector3.new(0.06, 0.30, 0.05),
                  pos = Vector3.new(0, -0.35, 0.23), color = C(240, 195, 90), material = M.Neon },
                { name = "Tip", shape = "Ball", size = Vector3.new(0.07, 0.07, 0.07),
                  pos = Vector3.new(0, 0.98, -0.16), color = C(255, 240, 200), material = M.Neon },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.34, 0.16, 0.16),
                  pos = Vector3.new(0, 1.14, 0), rot = Vector3.new(0, 0, 90), color = C(14, 14, 16), material = M.SmoothPlastic,
                  emitter = { color = C(255, 245, 225), size = 0.9,
                              speed = NumberRange.new(5, 11), lifetime = NumberRange.new(0.7, 1.4), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.55, 0), rot = Vector3.new(0, 0, 0), spin = 1.4,
                  count = 12, radius = 0.46, segSize = Vector3.new(0.06, 0.06, 0.10), segColor = C(240, 195, 90) },
            },
        },
    },

    -- ===================================================================== 13
    nebula = {
        id = "nebula",
        name = "NEBULA VAPE",
        house = "neon_tower",
        district = "neon",
        description = "Orbes de gas, nubes ambientales y anillos orbitales.",
        hold = { offset = Vector3.new(0, -0.55, -0.85), rot = Vector3.new(-13, 0, 11), scale = 1.2 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.80, 2.20, 0.70),
                  pos = Vector3.new(0, 0, 0), color = C(30, 18, 60), material = M.Metal, reflectance = 0.3 },
                { name = "Trim", shape = "Block", size = Vector3.new(0.86, 0.10, 0.76),
                  pos = Vector3.new(0, 1.0, 0), color = C(120, 90, 200), material = M.Metal, reflectance = 0.4 },
                { name = "OrbA", shape = "Ball", size = Vector3.new(0.34, 0.34, 0.34),
                  pos = Vector3.new(0.28, 0.5, 0.42), color = C(150, 120, 255), material = M.Neon,
                  light = { color = C(150, 120, 255), brightness = 2.4, range = 13 } },
                { name = "OrbB", shape = "Ball", size = Vector3.new(0.26, 0.26, 0.26),
                  pos = Vector3.new(-0.3, 0.1, 0.44), color = C(110, 190, 255), material = M.Neon,
                  light = { color = C(110, 190, 255), brightness = 2, range = 11 } },
                { name = "OrbC", shape = "Ball", size = Vector3.new(0.22, 0.22, 0.22),
                  pos = Vector3.new(0.1, -0.6, 0.42), color = C(255, 150, 230), material = M.Neon },
                { name = "Core", shape = "Ball", size = Vector3.new(0.42, 0.42, 0.42),
                  pos = Vector3.new(0, 0, 0.42), color = C(180, 140, 255), material = M.Neon,
                  light = { color = C(180, 140, 255), brightness = 3, range = 17 },
                  emitter = { color = C(200, 170, 255), size = 0.5,
                              speed = NumberRange.new(1, 3), lifetime = NumberRange.new(1.2, 2.2), rate = 0 } },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.44, 0.22, 0.22),
                  pos = Vector3.new(0, 1.45, 0), rot = Vector3.new(0, 0, 90), color = C(36, 22, 70), material = M.SmoothPlastic,
                  emitter = { color = C(210, 170, 255), size = 1.0,
                              speed = NumberRange.new(6, 12), lifetime = NumberRange.new(0.8, 1.6), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.7, 0), rot = Vector3.new(0, 0, 0), spin = 1.2,
                  count = 14, radius = 0.9, segSize = Vector3.new(0.08, 0.08, 0.08), segColor = C(180, 140, 255) },
                { name = "RingB", pos = Vector3.new(0, -0.7, 0), rot = Vector3.new(0, 0, 0), spin = -1.2,
                  count = 14, radius = 0.9, segSize = Vector3.new(0.08, 0.08, 0.08), segColor = C(110, 190, 255) },
            },
        },
    },

    -- ===================================================================== 14
    eclipse = {
        id = "eclipse",
        name = "ECLIPSE VAPE",
        house = "elite",
        district = "elite_heights",
        description = "Silueta exclusiva: esfera oscura y halo dorado en orbita.",
        hold = { offset = Vector3.new(0, -0.55, -0.85), rot = Vector3.new(-13, 0, 11), scale = 1.2 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.46, 1.75, 0.42),
                  pos = Vector3.new(0, 0, 0), color = C(12, 12, 16), material = M.Metal, reflectance = 0.4 },
                { name = "Sphere", shape = "Ball", size = Vector3.new(0.74, 0.74, 0.74),
                  pos = Vector3.new(0, 0, 0.14), color = C(10, 10, 14), material = M.Metal, reflectance = 0.5 },
                { name = "GlowLineL", shape = "Block", size = Vector3.new(0.05, 1.5, 0.05),
                  pos = Vector3.new(-0.2, 0, 0.22), color = C(255, 215, 120), material = M.Neon },
                { name = "GlowLineR", shape = "Block", size = Vector3.new(0.05, 1.5, 0.05),
                  pos = Vector3.new(0.2, 0, 0.22), color = C(255, 215, 120), material = M.Neon },
                { name = "Core", shape = "Ball", size = Vector3.new(0.3, 0.3, 0.3),
                  pos = Vector3.new(0, 0, 0.5), color = C(255, 235, 180), material = M.Neon,
                  light = { color = C(255, 225, 150), brightness = 3, range = 16 } },
                { name = "TopCap", shape = "Block", size = Vector3.new(0.42, 0.12, 0.38),
                  pos = Vector3.new(0, 0.92, 0), color = C(30, 26, 18), material = M.Metal, reflectance = 0.5 },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.36, 0.18, 0.18),
                  pos = Vector3.new(0, 1.2, 0), rot = Vector3.new(0, 0, 90), color = C(16, 14, 12), material = M.SmoothPlastic,
                  emitter = { color = C(255, 230, 180), size = 0.95,
                              speed = NumberRange.new(6, 12), lifetime = NumberRange.new(0.7, 1.5), rate = 0 } },
            },
            groups = {
                { name = "Halo", pos = Vector3.new(0, 0, 0.14), rot = Vector3.new(74, 0, 0), spin = 0.7,
                  count = 18, radius = 0.62, segSize = Vector3.new(0.07, 0.07, 0.07), segColor = C(255, 215, 120) },
                { name = "RingA", pos = Vector3.new(0, -0.7, 0), rot = Vector3.new(0, 0, 0), spin = 1.0,
                  count = 12, radius = 0.5, segSize = Vector3.new(0.06, 0.06, 0.10), segColor = C(255, 235, 180) },
            },
        },
    },

    -- ===================================================================== 15
    omega = {
        id = "omega",
        name = "OMEGA VAPE",
        house = "elite_manor",
        district = "elite_heights",
        description = "La pieza final. Coronas, nucleo solar y anillos orbitales.",
        hold = { offset = Vector3.new(0, -0.62, -0.95), rot = Vector3.new(-13, 0, 10), scale = 1.25 },
        model = {
            parts = {
                { name = "Body", primary = true, shape = "Block", size = Vector3.new(0.92, 2.40, 0.82),
                  pos = Vector3.new(0, 0, 0), color = C(26, 26, 34), material = M.Metal, reflectance = 0.45 },
                { name = "TierTop", shape = "Block", size = Vector3.new(1.00, 0.14, 0.90),
                  pos = Vector3.new(0, 1.18, 0), color = C(240, 195, 90), material = M.Metal, reflectance = 0.6 },
                { name = "TierBot", shape = "Block", size = Vector3.new(1.00, 0.14, 0.90),
                  pos = Vector3.new(0, -1.18, 0), color = C(240, 195, 90), material = M.Metal, reflectance = 0.6 },
                { name = "CrownBase", shape = "Block", size = Vector3.new(1.05, 0.12, 0.95),
                  pos = Vector3.new(0, 1.30, 0), color = C(240, 195, 90), material = M.Metal, reflectance = 0.6 },
                { name = "CrestL", shape = "Block", size = Vector3.new(0.12, 0.50, 0.12),
                  pos = Vector3.new(-0.38, 1.55, 0), color = C(255, 220, 140), material = M.Neon },
                { name = "CrestC", shape = "Block", size = Vector3.new(0.12, 0.62, 0.12),
                  pos = Vector3.new(0, 1.60, 0), color = C(255, 120, 200), material = M.Neon },
                { name = "CrestR", shape = "Block", size = Vector3.new(0.12, 0.50, 0.12),
                  pos = Vector3.new(0.38, 1.55, 0), color = C(255, 220, 140), material = M.Neon },
                { name = "Core", shape = "Ball", size = Vector3.new(0.62, 0.62, 0.62),
                  pos = Vector3.new(0, 0, 0.5), color = C(255, 225, 150), material = M.Neon,
                  light = { color = C(255, 220, 150), brightness = 3.4, range = 20 },
                  emitter = { color = C(255, 230, 170), size = 0.42,
                              speed = NumberRange.new(1, 4), lifetime = NumberRange.new(1.0, 2.0), rate = 0 } },
                { name = "CrystalL", shape = "Block", size = Vector3.new(0.18, 0.55, 0.18),
                  pos = Vector3.new(-0.52, 0, 0.2), rot = Vector3.new(0, 0, 42), color = C(120, 230, 255), material = M.Neon },
                { name = "CrystalR", shape = "Block", size = Vector3.new(0.18, 0.55, 0.18),
                  pos = Vector3.new(0.52, 0, 0.2), rot = Vector3.new(0, 0, -42), color = C(120, 230, 255), material = M.Neon },
                { name = "Mouthpiece", shape = "Cylinder", size = Vector3.new(0.50, 0.26, 0.26),
                  pos = Vector3.new(0, 2.05, 0), rot = Vector3.new(0, 0, 90), color = C(30, 26, 22), material = M.SmoothPlastic,
                  emitter = { color = C(255, 235, 190), size = 1.1,
                              speed = NumberRange.new(7, 13), lifetime = NumberRange.new(0.8, 1.7), rate = 0 } },
            },
            groups = {
                { name = "RingA", pos = Vector3.new(0, 0.9, 0), rot = Vector3.new(0, 0, 0), spin = 1.1,
                  count = 14, radius = 1.05, segSize = Vector3.new(0.09, 0.09, 0.09), segColor = C(240, 195, 90) },
                { name = "RingB", pos = Vector3.new(0, 0, 0), rot = Vector3.new(30, 0, 0), spin = -0.9,
                  count = 16, radius = 1.15, segSize = Vector3.new(0.08, 0.08, 0.08), segColor = C(160, 120, 255) },
                { name = "RingC", pos = Vector3.new(0, -0.9, 0), rot = Vector3.new(0, 0, 0), spin = 0.8,
                  count = 14, radius = 1.05, segSize = Vector3.new(0.08, 0.08, 0.08), segColor = C(120, 230, 255) },
                { name = "CoreRing", pos = Vector3.new(0, 0, 0.5), rot = Vector3.new(90, 0, 0), spin = 2.0,
                  count = 12, radius = 0.72, segSize = Vector3.new(0.07, 0.07, 0.07), segColor = C(255, 235, 180) },
            },
        },
    },
}

-- Inyeccion de la economia (precio + multiplicador) desde EconomyConfig ------
-- Se hace aqui para que exista una sola fuente de verdad: si cambias un precio,
-- solo se toca EconomyConfig.
for id, cfg in pairs(VapeConfig.Vapes) do
    cfg.price = EconomyConfig.Price(id)
    cfg.multiplier = EconomyConfig.Multiplier(id)
    cfg.rarity = EconomyConfig.RarityOf(id)
end

-- Helper: obtiene un vape por id
function VapeConfig.Get(id)
    return VapeConfig.Vapes[id]
end

-- Helper: lista ordenada
function VapeConfig.GetOrdered()
    local list = {}
    for _, id in ipairs(VapeConfig.Order) do
        table.insert(list, VapeConfig.Vapes[id])
    end
    return list
end

-- Helper: vapers que vende una casa
function VapeConfig.ByHouse(houseId)
    local list = {}
    for _, id in ipairs(VapeConfig.Order) do
        if VapeConfig.Vapes[id].house == houseId then
            table.insert(list, VapeConfig.Vapes[id])
        end
    end
    return list
end

return VapeConfig
