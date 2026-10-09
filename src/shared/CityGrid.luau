--[[
    CityGrid
    Ruta en Roblox Studio: ReplicatedStorage > Shared > CityGrid
    Tipo: ModuleScript

    RETICULA URBANA COMPARTIDA. Es la unica fuente de verdad de la geometria de
    la ciudad (no hay que tocar numeros por varios scripts).

    Diseno: UNA sola ciudad continua de 2000 x 2000 studs. Nada de islas ni
    plataformas separadas: todo el suelo es continuo y las calles conectan la
    plaza central con los 8 barrios sin cortes.

        * Calles (lineas) cada 260 studs en los dos ejes: -780..780.
        * Avenidas (mas anchas) en x/z = 0 y +-520; el resto son calles.
        * Plaza central de 520 x 520 studs alrededor del origen (ocupa los 4
          bloques centrales y corta las avenidas que entran en ella).
        * Cinturon verde exterior + carretera de circunvalacion en +-890.
        * 8 barrios en los cruces (+-520, 0), (0, +-520) y (+-520, +-520).

    Niveles verticales (evitan z-fighting y huecos):
        base 0.5  -> relleno bajo todo (por encima del Baseplate por defecto)
        road 0.62 -> cara del asfalto
        mark 0.72 -> pintura de la carretera
        walk 1.00 -> aceras, solares, plaza, parques (bordillo de 0.38)

    Puro dato + utilidades. No instancia nada.
]]

local CityGrid = {}

CityGrid.MAP_SIZE = 2000
CityGrid.HALF = CityGrid.MAP_SIZE * 0.5

-- Lineas de calle (centro de cada calle) en ambos ejes.
CityGrid.PITCH = 260
CityGrid.LINES = { -780, -520, -260, 0, 260, 520, 780 }

-- Carretera de circunvalacion (cinturon exterior).
CityGrid.RING = 890

-- Anchuras y niveles.
CityGrid.Road = {
    avenueWidth = 52,
    streetWidth = 38,
    sidewalk = 15,
}

CityGrid.Levels = {
    base = 0.5,
    road = 0.62,
    mark = 0.72,
    walk = 1.0,
    curbRise = 0.06,   -- resalte extra del bordillo sobre la acera
}

-- Plaza central. Medio lado 234: cubre exactamente los 4 bloques centrales y
-- deja libre la calzada perimetral de las calles de ±260.
CityGrid.Plaza = {
    half = 234,          -- medio lado (ocupa los 4 bloques centrales)
    smokingRadius = 150, -- radio de la zona de fumadores
    spawn = Vector3.new(0, 0, 196),
}

--[[ True si la linea es una avenida (mas ancha). ]]
function CityGrid.IsAvenue(line)
    return line == 0 or math.abs(line) == 520
end

function CityGrid.WidthOf(line)
    if CityGrid.IsAvenue(line) then
        return CityGrid.Road.avenueWidth
    end
    return CityGrid.Road.streetWidth
end

function CityGrid.HalfRoad(line)
    return CityGrid.WidthOf(line) * 0.5
end

--[[ Distancia desde el centro de la calle hasta el borde interior de la acera
     (es decir, donde empieza la zona edificable del bloque). ]]
function CityGrid.BuildableInset(line)
    return CityGrid.HalfRoad(line) + CityGrid.Road.sidewalk
end

--[[ Bloque (region entre dos lineas consecutivas) que contiene el punto dado.
     Devuelve { x1, x2, z1, z2, cx, cz }. ]]
