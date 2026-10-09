--[[
    ProgressService
    Ruta en Roblox Studio: ServerScriptService > ProgressService
    Tipo: ModuleScript

    Exploracion, descubrimiento y misiones, todo validado en servidor.

      * Descubrimiento de DISTRITOS: al entrar fisicamente en un distrito se
        marca como conocido (revela en el mapa) y se sincroniza.
      * Descubrimiento de CASAS: al acercarse a una casa nueva se marca como
        vista (revela su dealer en el mapa) y da una pequena recompensa.
      * MISIONES: se evaluan tras cada evento relevante (calada, compra,
        descubrimiento, desbloqueo). Al completarse pagan Puffs una sola vez.

    Un unico barrido cada GameConfig.DiscoverInterval segundos. Coste por
    jugador = (8 distritos + 13 casas) comprobaciones triviales; no recorre
    ninguna jerarquia de Workspace.

    Requiere: GameConfig, ZoneConfig, MissionConfig, EconomyConfig,
              PlayerDataService, Net.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local MissionConfig = require(Shared:WaitForChild("MissionConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local ProgressService = {}

local started = false

local function notify(player, text, color)
    PlayerDataService.Notify(player, text, color)
end

local function countKeys(map)
    local n = 0
    for _ in pairs(map) do n += 1 end
    return n
end

-- Metricas de mision ----------------------------------------------------------
local function metricValue(profile, metric)
    if metric == "puffsClicked" then
        return profile.stats.puffsClicked
    elseif metric == "totalPuffs" then
        return profile.stats.totalPuffs
    elseif metric == "districts" then
        return countKeys(profile.zones)
    elseif metric == "houses" then
        return countKeys(profile.houses)
    elseif metric == "vapes" then
        return countKeys(profile.owned)
    elseif metric == "puffs" then
        return profile.puffs
    end
    return 0
end

--[[ Revisa todas las misiones y paga las recien completadas. ]]
function ProgressService.Evaluate(player)
    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end
    local completedAny = false
    for _, mission in ipairs(MissionConfig.GetOrdered()) do
        if not profile.missions[mission.id] then
            if metricValue(profile, mission.metric) >= mission.target then
                profile.missions[mission.id] = true
                profile.puffs += mission.reward
                completedAny = true
                notify(player, ("MISION COMPLETADA: %s  (+%d Puffs)"):format(mission.name, mission.reward),
                    Color3.fromRGB(120, 255, 190))
            end
        end
    end
    if completedAny then
        PlayerDataService.Save(player)
        PlayerDataService.Sync(player, {
            puffs = profile.puffs,
            missions = profile.missions,
        })
    end
end

-- Descubrimiento ---------------------------------------------------------------
local function discoverDistrict(player, profile, district)
    profile.zones[district.id] = true
    profile.stats.districtsDiscovered = countKeys(profile.zones)
    local reward = EconomyConfig.Rewards.DistrictDiscover or 0
    if reward > 0 then
        profile.puffs += reward
    end
    notify(player, ("DISTRITO DESCUBIERTO: %s"):format(district.name), district.color)
    return true
end

local function discoverHouse(player, profile, house)
    profile.discovered[house.id] = true
    local reward = EconomyConfig.Rewards.HouseDiscover or 0
    if reward > 0 then
        profile.puffs += reward
    end
    notify(player, ("Casa descubierta: %s  (+%d Puffs)"):format(house.name, reward),
        house.dealer.color or Color3.fromRGB(200, 200, 200))
    return true
end

local function scanPlayer(player, profile)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local pos = root.Position
    local changed = false
    local radius = ZoneConfig.Layout.districtSize * 0.62

    -- Distritos
    for _, id in ipairs(ZoneConfig.DistrictOrder) do
        if not profile.zones[id] then
            local district = ZoneConfig.Districts[id]
            if (Vector3.new(pos.X, 0, pos.Z) - district.center).Magnitude <= radius then
                changed = discoverDistrict(player, profile, district) or changed
            end
        end
    end

    -- Casas
    for _, id in ipairs(ZoneConfig.HouseOrder) do
        if not profile.discovered[id] then
            local house = ZoneConfig.Houses[id]
            if (Vector3.new(pos.X, 0, pos.Z) - house.position).Magnitude <= GameConfig.DiscoverRange then
                changed = discoverHouse(player, profile, house) or changed
            end
        end
    end

    if changed then
        PlayerDataService.Save(player)
        PlayerDataService.Sync(player, {
            puffs = profile.puffs,
            zones = profile.zones,
            discovered = profile.discovered,
        })
        ProgressService.Evaluate(player)
    end
end

function ProgressService.Init()
    if started then
        return
    end
    started = true
    task.spawn(function()
        while true do
            task.wait(GameConfig.DiscoverInterval)
            for _, player in ipairs(Players:GetPlayers()) do
                local profile = PlayerDataService.Get(player)
                if profile then
                    pcall(scanPlayer, player, profile)
                end
            end
        end
    end)
end

return ProgressService
