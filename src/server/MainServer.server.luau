--[[
    MainServer
    Ruta en Roblox Studio: ServerScriptService > MainServer
    Tipo: Script (Script de servidor, no LocalScript)

    Punto de entrada del servidor. Inicializa remotos, servicios, construye la
    ciudad y gestiona el ciclo de vida de los jugadores (carga de datos,
    equipamiento al reaparecer, guardado al salir).

    Este script es DELGADO: solo orquesta. La logica vive en los servicios.

    Requiere: Net, PlayerDataService, PuffService, ShopService, ZoneService,
              AccessService, ProgressService, EquipmentService, VehicleService,
              CityBuilder.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = script.Parent
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local PuffService = require(ServerScriptService:WaitForChild("PuffService"))
local ShopService = require(ServerScriptService:WaitForChild("ShopService"))
local ZoneService = require(ServerScriptService:WaitForChild("ZoneService"))
local AccessService = require(ServerScriptService:WaitForChild("AccessService"))
local ProgressService = require(ServerScriptService:WaitForChild("ProgressService"))
local EquipmentService = require(ServerScriptService:WaitForChild("EquipmentService"))
local VehicleService = require(ServerScriptService:WaitForChild("VehicleService"))
local CityBuilder = require(ServerScriptService:WaitForChild("CityBuilder"))

-- 1) Red ----------------------------------------------------------------------
Net.init()

-- 2) Datos --------------------------------------------------------------------
PlayerDataService.Init()
PlayerDataService.InitAutosave()
PlayerDataService.BindShutdown()

-- 3) Ciudad -------------------------------------------------------------------
CityBuilder.Build()

-- 4) Vehiculos temporales: contenedor limpio (idempotente al recargar scripts) --
--    La PROPIEDAD de los vehiculos vive en el perfil del jugador; aqui solo se
--    guardan los modelos desplegados en esta sesion. Se crea DESPUES de
--    CityBuilder para que su limpieza de contenedores no lo toque.
local vehiclesFolder = workspace:FindFirstChild("HowToVape_Vehicles")
if vehiclesFolder then
    vehiclesFolder:Destroy()
end
local newVehiclesFolder = Instance.new("Folder")
newVehiclesFolder.Name = "HowToVape_Vehicles"
newVehiclesFolder.Parent = workspace

-- 5) Servicios de juego -------------------------------------------------------
PuffService.Init()
ShopService.Init()
ZoneService.Init()
AccessService.Init()
ProgressService.Init()
VehicleService.Init()

-- 6) Ciclo de vida de jugadores ----------------------------------------------
-- Al aparecer (primera vez o respawn) colocamos el vape guardado en la mano.
local function onCharacterAdded(player)
    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end
    task.wait(0.3) -- deja que el personaje termine de cargar
    EquipmentService.Equip(player, profile.equipped)
end

local function onPlayerAdded(player)
    local profile, reason = PlayerDataService.Load(player)

    if not profile then
        -- No arriesgamos perder progreso: no guardamos datos por defecto.
        warn(("[MainServer] No se pudieron cargar los datos de %s (%s). Expulsando.")
            :format(player.Name, tostring(reason)))
        player:Kick("No se pudieron cargar tus datos. Vuelve a entrar en unos segundos.")
        return
    end

    -- Estado inicial completo a la interfaz (puffs, vapes, casas, descubrimientos)
    PlayerDataService.SyncProfile(player, true)

    player.CharacterAdded:Connect(function()
        onCharacterAdded(player)
    end)

    if player.Character then
        task.spawn(onCharacterAdded, player)
    end
end

local function onPlayerRemoving(player)
    VehicleService.Release(player)
    PlayerDataService.Save(player)
    PuffService.Release(player)
    ShopService.Release(player)
    ZoneService.Release(player)
    AccessService.Release(player)
    PlayerDataService.Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Jugadores que ya estaban (Studio / recarga de scripts)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

print("[MainServer] HOW TO VAPE servidor iniciado.")
