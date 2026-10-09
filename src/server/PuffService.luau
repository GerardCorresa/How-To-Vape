--[[
    PuffService
    Ruta en Roblox Studio: ServerScriptService > PuffService
    Tipo: ModuleScript

    Resuelve cada accion de PUFF en el servidor (autoridad total):
      * valida tipos y frecuencia (cooldown anti-spam por jugador)
      * comprueba que el jugador esta en la zona de fumadores (configurable)
      * lee el multiplicador del vape EQUIPADO y COMPRADO del perfil
      * suma Puffs, actualiza estadisticas y sincroniza con el cliente

    El cliente solo envia la intencion ("quiero dar una calada"); nunca envia
    cantidades. El servidor recalcula el resultado desde VapeConfig.

    Requiere: GameConfig, VapeConfig, Net, PlayerDataService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local VapeConfig = require(Shared:WaitForChild("VapeConfig"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ProgressService = require(script.Parent:WaitForChild("ProgressService"))

local PuffService = {}

local lastPuffAt = {} -- [Player] = os.clock()

local function getRootPart(player)
    local character = player.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

-- Comprueba si el jugador esta dentro de la zona de fumadores de la ciudad.
function PuffService.InSmokingZone(player)
    local root = getRootPart(player)
    if not root then
        return false
    end
    local pos = workspace:GetAttribute("SmokingZonePosition")
    local radius = workspace:GetAttribute("SmokingZoneRadius")
    if typeof(pos) ~= "Vector3" then
        return true -- si no hay zona definida, no bloqueamos
    end
    radius = radius or GameConfig.SmokingZoneRadius
    return (root.Position - pos).Magnitude <= radius
end

--[[ Procesa la peticion de un PUFF. ]]
function PuffService.Handle(player)
    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end

    -- Cooldown anti-spam
    local now = os.clock()
    if lastPuffAt[player] and now - lastPuffAt[player] < GameConfig.PuffCooldown then
        return
    end
    lastPuffAt[player] = now

    -- Zona de fumadores
    if GameConfig.RequireSmokingZone and not PuffService.InSmokingZone(player) then
        PlayerDataService.Notify(player, "Ve a la ZONA DE FUMADORES de la plaza para dar caladas.", Color3.fromRGB(255, 170, 60))
        return
    end

    -- Vape equipado debe existir y estar comprado
    local vape = VapeConfig.Vapes[profile.equipped]
    if not vape or not profile.owned[profile.equipped] then
        profile.equipped = GameConfig.DefaultVapeId
        PlayerDataService.Sync(player, { equipped = profile.equipped })
        vape = VapeConfig.Vapes[profile.equipped]
    end

    -- Recompensa calculada en el servidor
    local gained = GameConfig.BasePuffsPerAction * (vape.multiplier or 1)
    profile.puffs += gained
    profile.stats.totalPuffs += gained
    profile.stats.puffsClicked += 1

    PlayerDataService.Sync(player, {
        puffs = profile.puffs,
        gained = gained,
        equipped = profile.equipped,
    })

    -- Aviso autoritativo al resto de clientes para que reproduzcan la calada.
    -- El cliente que la pulsa ya la anima en local, asi que se descarta a si
    -- mismo comparando UserId (ver ClientController). Esto evita que cada
    -- jugador tenga que replicar CFrames por la red.
    Net.get("PuffBroadcast"):FireAllClients({
        userId = player.UserId,
        vapeId = profile.equipped,
    })

    -- Las misiones de "dar N caladas" / "reunir N Puffs" avanzan aqui.
    ProgressService.Evaluate(player)
end

function PuffService.Init()
    Net.get("PuffRequest").OnServerEvent:Connect(function(player)
        PuffService.Handle(player)
    end)
end

-- Limpieza al salir
function PuffService.Release(player)
    lastPuffAt[player] = nil
end

return PuffService
