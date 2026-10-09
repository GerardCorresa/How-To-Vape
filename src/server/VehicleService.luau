--[[
    VehicleService
    Ruta en Roblox Studio: ServerScriptService > VehicleService
    Tipo: ModuleScript

    Compra, despliegue y limpieza de vehiculos. TODO se valida aqui:

      * Compra   el vehiculo existe (VehicleConfig), no lo tiene ya (evita
                 doble cobro), tiene Puffs suficientes y el precio viene de
                 EconomyConfig. Descuenta una sola vez y guarda el perfil.
      * Despliegue  exige la propiedad, limita a GameConfig.VehicleMaxActive
                 vehiculos por jugador, busca un hueco libre y seguro al lado
                 del jugador (no dentro de muros, no bajo el mapa) y aparece
                 anclado y de pie.
      * Conduccion  el modelo lo mueve el cliente del conductor de forma
                 cinemática (VehicleController). El servidor solo habilita el
                 movimiento al montarse (atributo DriveEnabled) y lo vuelve a
                 anclar al bajarse: asi el vehiculo nunca se hunde, ni se
                 cae solo, ni se separa del jugador.
      * Limpieza al morir, al salir del servidor, si el vehiculo cae fuera del
                 mapa o si alguien lo destruye. Uno activo por jugador.

    Requiere: GameConfig, VehicleConfig, VehicleFactory, Net,
              PlayerDataService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local VehicleService = {}

local CONTAINER = "HowToVape_Vehicles"
local DRIVE_ATTR = "DriveEnabled"

local active = {}            -- [Player] = { model, id, seat, conn }
local lastPurchaseAt = {}
local lastSpawnAt = {}
local lastStoreAt = {}
local watched = {}           -- [Player] = true (conexiones por jugador)

local OK = Color3.fromRGB(86, 240, 156)
local BAD = Color3.fromRGB(255, 92, 108)
local WARN = Color3.fromRGB(255, 188, 84)
local INFO = Color3.fromRGB(150, 158, 188)

local function notify(player, text, color)
    PlayerDataService.Notify(player, text, color)
end

local function folder()
    local f = workspace:FindFirstChild(CONTAINER)
    if not f then
        f = Instance.new("Folder")
        f.Name = CONTAINER
        f.Parent = workspace
    end
    return f
end

local function getRoot(player)
    local character = player.Character
    if not character then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then
        return nil
    end
    return root, humanoid, character
end

-- Ancla / desancla todo el vehiculo. Anclado = aparcado y estable; desanclado =
-- el cliente puede conducirlo (es el dueno de la fisica mientras conduce).
local function setAnchored(model, anchored)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = anchored
        end
    end
end

--[[ Evita que las piernas y los pies del conductor arrastren por el suelo
     cuando va montado (es lo unico que puede desestabilizar un vehiculo bajo).
     Se restaura al bajarse. ]]
local function setLegsCollision(player, collide)
    local character = player.Character
    if not character then
        return
    end
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = d.Name
            if string.find(n, "Leg", 1, true) or string.find(n, "Foot", 1, true) then
                d.CanCollide = collide
            end
        end
    end
end

-- Busqueda de suelo -----------------------------------------------------------

local function rayParams(player, model)
    local ignore = {}
    if player.Character then
        table.insert(ignore, player.Character)
    end
    local c = workspace:FindFirstChild(CONTAINER)
    if c then
        table.insert(ignore, c)
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    return params
end

-- Altura del suelo en una coordenada XZ (nil si no hay nada debajo).
local function groundAt(player, model, x, z, fromY)
    local params = rayParams(player, model)
    local origin = Vector3.new(x, fromY + GameConfig.VehicleGroundRay, z)
    local hit = workspace:Raycast(origin, Vector3.new(0, -(GameConfig.VehicleGroundRay * 2), 0), params)
    if hit then
        return hit.Position.Y
    end
    return nil
end

--[[ Hueco libre: dentro de la caja del vehiculo no puede haber nada solido que
     sobresalga del suelo (los bordillos, tapas y demas piezas bajas se ignoran
     a proposito: al conducir se suben de forma suave). ]]
local function isFree(player, center, size)
    local ignore = {}
    if player.Character then
        table.insert(ignore, player.Character)
    end
    local c = workspace:FindFirstChild(CONTAINER)
    if c then
        table.insert(ignore, c)
    end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local floorTop = center.Y - size.Y * 0.5
    for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(center), size, params)) do
        if part.CanCollide and (part.Position.Y + part.Size.Y * 0.5) > floorTop + 0.55 then
            return false
        end
    end
    return true
