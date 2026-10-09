--[[
    AccessService
    Ruta en Roblox Studio: ServerScriptService > AccessService
    Tipo: ModuleScript

    Desbloqueo de ACCESO a las casas funcionales (donde viven los dealers).
    Validado por completo en el servidor:

      * la casa existe
      * no estaba ya desbloqueada (evita doble cobro)
      * el jugador esta fisicamente junto a la casa (anti-remote-spam)
      * tiene Puffs suficientes

    Solo entonces cobra (una vez), marca profile.houses[houseId] y sincroniza.
    El desbloqueo es PERMANENTE por jugador y no se vuelve a cobrar al entrar
    o salir. La puerta fisica la abre cada cliente en local (ver DoorClient)
    segun este estado, de forma que el acceso es realmente por jugador.

    Requiere: GameConfig, ZoneConfig, Net, PlayerDataService, ProgressService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ProgressService = require(script.Parent:WaitForChild("ProgressService"))

local AccessService = {}

local lastUnlockAt = {}

local function notify(player, text, color)
    PlayerDataService.Notify(player, text, color)
end

local function distanceTo(player, position)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or typeof(position) ~= "Vector3" then
        return math.huge
    end
    return (root.Position - position).Magnitude
end

--[[ Posicion de la puerta de una casa (centro + frente). ]]
function AccessService.DoorPosition(house)
    local yaw = math.rad(house.facing or 0)
    local front = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
    return house.position + front * (house.d / 2)
end

function AccessService.IsUnlocked(player, houseId)
    local profile = PlayerDataService.Get(player)
    return profile ~= nil and profile.houses[houseId] == true
end

--[[ Intenta desbloquear el acceso a una casa. ]]
function AccessService.Unlock(player, houseId)
    if type(houseId) ~= "string" then
        return
    end
    local house = ZoneConfig.Houses[houseId]
    if not house then
        return
    end

    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end

    if profile.houses[houseId] then
        notify(player, house.name .. " ya es accesible para ti.", Color3.fromRGB(120, 200, 255))
        return
    end

    local now = os.clock()
    if lastUnlockAt[player] and now - lastUnlockAt[player] < GameConfig.UnlockCooldown then
        return
    end
    lastUnlockAt[player] = now

    -- Proximidad fisica a la puerta
    if distanceTo(player, AccessService.DoorPosition(house)) > GameConfig.HouseRange then
        notify(player, "Acercate a la puerta de " .. house.name .. ".", Color3.fromRGB(255, 170, 60))
        return
    end

    local cost = house.requirement or 0
    if profile.puffs < cost then
        local falta = cost - profile.puffs
        notify(player, ("Necesitas %d Puffs mas para %s."):format(falta, house.name), Color3.fromRGB(255, 90, 90))
        return
    end

    -- Cobro unico + entrega
    if cost > 0 then
        profile.puffs -= cost
    end
    profile.houses[houseId] = true
    profile.discovered[houseId] = true
    profile.stats.housesUnlocked = profile.stats.housesUnlocked + 1

    PlayerDataService.Save(player)
    PlayerDataService.Sync(player, {
        puffs = profile.puffs,
        houses = profile.houses,
        discovered = profile.discovered,
    })
    notify(player, "Acceso desbloqueado: " .. house.name .. "!", Color3.fromRGB(90, 255, 150))

    ProgressService.Evaluate(player)
end

function AccessService.Init()
    Net.get("UnlockHouse").OnServerEvent:Connect(function(player, houseId)
        AccessService.Unlock(player, houseId)
    end)
end

function AccessService.Release(player)
    lastUnlockAt[player] = nil
end

return AccessService
