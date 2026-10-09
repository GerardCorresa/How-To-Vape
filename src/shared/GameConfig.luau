--[[
    GameConfig
    Ruta en Roblox Studio: ReplicatedStorage > Shared > GameConfig
    Tipo: ModuleScript

    Configuracion global del juego. Centraliza el balance, los nombres de
    Remotes y los tiempos. Nada de logica aqui: solo datos.
]]

local GameConfig = {}

GameConfig.GameName = "HOW TO VAPE"
GameConfig.DataVersion = 2

-- Economia base --------------------------------------------------------------
GameConfig.BasePuffsPerAction = 1
GameConfig.StartingPuffs = 0
GameConfig.DefaultVapeId = "basic"

-- Ritmo / anti-spam ----------------------------------------------------------
GameConfig.PuffCooldown = 0.5          -- segundos entre PUFF validados en servidor
GameConfig.PuffClientCooldown = 0.52   -- feedback en cliente (un pelin mayor)
GameConfig.PurchaseCooldown = 0.35
GameConfig.EquipCooldown = 0.2
GameConfig.UnlockCooldown = 0.6
GameConfig.VehiclePurchaseCooldown = 0.4   -- solo para el remoto de compra
GameConfig.VehicleSpawnCooldown = 0.7      -- desplegar (evita spam de modelos)
GameConfig.VehicleStoreCooldown = 0.3      -- guardar / retirar

-- Movimiento a pie -----------------------------------------------------------
-- Sprint con SHIFT IZQUIERDO (ver MovementController en el cliente).
GameConfig.WalkSpeed = 16              -- velocidad normal
GameConfig.SprintSpeed = 24            -- velocidad con Shift pulsado
GameConfig.SprintTransition = 0.22     -- segundos de transicion suave (ida o vuelta)

-- Vehiculos ------------------------------------------------------------------
GameConfig.VehicleMaxActive = 1        -- patinetes simultaneos por jugador
GameConfig.VehicleSpawnRange = 7       -- studs al lado del jugador al desplegar
GameConfig.VehicleGroundRay = 14       -- altura del sondeo de suelo al desplegar
GameConfig.VehicleFallLimit = -30      -- por debajo de esto se limpia el vehiculo

-- Guardado -------------------------------------------------------------------
GameConfig.DataStoreName = "HowToVape_Profile_v1"
GameConfig.DataStoreEnabled = true     -- datos persistentes en produccion
GameConfig.StudioUseDataStore = false  -- en Studio usamos memoria salvo que lo actives
GameConfig.AutoSaveInterval = 90       -- segundos entre autoguardados
GameConfig.LoadRetries = 3
GameConfig.LoadRetryDelay = 2

-- Interaccion ----------------------------------------------------------------
GameConfig.DealerRange = 22            -- studs maximos al dealer para comprar
GameConfig.ZoneGateRange = 26          -- studs maximos a la puerta para descubrir
GameConfig.HouseRange = 30             -- studs maximos a la casa para desbloquear
GameConfig.DiscoverRange = 90          -- studs para detectar que "ves" una casa
GameConfig.DiscoverInterval = 2        -- segundos entre barridos de descubrimiento

-- Zona de fumadores ----------------------------------------------------------
GameConfig.RequireSmokingZone = true   -- PUFF solo dentro de la zona de fumadores
GameConfig.SmokingZoneRadius = 75      -- radio por defecto (CityBuilder puede sobrescribir)

-- Interfaz -------------------------------------------------------------------
GameConfig.NotificationTime = 3.5
GameConfig.RemotesFolderName = "Remotes"

-- Nombres de remotos (deben coincidir con Net.luau) --------------------------
GameConfig.RemoteNames = {
    PuffRequest = "PuffRequest",   -- cliente -> servidor (RemoteEvent)
    PurchaseVape = "PurchaseVape", -- cliente -> servidor
    EquipVape = "EquipVape",       -- cliente -> servidor
    UnlockZone = "UnlockZone",     -- cliente -> servidor (descubrir distrito)
    UnlockHouse = "UnlockHouse",   -- cliente -> servidor (acceso a casa)
    SyncData = "SyncData",         -- servidor -> cliente
    Notify = "Notify",             -- servidor -> cliente
    PuffBroadcast = "PuffBroadcast", -- servidor -> todos: inicia la animacion de calada
    PurchaseVehicle = "PurchaseVehicle", -- cliente -> servidor (comprar vehiculo)
    SpawnVehicle = "SpawnVehicle",       -- cliente -> servidor (desplegar)
    DespawnVehicle = "DespawnVehicle",   -- cliente -> servidor (guardar/retirar)
}

GameConfig.RemoteTypes = {
    PuffRequest = "RemoteEvent",
    PurchaseVape = "RemoteEvent",
    EquipVape = "RemoteEvent",
    UnlockZone = "RemoteEvent",
    UnlockHouse = "RemoteEvent",
    SyncData = "RemoteEvent",
    Notify = "RemoteEvent",
    PuffBroadcast = "RemoteEvent",
    PurchaseVehicle = "RemoteEvent",
    SpawnVehicle = "RemoteEvent",
    DespawnVehicle = "RemoteEvent",
}

return GameConfig