end

--[[ Busca un punto de aparcamiento libre al lado del jugador, siempre sobre el
     suelo y nunca dentro de un muro. Devuelve `cframe` o nil. ]]
local function findSpot(player, size)
    local root = getRoot(player)
    if not root then
        return nil
    end
    local look = root.CFrame.LookVector
    local yaw = math.atan2(-look.X, -look.Z)
    local flat = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
    local fwd = flat.LookVector
    local right = flat.RightVector
    local boxSize = Vector3.new(size.X + 0.6, 2.4, size.Z + 0.6)

    local dirs = {
        { f = 1.0, s = 0.0 }, { f = 0.7, s = -0.6 }, { f = 0.7, s = 0.6 },
        { f = 0.3, s = -0.9 }, { f = 0.3, s = 0.9 },
        { f = -0.5, s = -0.6 }, { f = -0.5, s = 0.6 }, { f = -1.0, s = 0.0 },
    }
    local ground = root.Position.Y - 2.9 -- el HRP esta ~3 studs sobre el suelo

    for _, dist in ipairs({ 5.6, 7.4, 4.2 }) do
        for _, d in ipairs(dirs) do
            local dir = (fwd * d.f + right * d.s)
            if dir.Magnitude > 0.01 then
                dir = dir.Unit
                local x = root.Position.X + dir.X * dist
                local z = root.Position.Z + dir.Z * dist
                local gy = groundAt(player, nil, x, z, root.Position.Y)
                if gy and math.abs(gy - ground) <= 5 then
                    local center = Vector3.new(x, gy + boxSize.Y * 0.5 + 0.05, z)
                    if isFree(player, center, boxSize) then
                        return CFrame.new(x, gy, z) * CFrame.Angles(0, yaw, 0)
                    end
                end
            end
        end
    end
    return nil
end

-- Estados de conduccion -------------------------------------------------------

local function onMounted(player, model)
    setAnchored(model, false)
    model:SetAttribute(DRIVE_ATTR, true)
    local root = model.PrimaryPart
    if root then
        -- El conductor es el dueno de la fisica: asi ve su propio movimiento
        -- sin latencia. Es el mismo criterio que un asiento de Roblox normal.
        pcall(function()
            local assemblyRoot = root.AssemblyRootPart or root
            assemblyRoot:SetNetworkOwner(player)
        end)
    end
    setLegsCollision(player, false)
end

local function onDismounted(player, model)
    if not model.Parent then
        return
    end
    model:SetAttribute(DRIVE_ATTR, false)
    setAnchored(model, true)
    setLegsCollision(player, true)
end

--[[ Devuelve el Player que ocupa el asiento (o nil). ]]
local function seatRider(seat)
    local humanoid = seat.Occupant
    if not humanoid then
        return nil
    end
    local character = humanoid.Parent
    return character and Players:GetPlayerFromCharacter(character) or nil
end

local function watchSeat(player, model, seat, entry)
    if not seat then
        return
    end
    entry.conn = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        local rider = seatRider(seat)
        if rider == nil then
            onDismounted(player, model)
        elseif rider == player then
            onMounted(player, model)
        else
            -- Solo el DUENO puede conducirlo: cualquiera podria subirse tocando
            -- el asiento, asi que aqui se le baja sin mas.
            local humanoid = seat.Occupant
            if humanoid and humanoid.Parent then
                humanoid.Sit = false
            end
        end
    end)
end

