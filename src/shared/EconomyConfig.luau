--[[
    EconomyConfig
    Ruta en Roblox Studio: ReplicatedStorage > Shared > EconomyConfig
    Tipo: ModuleScript

    UNICA FUENTE DE VERDAD de la economia. Aqui se ajustan precios,
    multiplicadores, requisitos de distrito y costes de acceso a casas sin
    buscar numeros por otros scripts.

    Criterio de diseno (requisito del proyecto): la progresion NO es
    exponencial. Los precios crecen, pero cada vez con un factor menor, y los
    multiplicadores crecen de forma casi lineal. El resultado es que "acciones
    necesarias para el siguiente vaper" sube de forma suave y monótona en vez
    de dispararse:

        accion_i ~= Precio[i] / Multiplicador[i-1]

        v2=100  v3=150  v4=233  v5=350  v6=520   <- primeros 5, ritmo rapido
        v7=600  v8=700  v9=818  v10=893 v11=1000
        v12=1095 v13=1240 v14=1366 v15=1500     <- a partir de v6, mas exigente

    Los cinco primeros vapers se consiguen rapido (aprendizaje + sensacion de
    progreso). A partir del sexto el ritmo se vuelve mas exigente, pero nunca
    injusto: el peor salto es ~1,4x respecto al anterior, no 2x o 4x.

    Nada de logica aqui: solo datos y helpers de consulta.
]]

local EconomyConfig = {}

-- Orden canonico de los 15 dispositivos --------------------------------------
EconomyConfig.VapeOrder = {
    "basic", "neon", "cyber", "hyper", "galaxy",
    "titan", "phantom", "plasma", "quantum", "inferno",
    "aurora", "obsidian", "nebula", "eclipse", "omega",
}

-- Precio en Puffs -------------------------------------------------------------
EconomyConfig.Prices = {
    basic = 0, neon = 100, cyber = 300, hyper = 700, galaxy = 1400,
    titan = 2600, phantom = 4200, plasma = 6300, quantum = 9000, inferno = 12500,
    aurora = 17000, obsidian = 23000, nebula = 31000, eclipse = 41000, omega = 54000,
}

-- Puffs por calada ------------------------------------------------------------
-- Crecimiento casi lineal (no exponencial): la mejora se nota, pero un vaper
-- antiguo nunca queda inutil.
EconomyConfig.Multipliers = {
    basic = 1, neon = 2, cyber = 3, hyper = 4, galaxy = 5,
    titan = 7, phantom = 9, plasma = 11, quantum = 14, inferno = 17,
    aurora = 21, obsidian = 25, nebula = 30, eclipse = 36, omega = 43,
}

-- Rareza (solo etiqueta visual / color de tienda) ----------------------------
-- 0 Comun, 1 Poco comun, 2 Raro, 3 Epico, 4 Legendario, 5 Mitico
EconomyConfig.Rarity = {
    basic = 0, neon = 0, cyber = 0,
    hyper = 1, galaxy = 1,
    titan = 2, phantom = 2, plasma = 2,
    quantum = 3, inferno = 3, aurora = 3,
    obsidian = 4, nebula = 4, eclipse = 4,
    omega = 5,
}

EconomyConfig.RarityNames = { "COMUN", "POCO COMUN", "RARO", "EPICO", "LEGENDARIO", "MITICO" }

EconomyConfig.RarityColors = {
    Color3.fromRGB(170, 180, 200),  -- comun
    Color3.fromRGB(110, 220, 150),  -- poco comun
    Color3.fromRGB(90, 180, 255),   -- raro
    Color3.fromRGB(190, 130, 255),  -- epico
    Color3.fromRGB(255, 190, 70),   -- legendario
    Color3.fromRGB(255, 90, 140),   -- mitico
}

-- Requisito de Puffs para "descubrir" un distrito -----------------------------
-- Los distritos son transitables libremente (mundo abierto). Esto es un hito
-- de descubrimiento: al alcanzarlo se revela en el mapa y da una recompensa.
-- Se fijan un poco por debajo de la primera casa del distrito para que el
-- jugador llegue ANTES al distrito que a su contenido.
EconomyConfig.DistrictRequirements = {
    starter_block  = 0,
    suburban_east  = 0,
    old_town       = 1200,
    downtown       = 2400,
    industrial     = 4200,
    suburban_hills = 7000,
    neon           = 13000,
    elite_heights  = 25000,
}

-- Coste de acceso a las casas funcionales (los dealers viven dentro) ---------
-- Casa inicial gratis. Resto segun la progresion pedida en el diseno.
EconomyConfig.HouseCosts = {
    starter      = 0,
    suburb_a     = 100,
    suburb_b     = 350,
    suburb_c     = 800,
    old_town     = 1600,
    downtown     = 3000,
    industrial   = 5000,
    hills        = 9000,
    hills_manor  = 12000,
    neon_house   = 16000,
    neon_tower   = 22000,
    elite        = 30000,
    elite_manor  = 54000,
}

-- Precio de los VEHICULOS en Puffs -------------------------------------------
-- Un vehiculo se compra UNA vez y se despliega tantas veces como se quiera.
-- El primer vehiculo (patinete) esta calibrado a 500 Puffs: se alcanza en la
-- primera media hora de juego (vaper neon = 100, cyber = 300) y no compite con
-- el precio de ninguna casa.
EconomyConfig.VehiclePrices = {
    scooter = 500,
}

-- Recompensas de exploracion / descubrimiento --------------------------------
EconomyConfig.Rewards = {
    DistrictDiscover = 0,      -- revelar distrito no da Puffs (evita farmeo caminando)
    HouseDiscover   = 40,      -- descubrir una casa nueva (antes de pagar) da un bonus
    MissionBase     = 0,       -- las misiones definen su propia recompensa
}

-- Helpers ---------------------------------------------------------------------
function EconomyConfig.Price(id)
    return EconomyConfig.Prices[id] or 0
end

function EconomyConfig.Multiplier(id)
    return EconomyConfig.Multipliers[id] or 1
end

--[[ Precio en Puffs de un vehiculo (0 si no existe). ]]
function EconomyConfig.VehiclePrice(id)
    return EconomyConfig.VehiclePrices[id] or 0
end

function EconomyConfig.RarityOf(id)
    return EconomyConfig.Rarity[id] or 0
end

function EconomyConfig.RarityName(id)
    return EconomyConfig.RarityNames[(EconomyConfig.RarityOf(id)) + 1] or "COMUN"
end

function EconomyConfig.RarityColor(id)
    return EconomyConfig.RarityColors[(EconomyConfig.RarityOf(id)) + 1] or Color3.fromRGB(200, 200, 200)
end

--[[ Acciones necesarias para pagar el vaper `index` usando el multiplicador
     del vaper anterior. Utilidad de balance: sirve para comprobar de un vistazo
     que la curva es suave y monotona. ]]
function EconomyConfig.ActionsToAfford(index)
    local order = EconomyConfig.VapeOrder
    if index < 2 or index > #order then
        return 0
    end
    local price = EconomyConfig.Price(order[index])
    local prevMult = EconomyConfig.Multiplier(order[index - 1])
    return math.ceil(price / math.max(1, prevMult))
end

return EconomyConfig
