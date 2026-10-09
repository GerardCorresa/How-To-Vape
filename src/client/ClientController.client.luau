--[[
    ClientController
    Ruta en Roblox Studio: StarterPlayer > StarterPlayerScripts > ClientController
    Tipo: LocalScript

    Cerebro del cliente:
      * construye la interfaz (via UIModule)
      * envia las intenciones al servidor (PUFF, comprar, equipar, descubrir
        distrito, desbloquear casa)
      * reproduce los efectos locales (humo, animacion de brazo via PuffAnimator)
      * anima los vapes equipados de todos los jugadores (anillos y RGB)
      * abre tienda/inventario/vehiculos/mapa/misiones y pinta las listas
      * reacciona a ProximityPrompt de dealers, casas y arcos de distrito
      * abre/cierra las puertas EN LOCAL segun el acceso del jugador (DoorClient)
      * sprint con SHIFT IZQUIERDO (MovementController) y conduccion del
        patinete (VehicleController)

    El cliente NO decide economia: solo refleja lo que confirma el servidor.

    Requiere: UIModule, PuffAnimator, DoorClient, MovementController y
              VehicleController (mismo directorio), GameConfig, VapeConfig,
              VehicleConfig, ZoneConfig, VapeFactory, Net.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local VapeConfig = require(Shared:WaitForChild("VapeConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local MissionConfig = require(Shared:WaitForChild("MissionConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))
local VapeFactory = require(Shared:WaitForChild("VapeFactory"))
local Net = require(Shared:WaitForChild("Net"))

local UIModule = require(script.Parent:WaitForChild("UIModule"))
local PuffAnimator = require(script.Parent:WaitForChild("PuffAnimator"))
local DoorClient = require(script.Parent:WaitForChild("DoorClient"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))
local VehicleController = require(script.Parent:WaitForChild("VehicleController"))

local player = Players.LocalPlayer
local C = UIModule.Colors

local remotes = {
    PuffRequest = Net.get("PuffRequest"),
    PurchaseVape = Net.get("PurchaseVape"),
    EquipVape = Net.get("EquipVape"),
    UnlockZone = Net.get("UnlockZone"),
    UnlockHouse = Net.get("UnlockHouse"),
    PurchaseVehicle = Net.get("PurchaseVehicle"),
    SpawnVehicle = Net.get("SpawnVehicle"),
    DespawnVehicle = Net.get("DespawnVehicle"),
}

-- Estado local espejo del servidor -------------------------------------------
local state = {
    puffs = 0,
    owned = { [GameConfig.DefaultVapeId] = true },
    equipped = GameConfig.DefaultVapeId,
    vehicles = {},
    activeVehicle = false,
    zones = { starter_block = true },
    houses = {},
    discovered = {},
    missions = {},
    stats = { totalPuffs = 0, puffsClicked = 0, housesUnlocked = 0, districtsDiscovered = 1, vapesOwned = 1 },
    ready = false,
}

local puffCooldownUntil = 0

-- Utilidades ------------------------------------------------------------------
local function getCharacter()
    return player.Character
end

local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function distanceToPlayer(position)
    local root = getRoot(getCharacter())
    if not root or typeof(position) ~= "Vector3" then
        return math.huge
    end
    return (root.Position - position).Magnitude
end

local function equippedCfg()
    return VapeConfig.Vapes[state.equipped] or VapeConfig.Vapes[GameConfig.DefaultVapeId]
end

local function countKeys(map)
    local n = 0
    for _ in pairs(map) do n += 1 end
    return n
end

local function houseName(houseId)
    local house = houseId and ZoneConfig.Houses[houseId]
    return house and house.name or "?"
end

-- Refresco de HUD --------------------------------------------------------------
local function refreshHUD()
    UIModule.SetPuffs(state.puffs)
    UIModule.SetRate(equippedCfg().multiplier)
    UIModule.SetEquipped(equippedCfg())

    -- Progreso hacia el siguiente acceso de casa (el gating economico real).
    local nextHouse = ZoneConfig.GetNextHouse(state.houses)
    if nextHouse then
        UIModule.SetProgress("Siguiente: " .. nextHouse.name, state.puffs, nextHouse.requirement)
    else
        UIModule.SetProgress("Todas las casas abiertas", 1, 1)
    end
end

-- Efectos locales del PUFF -----------------------------------------------------
local function playPuffEffects()
    PuffAnimator.play(getCharacter())
end

-- Inicializacion ---------------------------------------------------------------
local ui = UIModule.Build()
PuffAnimator.init()
DoorClient.Init()
MovementController.Init()      -- sprint con SHIFT IZQUIERDO
VehicleController.Init()       -- conduccion del patinete

-- Boton PUFF -------------------------------------------------------------------
ui.puffButton.MouseButton1Click:Connect(function()
    if not state.ready then
        return
    end
    local now = os.clock()
    if now < puffCooldownUntil then
        return
    end
    puffCooldownUntil = now + GameConfig.PuffClientCooldown

    playPuffEffects()
    remotes.PuffRequest:FireServer()

    UIModule.SetCooldown(1)
    local tween = TweenService:Create(ui.cooldownFill, TweenInfo.new(GameConfig.PuffClientCooldown, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })
    tween:Play()
    task.delay(GameConfig.PuffClientCooldown, function()
        UIModule.SetCooldown(0)
    end)
end)

-- Tarjetas de producto (tienda e inventario) ----------------------------------
local function rarityColor(cfg)
    return EconomyConfig.RarityColor(cfg.id)
end

--[[ Rellena una rejilla con tarjetas de vaper usando el estilo del inventario.
     `mode` = "shop" (solo stock del dealer) o "inventory" (los 15 vapers). ]]
local function fillCards(list, stock, mode)
    for _, cfg in ipairs(stock) do
        local card = UIModule.MakeVapeCard(list, cfg)
        local owned = state.owned[cfg.id] == true
        local equipped = state.equipped == cfg.id
        local price = cfg.price or 0
        local affordable = state.puffs >= price
        local onAction = nil
        if owned then
            onAction = function()
                remotes.EquipVape:FireServer(cfg.id)
            end
        else
            onAction = function()
                remotes.PurchaseVape:FireServer(cfg.id)
            end
        end

        local info
        if mode == "inventory" and not owned then
            local district = ZoneConfig.Districts[cfg.district]
            info = ("Precio: %d Puffs · %s · %s"):format(price, houseName(cfg.house),
                district and district.name or "?")
        end

        card.setState({
            owned = owned,
            equipped = equipped,
            price = price,
            puffs = state.puffs,
            locked = (not owned) and (not affordable),
            accent = rarityColor(cfg),
            info = info,
            onAction = onAction,
        })
    end
end

-- Tienda -----------------------------------------------------------------------
local currentShopHouse = nil

local function renderShop(houseId)
    local house = ZoneConfig.Houses[houseId]
    if not house then
        return
    end
    currentShopHouse = houseId
    UIModule.ClearShop()
    UIModule.OpenShop(("DEALER %s · %s"):format(house.dealer.name, house.name), "Toca una tarjeta para equipar o comprar")

    if not state.houses[houseId] then
        UIModule.SetShopHint(("Esta casa esta bloqueada. Desbloquea el acceso a %s (%d Puffs).")
            :format(house.name, house.requirement or 0), C.bad)
        return
    end

    local stock = VapeConfig.ByHouse(houseId)
    if #stock == 0 then
        UIModule.SetShopHint(house.dealer.line, C.text)
        return
    end
    UIModule.SetShopHint(("Precios en Puffs · tienes %d"):format(state.puffs), C.subtext)
    fillCards(UIModule.GetShopList(), stock, "shop")
end

-- Inventario -------------------------------------------------------------------
local function renderInventory()
    UIModule.ClearInventory()
    UIModule.OpenInventory()

    local ordered = VapeConfig.GetOrdered()
    fillCards(UIModule.GetInventoryList(), ordered, "inventory")
    UIModule.SetInventorySummary(
        ("%d de %d vapers desbloqueados · %d Puffs"):format(countKeys(state.owned), #ordered, state.puffs),
        C.subtext)
end

-- Modal de casa ----------------------------------------------------------------
local function openHouseModal(houseId)
    local house = ZoneConfig.Houses[houseId]
    if not house then
        return
    end
    local cost = house.requirement or 0
    UIModule.OpenHouseModal({
        title = house.name,
        cost = cost,
        puffs = state.puffs,
        missing = math.max(0, cost - state.puffs),
        unlocked = state.houses[houseId] == true,
        dealerName = house.dealer.name,
        district = house.district,
    }, function()
        UIModule.CloseHouseModal()
        remotes.UnlockHouse:FireServer(houseId)
    end)
end

-- Mapa y misiones --------------------------------------------------------------
local function toggleMap()
    if UIModule.IsMapOpen() then
        UIModule.CloseMap()
    else
        UIModule.RenderMap(state)
        UIModule.OpenMap()
    end
end

local function missionValues()
    return {
        puffsClicked = state.stats.puffsClicked or 0,
        totalPuffs = state.stats.totalPuffs or 0,
        districts = countKeys(state.zones),
        houses = countKeys(state.houses),
        vapes = countKeys(state.owned),
        puffs = state.puffs,
    }
end

local function toggleMissions()
    if UIModule.IsMissionsOpen() then
        UIModule.CloseMissions()
    else
        UIModule.RenderMissions(missionValues(), state.missions)
        UIModule.OpenMissions()
    end
end

-- Tienda de dealer (accesible desde el menu y desde el dock) -------------------
local function nearestUnlockedDealer()
    local best, bestDist = nil, math.huge
    for _, houseId in ipairs(ZoneConfig.HouseOrder) do
        if state.houses[houseId] then
            local house = ZoneConfig.Houses[houseId]
            local d = distanceToPlayer(house.position)
            if d < bestDist then
                best, bestDist = house, d
            end
        end
    end
    if best and bestDist <= GameConfig.DealerRange then
        return best
    end
    return nil
end

local function toggleShop()
    if UIModule.IsShopOpen() then
        UIModule.CloseShop()
        return
    end
    local house = nearestUnlockedDealer()
    if house then
        renderShop(house.id)
    else
        UIModule.Notify("Acercate a un DEALER para abrir su tienda.", C.warn)
    end
end

local function toggleInventory()
    if UIModule.IsInventoryOpen() then
        UIModule.CloseInventory()
    else
        renderInventory()
    end
end

-- Vehiculos --------------------------------------------------------------------
--[[ Repinta el menu de vehiculos con el estado real del jugador. La propiedad y
     el despliegue los confirma SIEMPRE el servidor: aqui solo se pinta y se
     envian las intenciones. ]]
local function renderVehicles()
    UIModule.ClearVehicles()
    UIModule.OpenVehicles()

    local owned = 0
    for _, cfg in ipairs(VehicleConfig.GetOrdered()) do
        local isOwned = state.vehicles[cfg.id] == true
        local isActive = state.activeVehicle == cfg.id
        if isOwned then
            owned += 1
        end

        local card = UIModule.MakeVehicleCard(UIModule.GetVehiclesList(), cfg)
        card.setState({
            owned = isOwned,
            active = isActive,
            price = VehicleConfig.Price(cfg.id),
            puffs = state.puffs,
            accent = VehicleConfig.Accent(cfg.id),
            onBuy = function()
                remotes.PurchaseVehicle:FireServer(cfg.id)
            end,
            onDeploy = function()
                remotes.SpawnVehicle:FireServer(cfg.id)
                -- Cerramos para que el jugador pueda subirse enseguida: el
                -- vehiculo aparece a su lado.
                UIModule.CloseVehicles()
            end,
            onStore = function()
                remotes.DespawnVehicle:FireServer()
            end,
        })
    end

    local hint
    if state.activeVehicle then
        hint = ("%s desplegado. Subete y conduce con WASD · ESPACIO para bajarte."):format(
            (VehicleConfig.Get(state.activeVehicle) or {}).name or "Vehiculo")
    elseif owned > 0 then
        hint = ("%d de %d vehiculos comprados · %d Puffs"):format(owned, #VehicleConfig.Order, state.puffs)
    else
        hint = ("Compra tu primer vehiculo · tienes %d Puffs"):format(state.puffs)
    end
    UIModule.SetVehiclesSummary(hint, owned > 0 and C.subtext or C.muted)
end

local function toggleVehicles()
    if UIModule.IsVehiclesOpen() then
        UIModule.CloseVehicles()
    else
        renderVehicles()
    end
end

local function toggleControls()
    if UIModule.IsControlsOpen() then
        UIModule.CloseControls()
    else
        UIModule.OpenControls()
    end
end

-- Botones del dock lateral (siempre visibles, nunca tapan el boton PUFF) -------
ui.inventoryButton.MouseButton1Click:Connect(toggleInventory)
ui.vehiclesButton.MouseButton1Click:Connect(toggleVehicles)
ui.menuButton.MouseButton1Click:Connect(function()
    UIModule.ToggleMenu()
end)

-- Opciones del menu principal --------------------------------------------------
if ui.menuShopButton then
    ui.menuShopButton.MouseButton1Click:Connect(toggleShop)
end
if ui.menuInventoryButton then
    ui.menuInventoryButton.MouseButton1Click:Connect(toggleInventory)
end
if ui.menuVehiclesButton then
    ui.menuVehiclesButton.MouseButton1Click:Connect(toggleVehicles)
end
if ui.menuMapButton then
    ui.menuMapButton.MouseButton1Click:Connect(toggleMap)
end
if ui.menuMissionsButton then
    ui.menuMissionsButton.MouseButton1Click:Connect(toggleMissions)
end
if ui.menuControlsButton then
    ui.menuControlsButton.MouseButton1Click:Connect(toggleControls)
end

-- Atajos de teclado y cierre con ESC -------------------------------------------
local UserInputService = game:GetService("UserInputService")
local keybinds = UIModule.Keybinds

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.Escape then
        if UIModule.IsAnyPanelOpen() then
            UIModule.CloseAllPanels()
        end
        return
    end
    if UserInputService:GetFocusedTextBox() then
        return
    end
    if input.KeyCode == Enum.KeyCode[keybinds.inventory] then
        toggleInventory()
    elseif input.KeyCode == Enum.KeyCode[keybinds.vehicles] then
        toggleVehicles()
    elseif input.KeyCode == Enum.KeyCode[keybinds.menu] then
        UIModule.ToggleMenu()
    elseif input.KeyCode == Enum.KeyCode[keybinds.map] then
        toggleMap()
    elseif input.KeyCode == Enum.KeyCode[keybinds.missions] then
        toggleMissions()
    end
end)

-- Interaccion con dealers, casas y arcos ---------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
    if triggerPlayer ~= player then
        return
    end
    local promptType = prompt:GetAttribute("PromptType")
    local zoneId = prompt:GetAttribute("ZoneId")
    local houseId = prompt:GetAttribute("HouseId")
    if promptType == "Dealer" and zoneId then
        renderShop(zoneId)
    elseif promptType == "House" and houseId then
        openHouseModal(houseId)
    elseif promptType == "Gate" and zoneId then
        remotes.UnlockZone:FireServer(zoneId)
    end
end)

-- Sincronizacion desde el servidor ---------------------------------------------
Net.get("SyncData").OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then
        return
    end
    if payload.init then
        state.ready = true
    end
    if payload.puffs then
        state.puffs = payload.puffs
    end
    if payload.owned then
        state.owned = payload.owned
    end
    if payload.equipped then
        state.equipped = payload.equipped
    end
    if payload.vehicles then
        state.vehicles = payload.vehicles
    end
    if payload.activeVehicle ~= nil then
        state.activeVehicle = payload.activeVehicle
    end
    if payload.zones then
        state.zones = payload.zones
    end
    if payload.houses then
        state.houses = payload.houses
        DoorClient.SetUnlocked(state.houses)
    end
    if payload.discovered then
        state.discovered = payload.discovered
    end
    if payload.missions then
        state.missions = payload.missions
    end
    if payload.stats then
        state.stats = payload.stats
    end

    refreshHUD()

    -- Refresca paneles abiertos
    if UIModule.IsInventoryOpen() then
        renderInventory()
    end
    if UIModule.IsShopOpen() and currentShopHouse then
        renderShop(currentShopHouse)
    end
    if UIModule.IsVehiclesOpen() then
        renderVehicles()
    end
    if UIModule.IsMapOpen() then
        UIModule.RenderMap(state)
    end
    if UIModule.IsMissionsOpen() then
        UIModule.RenderMissions(missionValues(), state.missions)
    end
end)

Net.get("Notify").OnClientEvent:Connect(function(data)
    if type(data) == "table" and data.text then
        UIModule.Notify(data.text, data.color)
    end
end)

-- Caladas de OTROS jugadores ---------------------------------------------------
Net.get("PuffBroadcast").OnClientEvent:Connect(function(data)
    if type(data) ~= "table" or not data.userId then
        return
    end
    if data.userId == player.UserId then
        return
    end
    local other = Players:GetPlayerByUserId(data.userId)
    if other and other.Character then
        PuffAnimator.play(other.Character)
    end
end)

-- Animacion de los vapes equipados (anillos + RGB) ----------------------------
local trackedModels = {}

local function trackModel(model)
    if trackedModels[model] then
        return
    end
    local spinners, rgbParts = {}, {}
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            local speed = desc:GetAttribute("SpinSpeed")
            if speed and desc:FindFirstChild("SpinMotor") then
                local motor = desc:FindFirstChild("SpinMotor")
                table.insert(spinners, { motor = motor, base = motor.C0, speed = speed, theta = 0 })
            end
            local rgbSpeed = desc:GetAttribute("RGBSpeed")
            if rgbSpeed then
                table.insert(rgbParts, { part = desc, speed = rgbSpeed, hue = 0 })
            end
        end
    end
    trackedModels[model] = { spinners = spinners, rgbParts = rgbParts }
end

local function untrackModel(model)
    trackedModels[model] = nil
end

for _, model in ipairs(CollectionService:GetTagged("VapeModel")) do
    trackModel(model)
end
CollectionService:GetInstanceAddedSignal("VapeModel"):Connect(trackModel)
CollectionService:GetInstanceRemovedSignal("VapeModel"):Connect(untrackModel)

RunService.RenderStepped:Connect(function(dt)
    for model, data in pairs(trackedModels) do
        if not model.Parent then
            trackedModels[model] = nil
            continue
        end
        for _, s in ipairs(data.spinners) do
            s.theta += s.speed * dt
            s.motor.C0 = s.base * CFrame.Angles(0, s.theta, 0)
        end
        for _, r in ipairs(data.rgbParts) do
            r.hue = (r.hue + r.speed * dt * 0.25) % 1
            r.part.Color = Color3.fromHSV(r.hue, 1, 1)
        end
    end
end)

refreshHUD()
UIModule.Notify("Bienvenido a HOW TO VAPE. Explora la ciudad y encuentra casas de dealers.", C.accent)
