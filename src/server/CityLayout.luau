--[[
    CityLayout
    Ruta en Roblox Studio: ServerScriptService > CityLayout
    Tipo: ModuleScript

    DISTRIBUCION URBANA. A partir de la reticula de CityGrid decide, sin crear
    nada todavia:

      * a que barrio pertenece cada bloque (por cercania a los centros de
        ZoneConfig.Districts; el anillo interior es "centro" comercial),
      * como se subdivide cada bloque en solares (lots) segun su perfil,
      * que solares quedan reservados (casas con dealer, parques, parkings),
      * el plan de carreteras: tramos de asfalto y los vanos donde se puede
        pintar (sin entrar en cruces ni en la plaza).

    Todo es deterministico: mismo mapa en cada servidor.

    Requiere: CityGrid, ZoneConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGrid = require(Shared:WaitForChild("CityGrid"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

local CityLayout = {}

local M = Enum.Material
local C = Color3.fromRGB

-- Perfiles de manzana por barrio ----------------------------------------------
-- floors = {min, max}; lots = subdivision {cols, rows}; kind decide la estetica.
-- gap    = retranqueo de cada solar (studs). Pequeno en el centro para que los
--          edificios formen una fachada urbana casi continua y queden callejones.
-- tower  = true -> lo construye TowerBuilder (rascacielos), no BuildingBuilder.
-- kinds  = variantes de silueta que BuildingBuilder elige por solar.
CityLayout.Profiles = {
    -- Nucleo comercial denso alrededor de la plaza (12 manzanas).
    centro = {
        kind = "mixed", kinds = { "mixed", "apartment", "hotel", "mixed", "lowrise", "apartment" },
        lots = { 3, 3 }, gap = 2, floors = { 3, 9 }, shops = 0.50, lit = 0.50,
    },
    -- Manzanas de esquina del nucleo: rascacielos emblematicos.
    landmark = {
        kind = "tower", lots = { 1, 1 }, gap = 8, floors = { 42, 78 },
        tower = true, landmark = true, shops = 0, lit = 0.72,
    },
    -- Zona financiera: torres altas y muy juntas.
    downtown = {
        kind = "tower", lots = { 2, 2 }, gap = 3, floors = { 24, 70 },
        tower = true, shops = 0.08, lit = 0.62,
    },
    -- Ocio nocturno: torres con neon.
    neon = {
        kind = "neon", lots = { 2, 2 }, gap = 3, floors = { 16, 46 },
        tower = true, shops = 0.25, lit = 0.80,
    },
    starter_block = {
        kind = "lowrise", kinds = { "lowrise", "mixed", "apartment", "lowrise" },
        lots = { 3, 3 }, gap = 3, floors = { 2, 5 }, shops = 0.35, lit = 0.30,
    },
    old_town = {
        kind = "brick", kinds = { "brick", "apartment", "brick" },
        lots = { 3, 3 }, gap = 2, floors = { 2, 5 }, shops = 0.40, lit = 0.35,
    },
    suburban_east = {
        kind = "house", lots = { 3, 3 }, gap = 5, floors = { 1, 2 }, shops = 0.10, lit = 0.20,
    },
    suburban_hills = {
        kind = "house", lots = { 3, 3 }, gap = 5, floors = { 1, 2 }, shops = 0.06, lit = 0.25,
        luxury = true,
    },
    elite_heights = {
        kind = "luxury", lots = { 2, 2 }, gap = 8, floors = { 2, 3 }, shops = 0.10, lit = 0.40,
        luxury = true,
    },
    industrial = {
        kind = "industrial", lots = { 2, 2 }, gap = 6, floors = { 1, 2 }, shops = 0.10, lit = 0.15,
    },
}

CityLayout.CentroStyle = {
    wall = { C(196, 192, 184), C(172, 178, 186), C(210, 200, 186), C(160, 166, 176) },
    roof = { C(96, 98, 104), C(120, 88, 74), C(88, 92, 100) },
    accent = C(120, 200, 255),
    material = M.Concrete,
}

-- Bloques reservados a parques y aparcamientos --------------------------------
-- Los parques van en las esquinas exteriores (1 por barrio de esquina) y los
-- aparcamientos en el anillo del centro, que es donde tiene sentido.
CityLayout.ParkBlocks = {
    { -650, -650 }, { 650, 650 }, { -650, 650 }, { 650, -650 },
}
CityLayout.ParkingBlocks = {
    { -130, 390 }, { 130, -390 },
}

--[[ Manzanas del nucleo que llevan un rascacielos emblematico. Son las cuatro
     esquinas que rodean la plaza (a 551 studs del centro): desde el spawn se
     ven las cuatro torres recortandose sobre el resto de la ciudad. ]]
CityLayout.LandmarkBlocks = {
    { 390, 390 }, { -390, 390 }, { 390, -390 }, { -390, -390 },
}

local function keyOf(cx, cz)
    return cx .. ":" .. cz
end

local parkSet, parkingSet, landmarkSet
local function buildSets()
    if parkSet then
        return
    end
    parkSet, parkingSet, landmarkSet = {}, {}, {}
    for _, p in ipairs(CityLayout.ParkBlocks) do
        parkSet[keyOf(p[1], p[2])] = true
    end
    for _, p in ipairs(CityLayout.ParkingBlocks) do
        parkingSet[keyOf(p[1], p[2])] = true
    end
    for _, p in ipairs(CityLayout.LandmarkBlocks) do
        landmarkSet[keyOf(p[1], p[2])] = true
    end
end

--[[ Barrio al que pertenece un punto.

     El nucleo (12 manzanas: el anillo que toca la plaza y las cuatro esquinas
     de 551 studs) es el "centro" comercial denso, que es donde se concentran
     las tiendas y los rascacielos emblematicos. El resto se reparte en 8
     sectores de 45 grados centrados en la direccion de cada distrito, de forma
     que cada barrio recibe su parte de forma equilibrada y las transiciones son
     continuas. ]]
local SECTORS = {
    "suburban_east", "suburban_hills", "starter_block", "industrial",
    "downtown", "elite_heights", "old_town", "neon",
}

CityLayout.CentroRadius = 560

function CityLayout.DistrictOf(cx, cz)
    local dist = math.sqrt(cx * cx + cz * cz)
    if dist < CityLayout.CentroRadius then
        return "centro"
    end
    local a = math.deg(math.atan2(cz, cx))
    if a < 0 then
        a += 360
    end
    local idx = math.floor((a + 22.5) / 45) % 8
    return SECTORS[idx + 1]
end

function CityLayout.ProfileOf(districtId)
    return CityLayout.Profiles[districtId] or CityLayout.Profiles.centro
end

function CityLayout.StyleOf(districtId)
    local d = ZoneConfig.Districts[districtId]
    if d and d.style then
        return d.style
    end
    return CityLayout.CentroStyle
end

-- Rectangulos reservados --------------------------------------------------------

function CityLayout.ReservedRects()
    local rects = {}
    for _, id in ipairs(ZoneConfig.HouseOrder) do
        rects[#rects + 1] = CityGrid.HouseRect(ZoneConfig.Houses[id], 12)
    end
    return rects
end

local function intersects(a, b)
    return not (a.x2 < b.x1 or a.x1 > b.x2 or a.z2 < b.z1 or a.z1 > b.z2)
end

-- Plan de carreteras ------------------------------------------------------------

local RUN_MIN = -(CityGrid.RING - CityGrid.Road.avenueWidth * 0.5)
local RUN_MAX = CityGrid.RING - CityGrid.Road.avenueWidth * 0.5

local function crossSetFor()
    local set = {}
    for _, l in ipairs(CityGrid.LINES) do
        set[l] = true
    end
    return set
end

local CROSS = crossSetFor()

local function marginAt(v)
    if CROSS[v] then
        return CityGrid.HalfRoad(v) + 4
    end
    if math.abs(math.abs(v) - CityGrid.Plaza.half) < 0.01 then
        return 3
    end
    return 5
end

--[[ Recorte de un tramo hasta el borde del asfalto de la calle que cruza. ]]
local function edgeInset(v)
    if CROSS[v] then
        return CityGrid.HalfRoad(v)
    end
    return 0
end

--[[ Cortes a lo largo de una calle: cada cruce y los bordes de la plaza. ]]
local function cutsFor(line)
    local cuts = { RUN_MIN }
    for _, c in ipairs(CityGrid.LINES) do
        if c > RUN_MIN + 0.01 and c < RUN_MAX - 0.01 then
            cuts[#cuts + 1] = c
        end
    end
    if math.abs(line) <= CityGrid.Plaza.half then
        cuts[#cuts + 1] = -CityGrid.Plaza.half
        cuts[#cuts + 1] = CityGrid.Plaza.half
    end
    cuts[#cuts + 1] = RUN_MAX
    table.sort(cuts)
    return cuts
end

--[[ Vanos pintables de una calle (fuera de cruces y de la plaza). ]]
local function spansFor(line)
    local cuts = cutsFor(line)
    local inPlaza = math.abs(line) <= CityGrid.Plaza.half
    local spans = {}
    for i = 1, #cuts - 1 do
        local a, b = cuts[i], cuts[i + 1]
        local insidePlaza = inPlaza and a >= -CityGrid.Plaza.half - 0.01 and b <= CityGrid.Plaza.half + 0.01
        if not insidePlaza then
            local sa = a + marginAt(a)
            local sb = b - marginAt(b)
            if sb - sa > 10 then
                spans[#spans + 1] = { from = sa, to = sb }
            end
        end
    end
    return spans
end

--[[ Plan completo de carreteras.

     slabs         tramos de asfalto (axis, line, from, to, width)
     spans         vanos pintables por calle (axis, line, from, to)
     intersections cruces de dos avenidas (para pasos de peatones)
     plazaMouths   bocas de avenida que llegan a la plaza
]]
function CityLayout.RoadPlan()
    local plan = { slabs = {}, spans = {}, intersections = {}, plazaMouths = {} }

    -- Calles verticales (corren en Z) en x = line. Van de lado a lado (salvo el
    -- hueco de la plaza) porque son las que TAPAN las intersecciones; las
    -- horizontales se recortan a su borde para no solaparse con ellas.
    for _, line in ipairs(CityGrid.LINES) do
        local w = CityGrid.WidthOf(line)
        if line == 0 then
            plan.slabs[#plan.slabs + 1] = { axis = "z", line = line, from = RUN_MIN, to = -CityGrid.Plaza.half, width = w }
            plan.slabs[#plan.slabs + 1] = { axis = "z", line = line, from = CityGrid.Plaza.half, to = RUN_MAX, width = w }
        else
            plan.slabs[#plan.slabs + 1] = { axis = "z", line = line, from = RUN_MIN, to = RUN_MAX, width = w }
        end
        for _, s in ipairs(spansFor(line)) do
            plan.spans[#plan.spans + 1] = { axis = "z", line = line, from = s.from, to = s.to }
        end
    end

    -- Calles horizontales (corren en X) en z = line: recortadas a las verticales.
    for _, line in ipairs(CityGrid.LINES) do
        local w = CityGrid.WidthOf(line)
        local inPlaza = math.abs(line) <= CityGrid.Plaza.half
        local cuts = { RUN_MIN }
        for _, c in ipairs(CityGrid.LINES) do
            cuts[#cuts + 1] = c
        end
        if inPlaza then
            cuts[#cuts + 1] = -CityGrid.Plaza.half
            cuts[#cuts + 1] = CityGrid.Plaza.half
        end
        cuts[#cuts + 1] = RUN_MAX
        table.sort(cuts)
        for i = 1, #cuts - 1 do
            local a, b = cuts[i], cuts[i + 1]
            local insidePlaza = inPlaza and a >= -CityGrid.Plaza.half - 0.01 and b <= CityGrid.Plaza.half + 0.01
            if not insidePlaza then
                local sa = a + edgeInset(a)
                local sb = b - edgeInset(b)
                if sb - sa > 1 then
                    plan.slabs[#plan.slabs + 1] = { axis = "x", line = line, from = sa, to = sb, width = w }
                end
            end
        end
        for _, s in ipairs(spansFor(line)) do
            plan.spans[#plan.spans + 1] = { axis = "x", line = line, from = s.from, to = s.to }
        end
    end

    -- Circunvalacion. Las piezas verticales se acortan para no solaparse con las
    -- horizontales en las cuatro esquinas.
    local ringW = CityGrid.Road.avenueWidth
    local R = CityGrid.RING
    local rInner = R - ringW * 0.5
    local rOuter = R + ringW * 0.5
    plan.slabs[#plan.slabs + 1] = { axis = "x", line = R, from = -rOuter, to = rOuter, width = ringW, ring = true }
    plan.slabs[#plan.slabs + 1] = { axis = "x", line = -R, from = -rOuter, to = rOuter, width = ringW, ring = true }
    plan.slabs[#plan.slabs + 1] = { axis = "z", line = R, from = -rInner, to = rInner, width = ringW, ring = true }
    plan.slabs[#plan.slabs + 1] = { axis = "z", line = -R, from = -rInner, to = rInner, width = ringW, ring = true }

    -- Cruces de dos avenidas (sin contar el de la plaza).
    for _, xl in ipairs(CityGrid.LINES) do
        for _, zl in ipairs(CityGrid.LINES) do
            if CityGrid.IsAvenue(xl) and CityGrid.IsAvenue(zl) then
                local inPlaza = math.abs(xl) <= CityGrid.Plaza.half and math.abs(zl) <= CityGrid.Plaza.half
                if not inPlaza then
                    plan.intersections[#plan.intersections + 1] = { x = xl, z = zl }
                end
            end
        end
    end

    -- Bocas de avenida en la plaza (para pasos de peatones en los 4 accesos).
    for _, axis in ipairs({ "z", "x" }) do
        for _, s in ipairs({ -1, 1 }) do
            if axis == "z" then
                plan.plazaMouths[#plan.plazaMouths + 1] = { x = 0, z = s * CityGrid.Plaza.half, axis = "z" }
            else
                plan.plazaMouths[#plan.plazaMouths + 1] = { x = s * CityGrid.Plaza.half, z = 0, axis = "x" }
            end
        end
    end

    return plan
end

-- Solares -----------------------------------------------------------------------

local function subdivide(r, cols, rows, gap)
    local lots = {}
    local cw = r.w / cols
    local ch = r.d / rows
    for i = 0, cols - 1 do
        for j = 0, rows - 1 do
            local x1 = r.x1 + i * cw + gap
            local x2 = r.x1 + (i + 1) * cw - gap
            local z1 = r.z1 + j * ch + gap
            local z2 = r.z1 + (j + 1) * ch - gap
            if x2 - x1 > 24 and z2 - z1 > 24 then
                lots[#lots + 1] = {
                    x1 = x1, x2 = x2, z1 = z1, z2 = z2,
                    cx = (x1 + x2) * 0.5, cz = (z1 + z2) * 0.5,
                    w = x2 - x1, d = z2 - z1,
                }
            end
        end
    end
    return lots
end

local function facingOf(lot, r)
    local dx = lot.cx - r.cx
    local dz = lot.cz - r.cz
    if math.abs(dx) >= math.abs(dz) then
        return dx >= 0 and "east" or "west"
    end
    return dz >= 0 and "north" or "south"
end

--[[ Genera bloques, solares genericos y zonas especiales. ]]

function CityLayout.Generate()
    buildSets()
    local reserved = CityLayout.ReservedRects()

    local blocks, lots, parks, parkings = {}, {}, {}, {}

    for _, b in ipairs(CityGrid.Blocks()) do
        if not b.plaza then
            local k = keyOf(b.cx, b.cz)
            local districtId = CityLayout.DistrictOf(b.cx, b.cz)
            local profile = CityLayout.ProfileOf(districtId)
            if landmarkSet[k] then
                -- Rascacielos emblematico: una sola torre que ocupa la manzana.
                districtId = "centro"
                profile = CityLayout.ProfileOf("landmark")
            end
            local entry = {
                x1 = b.x1, x2 = b.x2, z1 = b.z1, z2 = b.z2, cx = b.cx, cz = b.cz,
                district = districtId, profile = profile, style = CityLayout.StyleOf(districtId),
            }
            blocks[#blocks + 1] = entry

            local r = CityGrid.Buildable(b)
            entry.buildable = r

            if parkSet[k] then
                entry.special = "park"
                parks[#parks + 1] = entry
            elseif parkingSet[k] then
                entry.special = "parking"
                parkings[#parkings + 1] = entry
            else
                local cols = profile.lots[1]
                local rows = profile.lots[2]
                for _, lot in ipairs(subdivide(r, cols, rows, profile.gap or 4)) do
                    local blocked = false
                    for _, rect in ipairs(reserved) do
                        if intersects(lot, rect) then
                            blocked = true
                            break
                        end
                    end
                    if not blocked then
                        lot.district = districtId
                        lot.profile = profile
                        lot.style = entry.style
                        lot.facing = facingOf(lot, r)
                        lot.block = entry
                        lot.landmark = landmarkSet[k] == true
                        lots[#lots + 1] = lot
                    end
                end
            end
        end
    end

    return {
        blocks = blocks,
        lots = lots,
        parks = parks,
        parkings = parkings,
        reserved = reserved,
        roads = CityLayout.RoadPlan(),
    }
end

return CityLayout