--[[ Baja al conductor (si lo hay) antes de borrar el vehiculo. ]]
local function kickRider(entry)
    local seat = entry.seat
    local humanoid = seat and seat.Occupant
    if humanoid and humanoid.Parent then
        humanoid.Sit = false
    end
end

-- API -------------------------------------------------------------------------

--[[ Compra un vehiculo. Idempotente: si ya lo tiene no cobra y solo avisa. ]]
function VehicleService.Purchase(player, vehicleId)
    if type(vehicleId) ~= "string" then
        return
    end
    local cfg = VehicleConfig.Get(vehicleId)
    if not cfg then
        return
    end
    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end

    local now = os.clock()
    if lastPurchaseAt[player] and now - lastPurchaseAt[player] < GameConfig.VehiclePurchaseCooldown then
        return
    end
    lastPurchaseAt[player] = now

    if profile.vehicles[vehicleId] then
        notify(player, "Ya tienes el " .. cfg.name .. ". Puedes desplegarlo cuando quieras.", WARN)
        PlayerDataService.Sync(player, { puffs = profile.puffs, vehicles = profile.vehicles })
        return
    end

    local price = VehicleConfig.Price(vehicleId)
    if profile.puffs < price then
        notify(player, ("Te faltan %d Puffs para el %s."):format(price - profile.puffs, cfg.name), BAD)
        return
    end

    -- Cobro + entrega en el servidor y guardado inmediato.
    profile.puffs -= price
    profile.vehicles[vehicleId] = true
    PlayerDataService.Save(player)
    PlayerDataService.Sync(player, {
        puffs = profile.puffs,
        vehicles = profile.vehicles,
    })
    notify(player, ("Has comprado el %s! Ya puedes desplegarlo."):format(cfg.name), OK)
end

--[[ Despliega un vehiculo ya comprado al lado del jugador. ]]
function VehicleService.Spawn(player, vehicleId)
    if type(vehicleId) ~= "string" then
        return
    end
    local cfg = VehicleConfig.Get(vehicleId)
    if not cfg then
        return
    end
    local profile = PlayerDataService.Get(player)
    if not profile then
        return
    end

    if not profile.vehicles[vehicleId] then
        notify(player, "No tienes ese vehiculo. Compralo primero.", BAD)
        return
    end

    local now = os.clock()
    if lastSpawnAt[player] and now - lastSpawnAt[player] < GameConfig.VehicleSpawnCooldown then
        return
    end
    lastSpawnAt[player] = now

    if not getRoot(player) then
        notify(player, "Necesitas estar vivo para desplegar un vehiculo.", BAD)
        return
    end

    -- Limite: un vehiculo activo por jugador (nada de copias infinitas).
    local current = active[player]
    if current then
        if current.model and current.model.Parent then
            notify(player, "Ya tienes el " .. (VehicleConfig.Get(current.id) or cfg).name
                .. " desplegado. Guardalo antes de sacar otro.", WARN)
            PlayerDataService.Sync(player, { activeVehicle = current.id })
            return
        end
        active[player] = nil
    end

    local model = VehicleFactory.Build(vehicleId)
    if not model then
        return
    end

    local extents = model:GetExtentsSize()
    local spot = findSpot(player, extents)
    if not spot then
        model:Destroy()
        notify(player, "No hay sitio libre a tu lado. Muevete a un espacio abierto.", WARN)
        return
    end

    model:SetAttribute("OwnerUserId", player.UserId)
    model:PivotTo(spot)
    model.Parent = folder()
    setAnchored(model, true)

    local seat = model:FindFirstChild("Seat")
    local entry = { model = model, id = vehicleId, seat = seat }
    active[player] = entry
    watchSeat(player, model, seat, entry)

    PlayerDataService.Sync(player, { activeVehicle = vehicleId })
    notify(player, ("%s desplegado. Subete y conduce con WASD."):format(cfg.name), OK)
end