function CityGrid.BlockAt(px, pz)
    local lines = CityGrid.LINES
    local function bounds(v)
        for i = 1, #lines - 1 do
            if v >= lines[i] and v <= lines[i + 1] then
                return lines[i], lines[i + 1]
            end
        end
        if v < lines[1] then
            return lines[1], lines[2]
        end
        return lines[#lines - 1], lines[#lines]
    end
    local x1, x2 = bounds(px)
    local z1, z2 = bounds(pz)
    return { x1 = x1, x2 = x2, z1 = z1, z2 = z2, cx = (x1 + x2) * 0.5, cz = (z1 + z2) * 0.5 }
end

--[[ Todos los bloques de la reticula. ]]
function CityGrid.Blocks()
    local lines = CityGrid.LINES
    local list = {}
    for i = 1, #lines - 1 do
        for j = 1, #lines - 1 do
            local b = { x1 = lines[i], x2 = lines[i + 1], z1 = lines[j], z2 = lines[j + 1] }
            b.cx = (b.x1 + b.x2) * 0.5
            b.cz = (b.z1 + b.z2) * 0.5
            b.plaza = math.abs(b.cx) <= CityGrid.Plaza.half and math.abs(b.cz) <= CityGrid.Plaza.half
            list[#list + 1] = b
        end
    end
    return list
end

--[[ Zona edificable de un bloque (ya sin calzada ni aceras):
     { x1, x2, z1, z2, cx, cz }. ]]
function CityGrid.Buildable(b)
    local iW = CityGrid.BuildableInset(b.x1)
    local iE = CityGrid.BuildableInset(b.x2)
    local iS = CityGrid.BuildableInset(b.z1)
    local iN = CityGrid.BuildableInset(b.z2)
    local r = { x1 = b.x1 + iW, x2 = b.x2 - iE, z1 = b.z1 + iS, z2 = b.z2 - iN }
    r.cx = (r.x1 + r.x2) * 0.5
    r.cz = (r.z1 + r.z2) * 0.5
    r.w = r.x2 - r.x1
    r.d = r.z2 - r.z1
    return r
end

--[[ Aceras del bloque: 4 bandas sin solaparse entre si.
     Devuelve una lista de { x1, z1, x2, z2 } (rectangulos). ]]
function CityGrid.SidewalkBands(b)
    local hW, hE = CityGrid.HalfRoad(b.x1), CityGrid.HalfRoad(b.x2)
    local hS, hN = CityGrid.HalfRoad(b.z1), CityGrid.HalfRoad(b.z2)
    local s = CityGrid.Road.sidewalk
    local ix1, ix2 = b.x1 + hW, b.x2 - hE
    local iz1, iz2 = b.z1 + hS, b.z2 - hN
    return {
        -- sur (cubre las esquinas)
        { ix1, iz1, ix2, iz1 + s },
        -- norte
        { ix1, iz2 - s, ix2, iz2 },
        -- oeste
        { ix1, iz1 + s, ix1 + s, iz2 - s },
        -- este
        { ix2 - s, iz1 + s, ix2, iz2 - s },
    }
end

--[[ Coloca una casa de tamano w (ancho local X) x d (fondo local Z) apoyada en
     el borde `side` ("north"/"south"/"east"/"west") del bloque (cx, cz), con la
     fachada mirando a la calle de ese borde. Devuelve (position, facingGrados). ]]
function CityGrid.LotOnEdge(cx, cz, side, w, d)
    local r = CityGrid.Buildable(CityGrid.BlockAt(cx, cz))
    if side == "south" then
        return Vector3.new(r.cx, 0, r.z1 + d * 0.5), 180
    elseif side == "north" then
        return Vector3.new(r.cx, 0, r.z2 - d * 0.5), 0
    elseif side == "west" then
        return Vector3.new(r.x1 + d * 0.5, 0, r.cz), -90
    end
    return Vector3.new(r.x2 - d * 0.5, 0, r.cz), 90
end

--[[ Rectangulo (AABB + margen) que ocupa una casa ya colocada. Sirve para que
     los edificios genericos no se le monten encima. ]]
function CityGrid.HouseRect(house, margin)
    margin = margin or 10
    local rot = math.rad(house.facing or 0)
    local c, s = math.cos(rot), math.sin(rot)
    local hx = math.abs(c) * (house.w * 0.5) + math.abs(s) * (house.d * 0.5)
    local hz = math.abs(s) * (house.w * 0.5) + math.abs(c) * (house.d * 0.5)
    return {
        x1 = house.position.X - hx - margin,
        x2 = house.position.X + hx + margin,
        z1 = house.position.Z - hz - margin,
        z2 = house.position.Z + hz + margin,
    }
end

return CityGrid
