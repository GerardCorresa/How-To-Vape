--[[
    PlayerDataService
    Ruta en Roblox Studio: ServerScriptService > PlayerDataService
    Tipo: ModuleScript

    Persistencia con DataStoreService y perfil por jugador.

    Reglas clave:
      * Nunca se sobrescriben datos reales con valores por defecto: si la
        carga falla tras reintentos, se avisa y se expulsa al jugador (no se
        guarda un perfil vacio encima).
      * No se guarda en cada PUFF: autoguardado por intervalo + PlayerRemoving
        + BindToClose.
      * Estructura versionada (version) y reconciliada al cargar.
      * En Studio (por defecto) se usa un almacen en memoria para poder probar
        sin API Services. Activa GameConfig.DataStoreEnabled y
        GameConfig.StudioUseDataStore para pruebas reales.

    Perfil guardado:
        puffs       saldo actual
        owned       vapers comprados (mapa id -> true)
        equipped    vaper equipado
        vehicles    vehiculos comprados (mapa id -> true)
        zones       distritos descubiertos (mapa id -> true)
        houses      casas con acceso desbloqueado (mapa id -> true)
        discovered  casas vistas (para el mapa; se recompensa una vez)
        missions    misiones completadas (mapa id -> true)
        stats       contadores

    Requiere: GameConfig, VapeConfig, VehicleConfig, ZoneConfig,
              MissionConfig, Net.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local VapeConfig = require(Shared:WaitForChild("VapeConfig"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local MissionConfig = require(Shared:WaitForChild("MissionConfig"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerDataService = {}

local profiles = {}      -- [Player] = profile
local mockStore = {}     -- almacen en memoria para Studio
local store              -- DataStore real o mock
local autosaveThread

-- Crea / actualiza la estructura de datos --------------------------------------
local function defaultProfile()
    return {
        version = GameConfig.DataVersion,
        puffs = GameConfig.StartingPuffs,
        owned = { [GameConfig.DefaultVapeId] = true },
        equipped = GameConfig.DefaultVapeId,
        vehicles = {},
        zones = { starter_block = true },
        -- La casa inicial es de acceso libre: entra desde el primer minuto para
        -- conocer al primer dealer. El resto se desbloquea pagando Puffs.
        houses = { starter = true },
        discovered = {},
        missions = {},
        stats = {
            totalPuffs = 0, puffsClicked = 0,
            housesUnlocked = 0, districtsDiscovered = 1, vapesOwned = 1,
        },
    }
end

-- Normaliza datos potencialmente corruptos o de versiones anteriores.
local function reconcile(data)
    local profile = defaultProfile()
    if type(data) ~= "table" then
        return profile
    end

    profile.puffs = math.max(0, math.floor(tonumber(data.puffs) or 0))

    -- owned: solo ids validos y siempre el basico
    profile.owned = { [GameConfig.DefaultVapeId] = true }
    if type(data.owned) == "table" then
        for id, value in pairs(data.owned) do
            if value == true and VapeConfig.Vapes[id] then
                profile.owned[id] = true
            end
        end
    end

    -- equipped: debe estar comprado
    local eq = data.equipped
    if type(eq) == "string" and profile.owned[eq] then
        profile.equipped = eq
    else
        profile.equipped = GameConfig.DefaultVapeId
    end

    -- vehicles: solo ids validos de VehicleConfig (nunca datos inventados)
    profile.vehicles = {}
    if type(data.vehicles) == "table" then
        for id, value in pairs(data.vehicles) do
            if value == true and VehicleConfig.Get(id) then
                profile.vehicles[id] = true
            end
        end
    end

    -- zones (distritos descubiertos): starter siempre, solo ids validos
    profile.zones = { starter_block = true }
    if type(data.zones) == "table" then
        for id, value in pairs(data.zones) do
            if value == true and ZoneConfig.Districts[id] then
                profile.zones[id] = true
            end
        end
    end

    -- houses (acceso desbloqueado). La casa inicial siempre esta abierta: es el
    -- tutorial de dealers y acceso gratuito por diseno.
    profile.houses = { starter = true }
    if type(data.houses) == "table" then
        for id, value in pairs(data.houses) do
            if value == true and ZoneConfig.Houses[id] then
                profile.houses[id] = true
            end
        end
    end

    -- discovered (casas vistas)
    profile.discovered = {}
    if type(data.discovered) == "table" then
        for id, value in pairs(data.discovered) do
            if value == true and ZoneConfig.Houses[id] then
                profile.discovered[id] = true
            end
        end
    end

    -- missions completadas
    profile.missions = {}
    if type(data.missions) == "table" then
        for id, value in pairs(data.missions) do
            if value == true and MissionConfig.Missions[id] then
                profile.missions[id] = true
            end
        end
    end

    -- stats
    if type(data.stats) == "table" then
        for _, key in ipairs({ "totalPuffs", "puffsClicked", "housesUnlocked", "districtsDiscovered", "vapesOwned" }) do
            profile.stats[key] = math.max(0, math.floor(tonumber(data.stats[key]) or profile.stats[key]))
        end
    end

    -- Recalcula contadores derivados por si el guardado venia a medias.
    local vapeCount, houseCount, districtCount = 0, 0, 0
    for _ in pairs(profile.owned) do vapeCount += 1 end
    for _ in pairs(profile.houses) do houseCount += 1 end
    for _ in pairs(profile.zones) do districtCount += 1 end
    profile.stats.vapesOwned = math.max(profile.stats.vapesOwned, vapeCount)
    profile.stats.housesUnlocked = math.max(profile.stats.housesUnlocked, houseCount)
    profile.stats.districtsDiscovered = math.max(profile.stats.districtsDiscovered, districtCount)

    return profile
end

-- Serializa un perfil para DataStore (sin metadatos de sesion).
local function serialize(profile)
    return {
        version = GameConfig.DataVersion,
        puffs = profile.puffs,
        owned = profile.owned,
        equipped = profile.equipped,
        vehicles = profile.vehicles,
        zones = profile.zones,
        houses = profile.houses,
        discovered = profile.discovered,
        missions = profile.missions,
        stats = profile.stats,
    }
end

local function useRealStore()
    if not GameConfig.DataStoreEnabled then
        return false
    end
    if RunService:IsStudio() and not GameConfig.StudioUseDataStore then
        return false
    end
    return true
end

local function keyFor(player)
    return "player_" .. player.UserId
end

--[[ Inicializa el DataStore (real o en memoria). ]]
function PlayerDataService.Init()
    if useRealStore() then
        local ok, result = pcall(function()
            return DataStoreService:GetDataStore(GameConfig.DataStoreName)
        end)
        if ok then
            store = result
            print("[PlayerDataService] DataStore real activado.")
        else
            warn("[PlayerDataService] No se pudo crear el DataStore, usando memoria:", result)
            store = nil
        end
    end

    if not store then
        print("[PlayerDataService] Usando almacen en memoria (no persiste entre sesiones).")
    end
end

local function readKey(key)
    if store then
        return store:GetAsync(key)
    end
    return mockStore[key]
end

local function writeKey(key, data)
    if store then
        store:SetAsync(key, data)
    else
        mockStore[key] = data
    end
end

--[[ Carga el perfil del jugador. Devuelve profile o (nil, motivo). ]]
function PlayerDataService.Load(player)
    local key = keyFor(player)
    local data
    local loaded = false

    for attempt = 1, GameConfig.LoadRetries do
        local ok, result = pcall(readKey, key)
        if ok then
            data = result
            loaded = true
            break
        end
        warn(("[PlayerDataService] Fallo al cargar %s (intento %d/%d): %s")
            :format(player.Name, attempt, GameConfig.LoadRetries, tostring(result)))
        task.wait(GameConfig.LoadRetryDelay)
    end

    if not loaded then
        return nil, "load_failed"
    end

    local profile = reconcile(data)
    profiles[player] = profile
    return profile
end

--[[ Guarda el perfil actual del jugador. ]]
function PlayerDataService.Save(player)
    local profile = profiles[player]
    if not profile then
        return false
    end
    local key = keyFor(player)
    local data = serialize(profile)
    local ok, err = pcall(writeKey, key, data)
    if not ok then
        warn(("[PlayerDataService] Fallo al guardar %s: %s"):format(player.Name, tostring(err)))
        return false
    end
    return true
end

function PlayerDataService.Get(player)
    return profiles[player]
end

function PlayerDataService.IsLoaded(player)
    return profiles[player] ~= nil
end

function PlayerDataService.Release(player)
    profiles[player] = nil
end

-- Sincronizacion con el cliente ------------------------------------------------
-- payload: { init?, puffs?, gained?, owned?, equipped?, vehicles?, zones?,
--            houses?, discovered?, missions?, activeVehicle? }
-- `activeVehicle` es el id del vehiculo desplegado (o false si no hay ninguno);
-- lo envia VehicleService, porque el despliegue es estado de sesion y no se
-- guarda en el DataStore.
-- Los stats se adjuntan siempre (barato) para que el panel de misiones tenga
-- el progreso exacto sin necesitar un evento dedicado.
function PlayerDataService.Sync(player, payload)
    if type(payload) == "table" then
        local profile = profiles[player]
        if profile and payload.stats == nil then
            payload.stats = profile.stats
        end
    end
    Net.get("SyncData"):FireClient(player, payload)
end

function PlayerDataService.Notify(player, text, color)
    Net.get("Notify"):FireClient(player, { text = text, color = color })
end

--[[ Envia el estado completo (util al entrar o para forzar resync). ]]
function PlayerDataService.SyncProfile(player, isInit)
    local profile = profiles[player]
    if not profile then
        return
    end
    PlayerDataService.Sync(player, {
        init = isInit and true or nil,
        puffs = profile.puffs,
        owned = profile.owned,
        equipped = profile.equipped,
        vehicles = profile.vehicles,
        zones = profile.zones,
        houses = profile.houses,
        discovered = profile.discovered,
        missions = profile.missions,
        stats = profile.stats,
    })
end

-- Autoguardado -----------------------------------------------------------------
function PlayerDataService.InitAutosave()
    if autosaveThread then
        return
    end
    autosaveThread = task.spawn(function()
        while true do
            task.wait(GameConfig.AutoSaveInterval)
            for _, player in ipairs(Players:GetPlayers()) do
                if profiles[player] then
                    PlayerDataService.Save(player)
                end
            end
        end
    end)
end

-- Guardado final independiente de PlayerRemoving (cierre de servidor) ----------
function PlayerDataService.BindShutdown()
    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            PlayerDataService.Save(player)
        end
        if not RunService:IsStudio() then
            task.wait(2)
        end
    end)
end

return PlayerDataService
