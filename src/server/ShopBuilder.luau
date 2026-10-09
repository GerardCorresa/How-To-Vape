--[[
    ShopBuilder
    Ruta en Roblox Studio: ServerScriptService > ShopBuilder
    Tipo: ModuleScript

    Construye un LOCAL COMERCIAL completo y transitable: escaparate, rotulo,
    toldo y un INTERIOR basico amueblado segun `layout` (ver ShopConfig).

    A diferencia de los edificios genericos (macizos), estos locales son huecos
    y se puede entrar por la puerta, que queda mirando a la acera.

    Requiere: BuildKit, CityKit, CityGrid, ShopConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGrid = require(Shared:WaitForChild("CityGrid"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local BuildKit = require(script.Parent:WaitForChild("BuildKit"))
local CityKit = require(script.Parent:WaitForChild("CityKit"))

local ShopBuilder = {}

local M = Enum.Material
local C = Color3.fromRGB
local WALK = CityGrid.Levels.walk

local YAW = { north = 0, east = 90, south = 180, west = -90 }
local T = 0.8          -- grosor de pared
local H = 7.5          -- altura interior
local DOOR = 8         -- ancho del hueco de entrada

local function p(model, name, size, color, material, cf, collide)
    return BuildKit.Part({
        name = name, size = size, color = color, material = material, cframe = cf,
        canCollide = collide == true, castShadow = false, parent = model,
    })
end

-- Mobiliario interior ----------------------------------------------------------

local function productStrip(model, cfPos, width, color)
    return p(model, "Products", Vector3.new(width, 1.4, 1.0), color, M.SmoothPlastic, cfPos, false)
end

local function interiorCounter(model, L, w, d, def)
    p(model, "Counter", Vector3.new(w * 0.62, 1.3, 2.0), CityKit.Shade(def.main, -0.45), M.Wood,
        L(nil, 0, 0.65, -d * 0.16), true)
    p(model, "CounterTop", Vector3.new(w * 0.66, 0.24, 2.3), def.main, M.SmoothPlastic,
        L(nil, 0, 1.42, -d * 0.16), false)
    -- Barra/estanteria trasera
    p(model, "BackBar", Vector3.new(w * 0.62, 3.0, 0.8), CityKit.Shade(def.sub, 0.35), M.Wood,
        L(nil, 0, 1.5, -d * 0.5 + 1.4), false)
    productStrip(model, L(nil, 0, 2.4, -d * 0.5 + 1.9), w * 0.5, def.main)
    -- Mesas
    for _, sx in ipairs({ -w * 0.22, w * 0.22 }) do
        p(model, "TableTop", Vector3.new(4.0, 0.3, 4.0), CityKit.Shade(def.main, 0.28), M.Wood,
            L(nil, sx, 1.5, d * 0.24), true)
        p(model, "TableLeg", Vector3.new(0.4, 1.5, 0.4), def.sub, M.Metal,
            L(nil, sx, 0.75, d * 0.24), false)
        for _, o in ipairs({ -1.9, 1.9 }) do
            p(model, "Stool", Vector3.new(1.2, 1.2, 1.2), def.main, M.SmoothPlastic,
                L(nil, sx + o, 0.6, d * 0.24 + 2.6), false)
        end
    end
end

local function interiorAisles(model, L, w, d, def)
    local rows = 3
    for i = 1, rows do
        local z = -d * 0.22 + (i - 1) * (d * 0.26)
        for _, sx in ipairs({ -w * 0.19, w * 0.19 }) do
            p(model, "Shelf", Vector3.new(w * 0.3, 4.2, 1.4), CityKit.Shade(def.sub, 0.4), M.Metal,
                L(nil, sx, 2.1, z), true)
            productStrip(model, L(nil, sx, 4.6, z), w * 0.26, def.main)
            productStrip(model, L(nil, sx, 2.6, z), w * 0.26, CityKit.Shade(def.main, 0.3))
        end
    end
    p(model, "Checkout", Vector3.new(6.0, 1.2, 2.2), def.main, M.SmoothPlastic, L(nil, -w * 0.22, 0.6, d * 0.38), true)
    p(model, "Till", Vector3.new(1.6, 1.0, 1.4), def.sub, M.Metal, L(nil, -w * 0.22, 1.7, d * 0.38), false)
end

local function interiorRacks(model, L, w, d, def)
    for i = 1, 4 do
        local x = -w * 0.3 + (i - 1) * (w * 0.2)
        local rack = p(model, "Rack", Vector3.new(1.0, 5.0, d * 0.34), CityKit.Shade(def.sub, 0.45), M.Metal,
            L(nil, x, 2.5, -d * 0.1), true)
        productStrip(model, L(nil, x, 3.4, -d * 0.1), d * 0.3, def.main)
        productStrip(model, L(nil, x, 2.0, -d * 0.1), d * 0.3, CityKit.Shade(def.main, -0.2))
    end
    for _, sx in ipairs({ -w * 0.3, w * 0.3 }) do
        p(model, "Mannequin", Vector3.new(1.4, 2.4, 1.0), def.main, M.SmoothPlastic,
            L(nil, sx, 1.2, d * 0.34), false)
        p(model, "MannequinHead", Vector3.new(1.0, 1.0, 1.0), C(232, 200, 172), M.SmoothPlastic,
            L(nil, sx, 3.0, d * 0.34), false)
    end
    p(model, "FittingWall", Vector3.new(w * 0.24, 5.0, 0.5), CityKit.Shade(def.sub, 0.3), M.Wood,
        L(nil, w * 0.34, 2.5, -d * 0.42), true)
end

local function interiorTables(model, L, w, d, def)
    for _, cfg in ipairs({ { -w * 0.24, -d * 0.05 }, { w * 0.24, -d * 0.05 }, { 0, d * 0.3 } }) do
        p(model, "DisplayTable", Vector3.new(w * 0.36, 1.6, d * 0.24), CityKit.Shade(def.sub, 0.42), M.Metal,
            L(nil, cfg[1], 0.8, cfg[2]), true)
        productStrip(model, L(nil, cfg[1], 1.9, cfg[2]), w * 0.3, def.main)
    end
    for _, sx in ipairs({ -w * 0.42, w * 0.42 }) do
        p(model, "WallShelf", Vector3.new(1.2, 3.6, d * 0.5), CityKit.Shade(def.sub, 0.4), M.Metal,
            L(nil, sx, 2.6, 0), true)
        productStrip(model, L(nil, sx, 3.0, 0), d * 0.42, CityKit.Shade(def.main, 0.2))
    end
end

local function interiorService(model, L, w, d, def)
    p(model, "ServiceCounter", Vector3.new(w * 0.6, 1.2, 2.2), CityKit.Shade(def.sub, 0.4), M.Wood,
        L(nil, 0, 0.6, -d * 0.3), true)
    p(model, "ServiceTop", Vector3.new(w * 0.64, 0.24, 2.5), def.main, M.SmoothPlastic,
        L(nil, 0, 1.32, -d * 0.3), false)
    p(model, "BackShelf", Vector3.new(w * 0.5, 4.0, 0.8), CityKit.Shade(def.sub, 0.32), M.Metal,
        L(nil, 0, 2.2, -d * 0.5 + 1.4), true)
    productStrip(model, L(nil, 0, 3.0, -d * 0.5 + 1.9), w * 0.4, def.main)
    -- Zona de espera / equipo
    for _, sx in ipairs({ -w * 0.26, w * 0.26 }) do
        p(model, "Seat", Vector3.new(2.2, 0.4, 2.2), def.main, M.SmoothPlastic,
            L(nil, sx, 0.9, d * 0.28), false)
        p(model, "SeatBase", Vector3.new(0.6, 0.9, 0.6), def.sub, M.Metal,
            L(nil, sx, 0.45, d * 0.28), false)
    end
end

local function interiorGym(model, L, w, d, def)
    p(model, "Mat", Vector3.new(w * 0.9, 0.3, d * 0.6), CityKit.Shade(def.sub, 0.5), M.Fabric,
        L(nil, 0, 0.15, 0), false)
    for i = 1, 3 do
        local x = -w * 0.28 + (i - 1) * (w * 0.28)
        p(model, "WeightRack", Vector3.new(2.2, 1.4, d * 0.3), def.main, M.Metal,
            L(nil, x, 0.7, -d * 0.38), true)
        p(model, "Bench", Vector3.new(2.4, 0.5, 1.4), C(48, 48, 54), M.Fabric,
            L(nil, x, 1.0, d * 0.1), false)
    end
    p(model, "Mirror", Vector3.new(w * 0.7, 4.0, 0.3), C(150, 180, 200), M.Glass,
        L(nil, 0, 2.4, -d * 0.5 + 0.6), false)
end

local INTERIORS = {
    counter = interiorCounter,
    aisles = interiorAisles,
    racks = interiorRacks,
    tables = interiorTables,
    service = interiorService,
    gym = interiorGym,
}

-- Constructor ------------------------------------------------------------------

function ShopBuilder.Build(lot, shopId, parent, style)
    local def = ShopConfig.Get(shopId)
    if not def then
        return nil
    end

    local alongX = (lot.facing == "north" or lot.facing == "south")
    local availW = alongX and lot.w or lot.d
    local availD = alongX and lot.d or lot.w
    -- Local mas pequeno que el solar, anclado a la acera por su fachada.
    local w = math.max(26, math.min(availW, 54) - 2)
    local d = math.max(24, math.min(availD, 40) - 2)
    local model = CityKit.Model("Shop_" .. shopId, parent)
    local cx, cz
    if lot.facing == "north" then
        cx, cz = lot.cx, lot.z2 - d * 0.5
    elseif lot.facing == "south" then
        cx, cz = lot.cx, lot.z1 + d * 0.5
    elseif lot.facing == "west" then
        cx, cz = lot.x1 + d * 0.5, lot.cz
    else
        cx, cz = lot.x2 - d * 0.5, lot.cz
    end
    local cf = CFrame.new(Vector3.new(cx, WALK, cz)) * CFrame.Angles(0, math.rad(YAW[lot.facing] or 0), 0)

    local function L(_ignore, x, y, z)
        return cf * CFrame.new(x, y, z)
    end

    local wallColor = style and style.wall and CityKit.Pick(CityKit.Rng(#shopId * 131 + 7), style.wall)
        or CityKit.Shade(def.main, -0.55)
    local roofColor = style and style.roof and CityKit.Pick(CityKit.Rng(#shopId * 977 + 3), style.roof)
        or CityKit.Shade(def.sub, 0.2)

    -- Suelo interior (a nivel de acera) y losa bajo el local
    p(model, "ShopFloor", Vector3.new(w, 0.4, d), def.floor, M.SmoothPlastic, L(nil, 0, -0.14, 0), true)
    p(model, "Ceiling", Vector3.new(w, 0.5, d), CityKit.Shade(wallColor, -0.4), M.Concrete, L(nil, 0, H - 0.25, 0), true)

    -- Paredes: laterales y trasera macizas; frontal con hueco de entrada
    p(model, "WallLeft", Vector3.new(T, H, d), wallColor, M.Brick, L(nil, -w * 0.5, H * 0.5, 0), true)
    p(model, "WallRight", Vector3.new(T, H, d), wallColor, M.Brick, L(nil, w * 0.5, H * 0.5, 0), true)
    p(model, "WallBack", Vector3.new(w, H, T), wallColor, M.Brick, L(nil, 0, H * 0.5, -d * 0.5), true)

    -- Frontal: cristaleras a los lados + dintel sobre el hueco
    local segW = (w - DOOR) * 0.5
    local segX = DOOR * 0.5 + segW * 0.5
    for _, sx in ipairs({ -segX, segX }) do
        p(model, "Storefront", Vector3.new(segW, 5.6, 0.3), C(150, 196, 214), M.Glass,
            L(nil, sx, 2.9, d * 0.5), false)
        p(model, "FrontBase", Vector3.new(segW, 0.5, 0.4), CityKit.Shade(wallColor, -0.3), M.Concrete,
            L(nil, sx, 0.25, d * 0.5), false)
    end
    p(model, "Header", Vector3.new(w, H - 5.8, T), wallColor, M.Brick, L(nil, 0, (5.8 + H) * 0.5, d * 0.5), true)
    for _, sx in ipairs({ -DOOR * 0.5 - 0.4, DOOR * 0.5 + 0.4 }) do
        p(model, "DoorPost", Vector3.new(0.8, 6.0, 0.8), CityKit.Shade(wallColor, -0.2), M.Concrete,
            L(nil, sx, 3.0, d * 0.5), true)
    end
    -- Alfombrilla de entrada (marca el acceso)
    p(model, "Mat", Vector3.new(DOOR - 1, 0.12, 3.0), CityKit.Shade(def.main, -0.2), M.Fabric,
        L(nil, 0, 0.06, d * 0.5 - 1.6), false)

    -- Rotulo y toldo
    CityKit.SignBoard(model, (cf * CFrame.new(0, 6.9, d * 0.5 + 0.5)).Position, cf.LookVector,
        Vector3.new(w * 0.92, 2.6, 0.5), def.sub, def.name, def.main)
    CityKit.SignBoard(model, (cf * CFrame.new(0, 4.6, d * 0.5 + 0.7)).Position, cf.LookVector,
        Vector3.new(w * 0.8, 1.4, 0.4), CityKit.Shade(def.main, -0.3), def.kind, C(255, 255, 255), Enum.Font.GothamBold)
    CityKit.Awning(model, cf * CFrame.new(0, 5.7, d * 0.5), w * 0.96, 4.0, def.awning)

    -- Tejado
    p(model, "Roof", Vector3.new(w + 1.8, 0.8, d + 1.8), roofColor, M.Concrete, L(nil, 0, H + 0.4, 0), true)
    p(model, "Parapet", Vector3.new(w + 2.0, 1.0, 0.6), CityKit.Shade(roofColor, 0.15), M.Concrete,
        L(nil, 0, H + 1.2, d * 0.5 + 0.7), false)
    p(model, "ACUnit", Vector3.new(3.4, 2.0, 3.0), C(152, 154, 158), M.Metal, L(nil, w * 0.28, H + 1.6, -d * 0.24), true)

    -- Iluminacion interior
    local strip = p(model, "CeilingLight", Vector3.new(w * 0.7, 0.2, 0.6), C(255, 244, 214), M.Neon,
        L(nil, 0, H - 0.6, 0), false)
    local light = Instance.new("PointLight")
    light.Color = C(255, 240, 208)
    light.Brightness = 1.8
    light.Range = math.max(w, d) * 1.4
    light.Shadows = false
    light.Parent = strip

    -- Interior
    local builder = INTERIORS[def.layout] or interiorService
    builder(model, L, w, d, def)

    model:SetAttribute("ShopId", shopId)
    model:SetAttribute("Kind", def.kind)
    return model
end

return ShopBuilder
