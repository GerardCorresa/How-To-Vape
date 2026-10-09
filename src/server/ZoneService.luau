--[[
    ZoneService
    Ruta en Roblox Studio: ServerScriptService > ZoneService
    Tipo: ModuleScript

    "Descubrimiento" de distritos desde su arco/puerta, validado en servidor:
      * el distrito existe y no estaba ya descubierto
      * el jugador esta cerca del arco
      * cumple el requisito de Puffs (umbral, no coste)

    Los distritos tambien se descubren automaticamente al entrar fisicamente
    (ver ProgressService); este prompt es el registro "oficial" en la puerta y
    da la recompensa de descubrimiento de forma inmediata.

    Requiere: GameConfig, ZoneConfig, Net, PlayerDataService, ProgressService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ProgressService = require(script.Parent:WaitForChild("ProgressService"))

local ZoneService = {}

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

--[[ Descubre un distrito desde su arco. ]]
function ZoneService.Unlock(player, zoneId)
    if type(zoneId) ~= "string" then
        return
    end
    local zone = ZoneConfig.Districts[zoneId]
    if not zone then
        return
    end

    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end

    if profile.zones[zoneId] then
        notify(player, zone.name .. " ya esta descubierto.", Color3.fromRGB(120, 200, 255))
        return
    end

    local now = os.clock()
    if lastUnlockAt[player] and now - lastUnlockAt[player] < GameConfig.UnlockCooldown then
        return
    end
    lastUnlockAt[player] = now

    -- Proximidad a la puerta
    if distanceTo(player, zone.gatePosition) > GameConfig.ZoneGateRange then
        notify(player, "Acercate a la entrada de " .. zone.name .. ".", Color3.fromRGB(255, 170, 60))
        return
    end

    -- Requisito de Puffs (umbral)
    if profile.puffs < (zone.requirement or 0) then
        local falta = (zone.requirement or 0) - profile.puffs
        notify(player, ("Necesitas %d Puffs mas para descubrir %s."):format(falta, zone.name), Color3.fromRGB(255, 90, 90))
        return
    end

    profile.zones[zoneId] = true
    profile.stats.districtsDiscovered = profile.stats.districtsDiscovered + 1
    PlayerDataService.Save(player)

    PlayerDataService.Sync(player, { zones = profile.zones })
    notify(player, "Distrito descubierto: " .. zone.name .. "!", Color3.fromRGB(90, 255, 150))

    ProgressService.Evaluate(player)
end

function ZoneService.Init()
    Net.get("UnlockZone").OnServerEvent:Connect(function(player, zoneId)
        ZoneService.Unlock(player, zoneId)
    end)
end

function ZoneService.Release(player)
    lastUnlockAt[player] = nil
end

return ZoneService