--[[ Guarda / retira el vehiculo desplegado. La propiedad NO se pierde. ]]
function VehicleService.Despawn(player, silent)
    local now = os.clock()
    if lastStoreAt[player] and now - lastStoreAt[player] < GameConfig.VehicleStoreCooldown then
        return
    end
    lastStoreAt[player] = now

    local entry = active[player]
    active[player] = nil
    if not entry then
        if not silent then
            notify(player, "No tienes ningun vehiculo desplegado.", WARN)
        end
        PlayerDataService.Sync(player, { activeVehicle = false })
        return
    end

    if entry.conn then
        entry.conn:Disconnect()
    end
    kickRider(entry)
    setLegsCollision(player, true)
    if entry.model then
        entry.model:Destroy()
    end

    PlayerDataService.Sync(player, { activeVehicle = false })
    if not silent then
        notify(player, "Vehiculo guardado. Puedes volver a desplegarlo cuando quieras.", INFO)
    end
end

function VehicleService.GetActive(player)
    return active[player] and active[player].id or false
end

function VehicleService.Release(player)
    local entry = active[player]
    if entry and entry.conn then
        entry.conn:Disconnect()
    end
    if entry and entry.model then
        entry.model:Destroy()
    end
    active[player] = nil
    lastPurchaseAt[player] = nil
    lastSpawnAt[player] = nil
    lastStoreAt[player] = nil
    setLegsCollision(player, true)
end

-- Ciclo de vida ---------------------------------------------------------------

--[[ Conexiones por jugador. Usa un atributo como marca para no duplicar
     conexiones si el script se recarga (Studio) o el jugador reaparece. ]]
local function watchPlayer(player)
    if watched[player] or player:GetAttribute("HTV_VehicleWatcher") == true then
        return
    end
    watched[player] = true
    player:SetAttribute("HTV_VehicleWatcher", true)

    local function onCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then
            humanoid.Died:Connect(function()
                -- Al morir se limpia el vehiculo: es temporal, no se guarda.
                VehicleService.Despawn(player, true)
            end)
        end
    end
    player.CharacterAdded:Connect(onCharacter)
    if player.Character then
        task.spawn(onCharacter, player.Character)
    end
end

function VehicleService.Init()
    Net.get("PurchaseVehicle").OnServerEvent:Connect(function(player, vehicleId)
        VehicleService.Purchase(player, vehicleId)
    end)
    Net.get("SpawnVehicle").OnServerEvent:Connect(function(player, vehicleId)
        VehicleService.Spawn(player, vehicleId)
    end)
    Net.get("DespawnVehicle").OnServerEvent:Connect(function(player)
        VehicleService.Despawn(player, false)
    end)

    -- Prompts "SUBIR" de los patinetes desplegados.
    ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
        if prompt:GetAttribute("PromptType") ~= "Vehicle" then
            return
        end
        local seat = prompt.Parent
        if not (seat and seat:IsA("VehicleSeat")) then
            return
        end
        local model = seat:FindFirstAncestorOfClass("Model")
        if not model or model:GetAttribute("OwnerUserId") ~= player.UserId then
            return
        end
        local root, humanoid = getRoot(player)
        if not root then
            return
        end
        if (root.Position - seat.Position).Magnitude > 14 then
            return
        end
        seat:Sit(humanoid)
    end)

    Players.PlayerAdded:Connect(watchPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(watchPlayer, player)
    end

    -- Vigilancia: nada de vehiculos perdidos bajo el mapa ni huerfanos.
    task.spawn(function()
        while true do
            task.wait(1.5)
            for player, entry in pairs(active) do
                local model = entry.model
                local root = model and model.PrimaryPart
                if not model or not model.Parent or not root then
                    active[player] = nil
                    PlayerDataService.Sync(player, { activeVehicle = false })
                elseif root.Position.Y < GameConfig.VehicleFallLimit or not player.Parent then
                    VehicleService.Despawn(player, true)
                    if player.Parent then
                        notify(player, "Tu vehiculo se ha perdido. Vuelve a desplegarlo.", WARN)
                    end
                end
            end
        end
    end)
end

return VehicleService
