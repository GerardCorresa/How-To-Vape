--[[
    ShopService
    Ruta en Roblox Studio: ServerScriptService > ShopService
    Tipo: ModuleScript

    Compras y equipamiento, validados por completo en el servidor:
      * el vape existe en VapeConfig
      * no lo tiene ya (evita doble cobro)
      * el ACCESO a la casa que lo vende esta desbloqueado (profile.houses)
      * el jugador esta fisicamente en esa casa (anti-remote-spam)
      * tiene Puffs suficientes
    Solo entonces descuenta Puffs, marca owned y sincroniza.

    Cada dealer vende una seleccion coherente con su distrito (ver el campo
    `house` de cada vaper en VapeConfig). No se pueden comprar todos los vapers
    desde una sola tienda.

    Requiere: GameConfig, VapeConfig, ZoneConfig, Net,
              PlayerDataService, EquipmentService, ProgressService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local VapeConfig = require(Shared:WaitForChild("VapeConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EquipmentService = require(script.Parent:WaitForChild("EquipmentService"))
local ProgressService = require(script.Parent:WaitForChild("ProgressService"))

local ShopService = {}

local lastPurchaseAt = {}
local lastEquipAt = {}

local function distanceTo(player, position)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or typeof(position) ~= "Vector3" then
        return math.huge
    end
    return (root.Position - position).Magnitude
end

local function notify(player, text, color)
    PlayerDataService.Notify(player, text, color)
end

--[[ Compra un vape. ]]
function ShopService.Purchase(player, vapeId)
    if type(vapeId) ~= "string" then
        return
    end
    local cfg = VapeConfig.Vapes[vapeId]
    if not cfg then
        return
    end

    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end

    -- Antispam
    local now = os.clock()
    if lastPurchaseAt[player] and now - lastPurchaseAt[player] < GameConfig.PurchaseCooldown then
        return
    end
    lastPurchaseAt[player] = now

    if profile.owned[vapeId] then
        notify(player, "Ya tienes el " .. cfg.name .. ".", Color3.fromRGB(255, 200, 80))
        return
    end

    -- Debe venderse en una casa concreta
    local houseId = cfg.house
    local house = houseId and ZoneConfig.Houses[houseId]
    if not house then
        notify(player, "Ese dispositivo no esta en venta.", Color3.fromRGB(255, 90, 90))
        return
    end

    -- El acceso a esa casa debe estar desbloqueado
    if not profile.houses[houseId] then
        notify(player, "Primero desbloquea el acceso a " .. house.name .. ".", Color3.fromRGB(255, 90, 90))
        return
    end

    -- Proximidad fisica al dealer (no se puede comprar desde cualquier sitio)
    if distanceTo(player, house.position) > GameConfig.DealerRange then
        notify(player, "Acercate al dealer para comprar.", Color3.fromRGB(255, 170, 60))
        return
    end

    -- Saldo
    if profile.puffs < cfg.price then
        local falta = cfg.price - profile.puffs
        notify(player, ("Necesitas %d Puffs mas para el %s."):format(falta, cfg.name), Color3.fromRGB(255, 90, 90))
        return
    end

    -- Cobro + entrega (operacion server-side)
    profile.puffs -= cfg.price
    profile.owned[vapeId] = true
    profile.stats.vapesOwned = profile.stats.vapesOwned + 1
    PlayerDataService.Save(player)

    PlayerDataService.Sync(player, {
        puffs = profile.puffs,
        owned = profile.owned,
    })
    notify(player, "Has comprado el " .. cfg.name .. "!", Color3.fromRGB(90, 255, 150))

    ProgressService.Evaluate(player)
end

--[[ Equipa un vape ya comprado. ]]
function ShopService.Equip(player, vapeId)
    if type(vapeId) ~= "string" then
        return
    end
    local cfg = VapeConfig.Vapes[vapeId]
    if not cfg then
        return
    end

    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end

    local now = os.clock()
    if lastEquipAt[player] and now - lastEquipAt[player] < GameConfig.EquipCooldown then
        return
    end
    lastEquipAt[player] = now

    if not profile.owned[vapeId] then
        notify(player, "No tienes ese dispositivo. Compralo primero.", Color3.fromRGB(255, 90, 90))
        return
    end

    if profile.equipped == vapeId then
        return
    end

    profile.equipped = vapeId
    EquipmentService.Equip(player, vapeId)
    PlayerDataService.Save(player)
    PlayerDataService.Sync(player, { equipped = vapeId })
    notify(player, "Equipado: " .. cfg.name, Color3.fromRGB(120, 200, 255))
end

--[[ Vapers que vende una casa (helper usado tambien por el cliente). ]]
function ShopService.GetStock(houseId)
    return VapeConfig.ByHouse(houseId)
end

function ShopService.Init()
    Net.get("PurchaseVape").OnServerEvent:Connect(function(player, vapeId)
        ShopService.Purchase(player, vapeId)
    end)
    Net.get("EquipVape").OnServerEvent:Connect(function(player, vapeId)
        ShopService.Equip(player, vapeId)
    end)
end

function ShopService.Release(player)
    lastPurchaseAt[player] = nil
    lastEquipAt[player] = nil
end

return ShopService
