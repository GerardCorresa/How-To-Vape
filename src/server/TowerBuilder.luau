--[[
    TowerBuilder
    Ruta en Roblox Studio: ServerScriptService > TowerBuilder
    Tipo: ModuleScript

    RASCACIELOS. Construye las torres de la ciudad (centro, zona financiera y
    distrito de neon) sobre un solar completo, con fachada de cristal/acero,
    cuerpo escalonado, terrazas, podio comercial y coronacion.

    Es un edificio DECORATIVO: no tiene interior (nadie entra), asi que la
    fachada se resuelve con pocas piezas grandes bien elegidas en vez de miles
    de ventanas sueltas:

        * nucleo macizo (una sola pieza, la que da colision),
        * paneles de cristal por tramos de planta en las 4 caras,
        * forjados/cornisas finos entre tramos,
        * columnas de esquina y montantes verticales,
        * 1-3 cuerpos escalonados (setbacks) con terraza y pretil,
        * coronacion variable: aguja, antena, corona de neon o escalonada,
        * podio de 2-3 plantas con vestibulo acristalado y marquesina.

    Requiere: BuildKit, CityKit, CityGrid.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGrid = require(Shared:WaitForChild("CityGrid"))

local BuildKit = require(script.Parent:WaitForChild("BuildKit"))
local CityKit = require(script.Parent:WaitForChild("CityKit"))

local TowerBuilder = {}

local M = Enum.Material
local C = Color3.fromRGB
local WALK = CityGrid.Levels.walk

local YAW = { north = 0, east = 90, south = 180, west = -90 }

-- Paleta de fachadas de cristal (se mezcla con el color del distrito) --------
local GLASS = { C(104, 152, 190), C(74, 108, 152), C(56, 78, 108), C(126, 176, 204), C(86, 120, 148) }
local STEEL = C(152, 156, 166)
local TRIM = C(214, 216, 220)
local CONCRETE = C(178, 180, 186)
local LIT = C(255, 224, 162)

-- Estilo por defecto por si el distrito no aporta uno (nunca deberia).
local FALLBACK_STYLE = {
    wall = { C(196, 192, 184) },
    roof = { C(96, 98, 104) },
    accent = C(120, 200, 255),
    material = M.Concrete,
}

local function part(model, name, size, color, material, cf, collide, castShadow)
    return BuildKit.Part({
        name = name, size = size, color = color, material = material, cframe = cf,
        canCollide = collide == true,
        canQuery = collide == true,
        castShadow = castShadow == true,
        parent = model,
    })
end

local function shade(color, f)
    return CityKit.Shade(color, f)
end

--[[ Muro cortina de un cuerpo de la torre: nucleo + cristal por tramos +
     forjados + columnas de esquina + montantes. Devuelve el numero de piezas. ]]
local function curtain(model, cf, w, d, y0, h, o)
    local segH = o.segH or 52
    local segs = math.max(1, math.floor(h / segH + 0.5))
    local step = h / segs
    local glassH = math.max(6, step - 4.4)

    -- Nucleo estructural: una sola pieza, la unica con colision.
    part(model, "Core", Vector3.new(w, h, d), o.core, o.coreMat, cf * CFrame.new(0, y0 + h * 0.5, 0), true, true)

    for i = 0, segs - 1 do
        local yc = y0 + step * (i + 0.5)
        for _, face in ipairs({
            { Vector3.new(0, yc, d * 0.5), Vector3.new(w - 1.6, glassH, 0.4) },
            { Vector3.new(0, yc, -d * 0.5), Vector3.new(w - 1.6, glassH, 0.4) },
            { Vector3.new(w * 0.5, yc, 0), Vector3.new(0.4, glassH, d - 1.6) },
            { Vector3.new(-w * 0.5, yc, 0), Vector3.new(0.4, glassH, d - 1.6) },
        }) do
            -- Cada cara decide por separado si su tramo esta encendido: asi la
            -- fachada tiene luces salteadas y no tiras completas.
            local lit = o.litChance > 0 and o.rand() < o.litChance
            part(model, "Curtain", face[2], lit and LIT or o.glass, lit and M.Neon or M.Glass,
                cf * CFrame.new(face[1]), false, false)
        end
    end

    -- Forjados: un anillo fino cada tramo (una pieza por nivel de tramo).
    for i = 0, segs do
        local yb = y0 + step * i
        local s = (i == segs) and (w + 1.4) or (w + 0.5)
        local sd = (i == segs) and (d + 1.4) or (d + 0.5)
        local th = (i == segs) and 2.6 or 1.5
        part(model, "Spandrel", Vector3.new(s, th, sd), o.spandrel, M.Concrete,
            cf * CFrame.new(0, yb, 0), false, false)
    end

    -- Columnas de esquina (4 piezas, toda la altura).
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            part(model, "CornerColumn", Vector3.new(0.9, h, 0.9), o.trim, M.Metal,
                cf * CFrame.new(sx * (w * 0.5 - 0.2), y0 + h * 0.5, sz * (d * 0.5 - 0.2)), false, false)
        end
    end

    -- Montantes verticales (detalle barato: una pieza por montante).
    if o.mullions > 0 then
        for k = 1, o.mullions do
            local x = -w * 0.5 + (w / (o.mullions + 1)) * k
            for _, sz in ipairs({ -1, 1 }) do
                part(model, "Mullion", Vector3.new(0.4, h, 0.5), o.trim, M.Metal,
                    cf * CFrame.new(x, y0 + h * 0.5, sz * (d * 0.5)), false, false)
            end
        end
    end
end

-- Coronaciones -----------------------------------------------------------------

local function crownSpire(model, cf, w, d, topY)
    local steps = { { 0.72, 16 }, { 0.48, 14 }, { 0.26, 12 } }
    local y = topY
    for _, s in ipairs(steps) do
        part(model, "Spire", Vector3.new(w * s[1], s[2], d * s[1]), TRIM, M.Metal,
            cf * CFrame.new(0, y + s[2] * 0.5, 0), false, false)
        y += s[2]
    end
    part(model, "Mast", Vector3.new(0.7, 26, 0.7), STEEL, M.Metal, cf * CFrame.new(0, y + 13, 0), false, false)
    if CityKit.AllowLight() then
        local beacon = part(model, "Beacon", Vector3.new(1.6, 1.6, 1.6), C(255, 70, 70), M.Neon,
            cf * CFrame.new(0, y + 26, 0), false, false)
        local light = Instance.new("PointLight")
        light.Color = C(255, 70, 70)
        light.Brightness = 2
        light.Range = 40
        light.Shadows = false
        light.Parent = beacon
    end
end

local function crownAntenna(model, cf, w, d, topY, rand)
    part(model, "ParapetRing", Vector3.new(w + 1.0, 3.0, d + 1.0), shade(TRIM, -0.4), M.Concrete,
        cf * CFrame.new(0, topY + 1.5, 0), false, false)
    local mastH = CityKit.Int(rand, 34, 78)
    part(model, "Mast", Vector3.new(1.1, mastH, 1.1), STEEL, M.Metal,
        cf * CFrame.new(0, topY + mastH * 0.5, 0), false, false)
    for _, h in ipairs({ 0.45, 0.75 }) do
        part(model, "MastArm", Vector3.new(w * 0.7, 0.4, 0.4), STEEL, M.Metal,
            cf * CFrame.new(0, topY + mastH * h, 0), false, false)
    end
    if CityKit.AllowLight() then
        local beacon = part(model, "Beacon", Vector3.new(1.8, 1.8, 1.8), C(255, 70, 70), M.Neon,
            cf * CFrame.new(0, topY + mastH, 0), false, false)
        local light = Instance.new("PointLight")
        light.Color = C(255, 70, 70)
        light.Brightness = 2
        light.Range = 44
        light.Shadows = false
        light.Parent = beacon
    end
end

local function crownNeon(model, cf, w, d, topY, accent)
    part(model, "CrownBand", Vector3.new(w + 1.6, 3.2, d + 1.6), accent, M.Neon,
        cf * CFrame.new(0, topY + 1.8, 0), false, false)
    part(model, "CrownBox", Vector3.new(w * 0.5, 9, d * 0.5), shade(accent, -0.35), M.Metal,
        cf * CFrame.new(0, topY + 7.5, 0), false, false)
    part(model, "CrownTop", Vector3.new(w * 0.28, 5, d * 0.28), accent, M.Neon,
        cf * CFrame.new(0, topY + 14.5, 0), false, false)
end

local function crownStepped(model, cf, w, d, topY, rand)
    local y = topY
    for i = 1, 3 do
        local f = 1 - i * 0.24
        local hh = CityKit.Int(rand, 7, 12)
        part(model, "Step", Vector3.new(w * f, hh, d * f), CONCRETE, M.Concrete,
            cf * CFrame.new(0, y + hh * 0.5, 0), false, false)
        part(model, "StepLedge", Vector3.new(w * f + 0.9, 1.2, d * f + 0.9), shade(TRIM, -0.3), M.Concrete,
            cf * CFrame.new(0, y + hh, 0), false, false)
        y += hh + 1.2
    end
    part(model, "StepMast", Vector3.new(0.6, 18, 0.6), STEEL, M.Metal, cf * CFrame.new(0, y + 9, 0), false, false)
end

local function rooftop(model, cf, w, d, topY, rand)
    part(model, "ParapetRing", Vector3.new(w + 1.2, 2.8, d + 1.2), shade(TRIM, -0.45), M.Concrete,
        cf * CFrame.new(0, topY + 1.4, 0), false, false)
    for _ = 1, CityKit.Int(rand, 2, 4) do
        part(model, "RoofAC", Vector3.new(CityKit.Float(rand, 3.4, 5.4), 2.4, 3.0), C(150, 152, 156), M.Metal,
            cf * CFrame.new(CityKit.Float(rand, -w * 0.3, w * 0.3), topY + 3.4,
                CityKit.Float(rand, -d * 0.3, d * 0.3)), true, true)
    end
    if rand() < 0.6 then
        part(model, "WaterTank", Vector3.new(5.4, 6.0, 5.4), C(146, 140, 126), M.CorrugatedMetal,
            cf * CFrame.new(-w * 0.24, topY + 4.6, d * 0.2), true, true)
    end
    if rand() < 0.4 then
        part(model, "StairHead", Vector3.new(w * 0.26, 6, d * 0.26), shade(TRIM, -0.3), M.Concrete,
            cf * CFrame.new(w * 0.24, topY + 4.4, -d * 0.22), false, false)
    end
end

-- Podio comercial --------------------------------------------------------------

local function podium(model, cf, w, d, h, o)
    local pw, pd = w + 3.4, d + 3.4
    part(model, "Podium", Vector3.new(pw, h, pd), o.podiumColor, o.podiumMat,
        cf * CFrame.new(0, h * 0.5, 0), true, true)
    -- Vestibulo acristalado en las 4 caras (escaparate urbano).
    for _, face in ipairs({
        { Vector3.new(0, h * 0.55, pd * 0.5), Vector3.new(pw - 4, h - 4.4, 0.4) },
        { Vector3.new(0, h * 0.55, -pd * 0.5), Vector3.new(pw - 4, h - 4.4, 0.4) },
        { Vector3.new(pw * 0.5, h * 0.55, 0), Vector3.new(0.4, h - 4.4, pd - 4) },
        { Vector3.new(-pw * 0.5, h * 0.55, 0), Vector3.new(0.4, h - 4.4, pd - 4) },
    }) do
        local lit = o.litChance > 0 and o.rand() < o.litChance * 0.7
        part(model, "PodiumGlass", face[2], lit and LIT or C(150, 190, 214),
            lit and M.Neon or M.Glass, cf * CFrame.new(face[1]), false, false)
    end
    -- Zocalo y cornisa del podio.
    part(model, "PodiumBase", Vector3.new(pw + 0.8, 1.8, pd + 0.8), shade(o.podiumColor, -0.3), M.Concrete,
        cf * CFrame.new(0, 0.9, 0), false, false)
    part(model, "PodiumLedge", Vector3.new(pw + 1.6, 1.6, pd + 1.6), shade(TRIM, -0.25), M.Concrete,
        cf * CFrame.new(0, h + 0.4, 0), false, false)
    -- Marquesina de entrada, siempre mirando a la calle (local +Z).
    part(model, "Canopy", Vector3.new(pw * 0.44, 0.7, 7), o.trim, M.Metal,
        cf * CFrame.new(0, h - 3.6, pd * 0.5 + 3.2), false, false)
    for _, sx in ipairs({ -1, 1 }) do
        part(model, "CanopyRod", Vector3.new(0.35, h - 3.6, 0.35), o.trim, M.Metal,
            cf * CFrame.new(sx * pw * 0.2, (h - 3.6) * 0.5, pd * 0.5 + 6.4), false, false)
    end
    if o.neon then
        part(model, "NeonBand", Vector3.new(pw + 0.6, 1.1, pd + 0.6), o.accent, M.Neon,
            cf * CFrame.new(0, h - 0.4, 0), false, false)
    end
    if CityKit.AllowLight() then
        local lamp = part(model, "LobbyLight", Vector3.new(1.2, 0.6, 1.2), C(255, 236, 200), M.Neon,
            cf * CFrame.new(0, h - 4.4, pd * 0.5 + 3.0), false, false)
        local light = Instance.new("PointLight")
        light.Color = C(255, 232, 196)
        light.Brightness = 2
        light.Range = 34
        light.Shadows = false
        light.Parent = lamp
    end
end

-- Constructor principal ---------------------------------------------------------

function TowerBuilder.Build(lot, parent)
    local profile = lot.profile
    local style = lot.style or FALLBACK_STYLE
    local rand = CityKit.Rng(math.floor(lot.cx) * 73856093 + math.floor(lot.cz) * 19349663 + 977)

    local accent = style.accent or C(120, 200, 255)
    local neon = profile.kind == "neon"

    -- Huella: los rascacielos emblematicos se retranquean para dejar una plaza.
    local inset = (profile.landmark and 0.30) or 0.05
    local w = math.max(24, lot.w * (1 - inset) - 1)
    local d = math.max(24, lot.d * (1 - inset) - 1)
    -- Variedad de siluetas: torres esbeltas en uno de los dos ejes.
    if rand() < 0.34 then
        if rand() < 0.5 then
            d = math.max(22, d * 0.66)
        else
            w = math.max(22, w * 0.66)
        end
    end

    local floors = CityKit.Int(rand, profile.floors[1], profile.floors[2])
    local floorH = neon and 7.8 or 7.2
    local podiumH = neon and 22 or 19
    local bodyH = math.max(3, floors - 3) * floorH
    local totalH = podiumH + bodyH

    local glass = CityKit.Pick(rand, GLASS)
    glass = CityKit.Shade(glass, neon and -0.25 or 0)
    local coreMat = neon and M.SmoothPlastic or M.Concrete
    local core = neon and C(26, 22, 44) or CityKit.Shade(glass, -0.62)

    local model = CityKit.Model(("Tower_%s_%d"):format(profile.kind, floors), parent)
    local cf = CFrame.new(lot.cx, WALK, lot.cz) * CFrame.Angles(0, math.rad(YAW[lot.facing] or 0), 0)

    local o = {
        rand = rand,
        glass = glass,
        core = core,
        coreMat = coreMat,
        spandrel = neon and CityKit.Shade(accent, -0.55) or shade(TRIM, -0.3),
        trim = neon and accent or STEEL,
        accent = accent,
        litChance = profile.lit or 0.6,
        mullions = CityKit.Int(rand, 0, 3),
        neon = neon,
        podiumColor = neon and C(30, 26, 50) or shade(CONCRETE, -0.1),
        podiumMat = neon and M.SmoothPlastic or M.Concrete,
    }

    -- 1) Podio
    podium(model, cf, w, d, podiumH, o)

    -- 2) Cuerpos (1-3) con retranqueos y terrazas
    local nStacks = 1
    if rand() < 0.45 then
        nStacks = 2
    end
    if profile.landmark and rand() < 0.5 then
        nStacks = 3
    end
    if bodyH < 90 then
        nStacks = 1
    end

    local y = podiumH
    local cw, cd = w, d
    local remains = bodyH
    for i = 1, nStacks do
        local sh
        if i == nStacks then
            sh = remains
        else
            sh = math.floor(remains * CityKit.Float(rand, 0.45, 0.68))
        end
        sh = math.max(24, sh)
        o.segH = CityKit.Float(rand, 44, 66)
        curtain(model, cf, cw, cd, y, sh, o)
        y += sh
        remains -= sh

        if i < nStacks then
            -- Terraza: forjado que sobresale + pretil.
            local nw = math.max(20, cw * CityKit.Float(rand, 0.72, 0.86))
            local nd = math.max(20, cd * CityKit.Float(rand, 0.72, 0.86))
            part(model, "TerraceSlab", Vector3.new(cw + 6, 1.4, cd + 6), shade(TRIM, -0.35), M.Concrete,
                cf * CFrame.new(0, y + 0.7, 0), false, false)
            for _, side in ipairs({
                { Vector3.new(0, y + 2.6, (cd + 6) * 0.5), Vector3.new(cw + 6, 2.4, 0.6) },
                { Vector3.new(0, y + 2.6, -(cd + 6) * 0.5), Vector3.new(cw + 6, 2.4, 0.6) },
                { Vector3.new((cw + 6) * 0.5, y + 2.6, 0), Vector3.new(0.6, 2.4, cd + 6) },
                { Vector3.new(-(cw + 6) * 0.5, y + 2.6, 0), Vector3.new(0.6, 2.4, cd + 6) },
            }) do
                part(model, "TerraceRail", side[2], STEEL, M.Metal, cf * CFrame.new(side[1]), false, false)
            end
            cw, cd = nw, nd
        end
        if remains <= 24 then
            break
        end
    end

    local topY = y

    -- 3) Coronacion
    local crown = CityKit.Pick(rand, neon and { "crown", "antenna", "stepped" }
        or { "spire", "antenna", "stepped", "antenna" })
    if crown == "spire" then
        crownSpire(model, cf, cw, cd, topY)
    elseif crown == "antenna" then
        crownAntenna(model, cf, cw, cd, topY, rand)
    elseif crown == "crown" then
        crownNeon(model, cf, cw, cd, topY, accent)
    else
        crownStepped(model, cf, cw, cd, topY, rand)
    end

    -- 4) Azotea funcional (solo si la coronacion deja sitio)
    if crown == "spire" or crown == "antenna" then
        rooftop(model, cf, cw * 0.5, cd * 0.5, topY, rand)
    end

    -- 5) Detalle de fachada a pie de calle: buhardas / tuberias / montantes
    if rand() < 0.6 then
        for i = 1, CityKit.Int(rand, 2, 4) do
            -- Montantes verticales cada cierto tramo en las caras largas.
            local t = i / 5
            part(model, "Pier", Vector3.new(1.1, podiumH * 0.7, 1.1), shade(o.podiumColor, -0.2), M.Concrete,
                cf * CFrame.new(-w * 0.5 + w * t, podiumH + 4, d * 0.5 + 1.4), false, false)
        end
    end

    model:SetAttribute("Kind", profile.kind)
    model:SetAttribute("Floors", floors)
    model:SetAttribute("Height", math.floor(totalH))
    return model
end

return TowerBuilder
