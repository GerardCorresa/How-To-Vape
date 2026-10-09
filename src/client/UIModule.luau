--[[
    UIModule
    Ruta en Roblox Studio: StarterPlayer > StarterPlayerScripts > UIModule
    Tipo: ModuleScript (se ejecuta en el cliente)

    Construye TODA la interfaz por codigo usando el sistema de diseno UITheme:

      * BARRA PRINCIPAL: contador de Puffs con icono, vaper equipado con su
        multiplicador y rareza, y progreso hacia el siguiente desbloqueo.
      * PUFF: boton grande abajo en el centro, siempre libre.
      * DOCK lateral derecho (centrado en vertical): MENU, VAPERS y VEHICULOS.
        Al estar en el borde derecho y el boton PUFF en el centro, NUNCA se
        solapan, en ninguna resolucion.
      * El apartado de TIENDA de la parte inferior se elimino: ahora la tienda
        vive dentro del MENU y en el panel de cada dealer (mismo aspecto).
      * VEHICULOS: tarjetas con previsualizacion 3D del modelo real
        (VehicleFactory), nombre, estado (bloqueado/disponible/comprado/
        desplegado), precio en Puffs y botones de comprar, sacar a la calle y
        guardar. Se genera desde VehicleConfig: anadir un vehiculo no obliga a
        tocar la interfaz.
      * INVENTARIO: rejilla de tarjetas (UIGridLayout que se adapta al ancho),
        con previsualizacion 3D, multiplicador, rareza, precio, puffs que faltan,
        boton de equipar/comprar y marca clara del vaper equipado.
      * MENU, MAPA, MISIONES, CONTROLES y modal de casa con la misma identidad.
      * Notificaciones con acento de color y animacion.

    Expone una API sencilla que ClientController usa.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VapeConfig = require(Shared:WaitForChild("VapeConfig"))
local VapeFactory = require(Shared:WaitForChild("VapeFactory"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local MissionConfig = require(Shared:WaitForChild("MissionConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local CityGrid = require(Shared:WaitForChild("CityGrid"))

local Theme = require(script.Parent:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIModule = {}
local C = Theme.C

--[[ Paleta publica: ClientController la usa para pintar textos y botones con los
     mismos colores que el resto de la interfaz. `accent` es el cian de marca. ]]
UIModule.Colors = {
    bg = C.bg, panel = C.panel, panel2 = C.panel2, panelHi = C.panelHi, line = C.line,
    text = C.text, subtext = C.subtext, muted = C.muted,
    accent = C.cyan, cyan = C.cyan, blue = C.blue, purple = C.purple, pink = C.pink,
    good = C.good, warn = C.warn, bad = C.bad, dark = C.dark,
}

local refs = {}
local activePreviews = {}
local modalRegistry = {}

--[[ Registra un modal creado con Theme.modal. refs["XFrame"] queda apuntando al
     Frame y refs["XModal"] a la API (SetVisible), que es lo que usa el resto del
     codigo para abrir y cerrar paneles. ]]
local function registerModal(key, modal)
    refs[key] = modal.frame
    refs[(key:gsub("Frame$", "Modal"))] = modal
    modalRegistry[key] = modal
    return modal
end

--[[ modalRegistry guarda la API de cada modal creado con registerModal. ]]
local function setVisible(modal, visible)
    if modal and modal.SetVisible then
        modal.SetVisible(visible)
    end
end

-- Escala del mapa: mundo [-1000,1000] -> area [0, MAP_SIZE]
local WORLD_HALF = 1000
local MAP_SIZE = 380

-- Atajos de teclado (el ClientController los usa para que no se desincronicen)
UIModule.Keybinds = { inventory = "I", menu = "M", map = "K", missions = "J", vehicles = "V" }

-- Helpers ---------------------------------------------------------------------
local mk = Theme.new

local function worldToMap(x, z)
    return (x + WORLD_HALF) / (WORLD_HALF * 2) * MAP_SIZE, (z + WORLD_HALF) / (WORLD_HALF * 2) * MAP_SIZE
end

--[[ Previsualizacion 3D girando dentro de un ViewportFrame.
     `opts` = { radius, height, target } ajusta la orbita de la camara: los
     vapers son pequenos y bajos, los vehiculos mas grandes y altos. ]]
local function buildPreview(model, size, opts)
    opts = opts or {}
    local vf = mk("ViewportFrame", {
        Size = size,
        BackgroundColor3 = Color3.fromRGB(11, 13, 22),
        BorderSizePixel = 0,
        Ambient = Color3.fromRGB(170, 172, 196),
        LightColor = Color3.fromRGB(255, 255, 255),
        ZIndex = 26,
    }, nil)
    Theme.corner(vf, Theme.Radius.md)
    Theme.stroke(vf, C.line, 1.2, 0.2)

    if model then
        model.Parent = vf
    end

    local cam = Instance.new("Camera")
    cam.FieldOfView = opts.fov or 40
    vf.CurrentCamera = cam
    cam.Parent = vf

    table.insert(activePreviews, {
        viewport = vf,
        camera = cam,
        angle = opts.angle or 0,
        radius = opts.radius or 5,
        height = opts.height or 0.4,
        target = opts.target or Vector3.new(0, 0, 0),
        speed = opts.speed or 0.55,
    })
    return vf
end

--[[ Previsualizacion de un vaper (compatibilidad con el codigo existente). ]]
local function buildVapePreview(vapeId, size)
    return buildPreview(VapeFactory.Build(vapeId), size)
end

--[[ Previsualizacion de un vehiculo: orbita mas amplia y centrada en el cuerpo
     del vehiculo (el origen del modelo esta en el suelo). ]]
local function buildVehiclePreview(vehicleId, size)
    return buildPreview(VehicleFactory.Build(vehicleId), size, {
        radius = 8.5,
        height = 3.0,
        target = Vector3.new(0, 1.3, 0),
        fov = 34,
        angle = 0.7,
        speed = 0.4,
    })
end

-- Barra principal --------------------------------------------------------------

local function buildPuffCard(screen)
    local card = Theme.panel({
        Name = "PuffCard", Size = UDim2.fromOffset(330, 96),
        Position = UDim2.fromOffset(18, 18), BackgroundColor3 = C.panel,
        _accent = C.cyan, ZIndex = 5,
    }, screen)
    Theme.autoScale(card, 1500, 900, 0.78, 1.05)

    local icon = mk("Frame", {
        Name = "PuffIcon", Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0, 16, 0.5, -29),
        BackgroundColor3 = C.cyan, BorderSizePixel = 0, ZIndex = 6,
    }, card)
    Theme.corner(icon, Theme.Radius.md)
    Theme.gradient(icon, C.cyan, C.blue, 90)
    mk("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "💨",
        TextScaled = true, Font = Theme.Font.Black, ZIndex = 7,
    }, icon)

    refs.puffLabel = mk("TextLabel", {
        Name = "PuffCount", Size = UDim2.new(1, -100, 0, 46), Position = UDim2.fromOffset(88, 12),
        BackgroundTransparency = 1, Text = "0", TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Black, TextScaled = true, TextColor3 = C.text, ZIndex = 6,
    }, card)
    Theme.new("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 18 }, refs.puffLabel)

    refs.puffRate = mk("TextLabel", {
        Size = UDim2.new(1, -100, 0, 22), Position = UDim2.fromOffset(90, 60),
        BackgroundTransparency = 1, Text = "+1 por calada", TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Med, TextSize = 14, TextColor3 = C.subtext, ZIndex = 6,
    }, card)

    return card
end

local function buildProgressCard(screen)
    local card = Theme.panel({
        Name = "ProgressCard", Size = UDim2.fromOffset(330, 82),
        Position = UDim2.fromOffset(18, 124), BackgroundColor3 = C.panel,
        _accent = C.purple, ZIndex = 5,
    }, screen)
    Theme.autoScale(card, 1500, 900, 0.78, 1.05)

    refs.progressTitle = mk("TextLabel", {
        Size = UDim2.new(1, -28, 0, 20), Position = UDim2.fromOffset(14, 10),
        BackgroundTransparency = 1, Text = "Siguiente distrito", TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Bold, TextSize = 14, TextColor3 = C.text, ZIndex = 6,
    }, card)

    local bar = mk("Frame", {
        Name = "Bar", Size = UDim2.new(1, -28, 0, 12), Position = UDim2.fromOffset(14, 36),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 6,
    }, card)
    Theme.corner(bar, 6)
    refs.progressFill = mk("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.purple, BorderSizePixel = 0, ZIndex = 7,
    }, bar)
    Theme.corner(refs.progressFill, 6)
    Theme.gradient(refs.progressFill, C.purple, C.cyan, 0)

    refs.progressText = mk("TextLabel", {
        Size = UDim2.new(1, -28, 0, 18), Position = UDim2.fromOffset(14, 52),
        BackgroundTransparency = 1, Text = "0 / 250", TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Med, TextSize = 13, TextColor3 = C.subtext, ZIndex = 6,
    }, card)

    return card
end

local function buildEquipCard(screen)
    local card = Theme.panel({
        Name = "EquipCard", Size = UDim2.fromOffset(316, 96),
        Position = UDim2.new(1, -18, 0, 18), AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = C.panel, _accent = C.good, ZIndex = 5,
    }, screen)
    Theme.autoScale(card, 1500, 900, 0.78, 1.05)

    refs.equipPreview = buildVapePreview("basic", UDim2.fromOffset(74, 74))
    refs.equipPreview.Position = UDim2.new(0, 14, 0.5, -37)
    refs.equipPreview.Parent = card

    refs.equipName = mk("TextLabel", {
        Name = "EquipName", Size = UDim2.new(1, -108, 0, 26), Position = UDim2.fromOffset(100, 14),
        BackgroundTransparency = 1, Text = "BASIC VAPE", TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Bold, TextSize = 18, TextColor3 = C.text, TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, card)

    refs.equipMult = mk("TextLabel", {
        Size = UDim2.new(1, -108, 0, 22), Position = UDim2.fromOffset(100, 42),
        BackgroundTransparency = 1, Text = "x1 Puffs", TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Bold, TextSize = 16, TextColor3 = C.cyan, ZIndex = 6,
    }, card)

    refs.equipRarity = mk("TextLabel", {
        Size = UDim2.new(1, -108, 0, 18), Position = UDim2.fromOffset(100, 66),
        BackgroundTransparency = 1, Text = "COMUN", TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Med, TextSize = 12, TextColor3 = C.subtext, ZIndex = 6,
    }, card)

    return card
end

--[[ Boton del dock lateral: icono grande + pie con el nombre. ]]
local function dockButton(parent, opts)
    local b = Theme.button({
        Size = UDim2.fromOffset(74, 68), BackgroundColor3 = C.panel2, Variant = "ghost",
        Accent = opts.accent, ZIndex = 6, Name = opts.name, _corner = Theme.Radius.md,
    }, parent)
    b.Text = ""
    local icon = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 6),
        BackgroundTransparency = 1, Text = opts.icon, TextScaled = true, Font = Theme.Font.Black,
        TextColor3 = opts.accent, ZIndex = 7,
    }, b)
    Theme.new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 14 }, icon)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -20),
        BackgroundTransparency = 1, Text = opts.caption, Font = Theme.Font.Bold, TextSize = 11,
        TextColor3 = C.subtext, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7,
    }, b)
    return b
end

local function buildDock(screen)
    -- Dock en el borde DERECHO, centrado en vertical: no coincide nunca con el
    -- boton PUFF (centro-abajo) ni con los controles tactiles de Roblox.
    local dock = mk("Frame", {
        Name = "Dock", Size = UDim2.fromOffset(74, 0), Position = UDim2.new(1, -18, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5,
    }, screen)
    Theme.autoScale(dock, 1500, 900, 0.78, 1.05)
    Theme.new("UIListLayout", {
        Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, dock)

    refs.menuButton = dockButton(dock, { icon = "☰", caption = "MENU", accent = C.cyan, name = "MenuButton" })
    refs.inventoryButton = dockButton(dock, { icon = "🎒", caption = "VAPERS", accent = C.purple, name = "InventoryButton" })
    refs.vehiclesButton = dockButton(dock, { icon = "🛴", caption = "VEHICULOS", accent = C.pink, name = "VehiclesButton" })
    return dock
end

local function buildPuffButton(screen)
    local holder = mk("Frame", {
        Name = "PuffHolder", Size = UDim2.fromOffset(340, 186), Position = UDim2.new(0.5, 0, 1, -18),
        AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, ZIndex = 5,
    }, screen)
    Theme.autoScale(holder, 1500, 900, 0.78, 1.05)

    refs.puffButton = mk("TextButton", {
        Name = "PuffButton", Size = UDim2.fromOffset(164, 164), Position = UDim2.new(0.5, -82, 0, 0),
        BackgroundColor3 = C.cyan, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }, holder)
    Theme.corner(refs.puffButton, 82)
    Theme.stroke(refs.puffButton, C.cyan, 2.5, 0.1)
    Theme.gradient(refs.puffButton, C.cyan, C.blue, 90)

    refs.cooldownFill = mk("Frame", {
        Name = "Cooldown", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 12, 24),
        BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 7,
    }, refs.puffButton)
    Theme.corner(refs.cooldownFill, 82)

    refs.puffButtonLabel = mk("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "PUFF",
        Font = Theme.Font.Black, TextScaled = true, TextColor3 = Color3.fromRGB(10, 14, 24), ZIndex = 8,
    }, refs.puffButton)
    Theme.pad(refs.puffButtonLabel, 26, 22, 26, 22)
    Theme.new("UITextSizeConstraint", { MaxTextSize = 34, MinTextSize = 16 }, refs.puffButtonLabel)

    --Etiqueta informativa bajo el boton
    refs.puffHint = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1),
        BackgroundTransparency = 1, Text = "CLIC PARA DAR UNA CALADA", Font = Theme.Font.Bold,
        TextSize = 12, TextColor3 = C.subtext, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6,
    }, holder)

    return holder
end

local function buildNotifications(screen)
    local list = mk("Frame", {
        Name = "Notifications", Size = UDim2.fromOffset(430, 0), Position = UDim2.new(0.5, 0, 0, 16),
        AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 30,
    }, screen)
    Theme.autoScale(list, 1500, 900, 0.78, 1.05)
    Theme.new("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, list)
    refs.notifyList = list
    return list
end

-- Menu -------------------------------------------------------------------------

local function menuOption(parent, opts)
    local b = Theme.button({
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.panel2, Variant = "ghost",
        Accent = opts.accent, Text = "", ZIndex = 23, Name = opts.name, _corner = Theme.Radius.md,
    }, parent)
    local bar = mk("Frame", {
        Size = UDim2.fromOffset(4, 40), Position = UDim2.new(0, 0, 0.5, -20),
        BackgroundColor3 = opts.accent, BorderSizePixel = 0, ZIndex = 24,
    }, b)
    Theme.corner(bar, 2)
    mk("TextLabel", {
        Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 14, 0.5, -20),
        BackgroundTransparency = 1, Text = opts.icon, TextScaled = true, Font = Theme.Font.Black, ZIndex = 24,
    }, b)
    mk("TextLabel", {
        Size = UDim2.new(1, -74, 0, 22), Position = UDim2.new(0, 62, 0, 14),
        BackgroundTransparency = 1, Text = opts.title, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Bold, TextSize = 17, TextColor3 = C.text, ZIndex = 24,
    }, b)
    mk("TextLabel", {
        Size = UDim2.new(1, -74, 0, 18), Position = UDim2.new(0, 62, 0, 38),
        BackgroundTransparency = 1, Text = opts.caption or "", TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Med, TextSize = 12, TextColor3 = C.subtext, TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 24,
    }, b)
    return b
end

local function buildMenu(screen)
    local modal = Theme.modal(screen, {
        name = "MenuFrame", title = "MENU PRINCIPAL", subtitle = "HOW TO VAPE · ciudad y vapers",
        accent = C.cyan, width = 0.62, height = 0.66, maxSize = Vector2.new(760, 620), ZIndex = 20,
    })
    registerModal("menuFrame", modal)

    local scroll = mk("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 5, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22,
    }, modal.body)
    Theme.autoGrid(scroll, 230, 78, 12)

    refs.menuShopButton = menuOption(scroll, {
        icon = "🛒", title = "TIENDA DEL DEALER", caption = "Compra el stock del dealer mas cercano",
        accent = C.cyan, name = "MenuShop",
    })
    refs.menuInventoryButton = menuOption(scroll, {
        icon = "🎒", title = "INVENTARIO", caption = "Tus vapers: equipar y comprar",
        accent = C.purple, name = "MenuInventory",
    })
    refs.menuVehiclesButton = menuOption(scroll, {
        icon = "🛴", title = "VEHICULOS", caption = "Compra, despliega y guarda tus vehiculos",
        accent = C.pink, name = "MenuVehicles",
    })
    refs.menuMapButton = menuOption(scroll, {
        icon = "🗺", title = "MAPA", caption = "Distritos y casas descubiertas",
        accent = C.blue, name = "MenuMap",
    })
    refs.menuMissionsButton = menuOption(scroll, {
        icon = "⭐", title = "MISIONES", caption = "Retos y recompensas en Puffs",
        accent = C.warn, name = "MenuMissions",
    })
    refs.menuControlsButton = menuOption(scroll, {
        icon = "🎮", title = "CONTROLES", caption = "Teclado, raton y pantalla tactil",
        accent = C.good, name = "MenuControls",
    })
    return modal
end

-- Inventario y tienda ----------------------------------------------------------

--[[ Tarjeta de vaper: previsualizacion, nombre, multiplicador, rareza, precio y
     boton de accion. `setState` la pinta segun el estado real del jugador. ]]
function UIModule.MakeVapeCard(parent, cfg)
    local card = Theme.panel({
        Name = "Card_" .. cfg.id, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.panel2,
        _corner = Theme.Radius.md, ZIndex = 23, _flat = true,
    }, parent)

    local preview = buildVapePreview(cfg.id, UDim2.new(1, -20, 0, 100))
    preview.Position = UDim2.fromOffset(10, 10)
    preview.Parent = card

    local lockOverlay = mk("Frame", {
        Size = UDim2.new(1, -20, 0, 100), Position = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Color3.fromRGB(6, 8, 14), BackgroundTransparency = 0.45,
        BorderSizePixel = 0, Visible = false, ZIndex = 27,
    }, card)
    Theme.corner(lockOverlay, Theme.Radius.md)
    local lockIcon = mk("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "🔒", TextScaled = true,
        Font = Theme.Font.Black, TextColor3 = C.subtext, ZIndex = 28,
    }, lockOverlay)
    Theme.new("UITextSizeConstraint", { MaxTextSize = 40 }, lockIcon)

    local name = mk("TextLabel", {
        Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 114),
        BackgroundTransparency = 1, Text = cfg.name, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Bold, TextSize = 16, TextColor3 = C.text,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 24,
    }, card)

    local rarity = mk("TextLabel", {
        Size = UDim2.new(0, 110, 0, 18), Position = UDim2.fromOffset(10, 138),
        BackgroundTransparency = 1, Text = EconomyConfig.RarityName(cfg.id),
        TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Font.Bold, TextSize = 11,
        TextColor3 = EconomyConfig.RarityColor(cfg.id), ZIndex = 24,
    }, card)

    local mult = mk("TextLabel", {
        Size = UDim2.new(0, 90, 0, 18), Position = UDim2.new(1, -100, 0, 138),
        BackgroundTransparency = 1, Text = ("x%d Puffs"):format(cfg.multiplier or 1),
        TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Font.Bold, TextSize = 12,
        TextColor3 = C.cyan, ZIndex = 24,
    }, card)

    local info = mk("TextLabel", {
        Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 160),
        BackgroundTransparency = 1, Text = cfg.description or "", TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Font = Theme.Font.Med,
        TextSize = 12, TextColor3 = C.subtext, ZIndex = 24,
    }, card)

    local button = Theme.button({
        Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 1, -50),
        Variant = "ghost", Accent = C.cyan, TextSize = 15, ZIndex = 26, Name = "Action",
    }, card)

    local state = { onAction = nil, enabled = false }
    button.MouseButton1Click:Connect(function()
        if button.Active ~= false and state.onAction then
            state.onAction()
        end
    end)

    local card2 = {
        frame = card,
        preview = preview,
        button = button,
        nameLabel = name,
        infoLabel = info,
        config = cfg,
    }

    --[[ st = { owned, equipped, price, puffs, accent, info, locked, onAction } ]]
    function card2.setState(st)
        local accent = st.accent or EconomyConfig.RarityColor(cfg.id)
        state.onAction = st.onAction

        name.TextColor3 = st.locked and C.muted or C.text
        mult.TextColor3 = st.locked and C.muted or C.cyan
        rarity.TextColor3 = st.locked and Theme.shade(accent, -0.35) or accent
        lockOverlay.Visible = st.locked == true
        preview.BackgroundColor3 = st.locked and Color3.fromRGB(9, 10, 15) or Color3.fromRGB(11, 13, 22)

        if st.equipped then
            card.BackgroundColor3 = Theme.shade(C.good, -0.82)
            button.Text = "✔  EQUIPADO"
            button.Variant = "soft"
            button.BackgroundColor3 = Theme.shade(C.good, -0.7)
            button.TextColor3 = C.good
            button.Active = false
            info.Text = st.info or "Este es el vaper que llevas ahora."
        elseif st.owned then
            card.BackgroundColor3 = C.panel2
            button.Text = "EQUIPAR"
            button.Variant = "soft"
            button.BackgroundColor3 = Theme.shade(C.good, -0.72)
            button.TextColor3 = C.good
            button.Active = true
            info.Text = st.info or ("Desbloqueado · x%d Puffs por calada"):format(cfg.multiplier or 1)
        elseif st.puffs and st.puffs >= (st.price or 0) then
            card.BackgroundColor3 = C.panel2
            button.Text = ("COMPRAR   %d"):format(st.price or 0)
            button.Variant = "solid"
            button.BackgroundColor3 = C.cyan
            button.TextColor3 = Theme.shade(C.cyan, -0.86)
            button.Active = true
            info.Text = st.info or ("Precio: %d Puffs · ya puedes comprarlo"):format(st.price or 0)
        else
            card.BackgroundColor3 = Theme.shade(C.panel2, -0.15)
            local falta = math.max(0, (st.price or 0) - (st.puffs or 0))
            button.Text = ("FALTAN %d"):format(falta)
            button.Variant = "ghost"
            button.BackgroundColor3 = Theme.shade(C.panel2, -0.15)
            button.TextColor3 = C.muted
            button.Active = false
            info.Text = st.info or ("Precio: %d Puffs · te faltan %d"):format(st.price or 0, falta)
        end

        -- Borde de la tarjeta: verde si esta equipado, color de rareza si no.
        local st1 = card:FindFirstChildOfClass("UIStroke")
        if st1 then
            st1.Color = st.equipped and C.good or Theme.shade(accent, st.locked and -0.5 or 0.1)
            st1.Transparency = st.equipped and 0 or 0.35
            st1.Thickness = st.equipped and 2 or 1.2
        end
        return card2
    end

    return card2
end

local function buildInventory(screen)
    local modal = Theme.modal(screen, {
        name = "InventoryFrame", title = "INVENTARIO DE VAPERS",
        subtitle = "Elige tu dispositivo y da caladas", accent = C.purple,
        width = 0.92, height = 0.86, maxSize = Vector2.new(1060, 720), ZIndex = 20,
        footerHeight = 42,
    })
    registerModal("inventoryFrame", modal)

    local scroll = mk("ScrollingFrame", {
        Name = "Grid", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.line,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22,
    }, modal.body)
    Theme.autoGrid(scroll, 208, 268, 14)
    refs.inventoryList = scroll

    refs.inventorySummary = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(4, 8),
        BackgroundTransparency = 1, Text = "", Font = Theme.Font.Med, TextSize = 13,
        TextColor3 = C.subtext, ZIndex = 26,
    }, modal.footer)
    return modal
end

local function buildShop(screen)
    local modal = Theme.modal(screen, {
        name = "ShopFrame", title = "TIENDA", subtitle = "Stock del dealer", accent = C.cyan,
        width = 0.88, height = 0.82, maxSize = Vector2.new(980, 680), ZIndex = 20,
        footerHeight = 42,
    })
    registerModal("shopFrame", modal)
    refs.shopTitle = modal.title
    refs.shopSubtitle = modal.subtitle

    local scroll = mk("ScrollingFrame", {
        Name = "Grid", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.line,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22,
    }, modal.body)
    Theme.autoGrid(scroll, 208, 268, 14)
    refs.shopList = scroll

    refs.shopHint = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(4, 8),
        BackgroundTransparency = 1, Text = "", Font = Theme.Font.Med, TextSize = 13,
        TextColor3 = C.subtext, ZIndex = 26,
    }, modal.footer)
    return modal
end

-- Vehicles ---------------------------------------------------------------------

--[[ Tarjeta de vehiculo: previsualizacion 3D, nombre, estado, precio y los tres
     botones (comprar / sacar / guardar). `setState` la repinta con el estado
     real del jugador: st = { owned, active, price, puffs, accent,
     onBuy, onDeploy, onStore }.
     Anadir un vehiculo nuevo NO requiere tocar esto: la tarjeta se construye
     entera a partir de VehicleConfig. ]]
function UIModule.MakeVehicleCard(parent, cfg)
    local accent = VehicleConfig.Accent(cfg.id)
    local card = Theme.panel({
        Name = "VCard_" .. cfg.id, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.panel2,
        _corner = Theme.Radius.md, ZIndex = 23, _flat = true,
    }, parent)

    local preview = buildVehiclePreview(cfg.id, UDim2.new(1, -20, 0, 104))
    preview.Position = UDim2.fromOffset(10, 10)
    preview.Parent = card

    local lockOverlay = mk("Frame", {
        Name = "Lock", Size = UDim2.new(1, -20, 0, 104), Position = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Color3.fromRGB(6, 8, 14), BackgroundTransparency = 0.45,
        BorderSizePixel = 0, Visible = false, ZIndex = 27,
    }, card)
    Theme.corner(lockOverlay, Theme.Radius.md)
    local lockIcon = mk("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "🔒", TextScaled = true,
        Font = Theme.Font.Black, TextColor3 = C.subtext, ZIndex = 28,
    }, lockOverlay)
    Theme.new("UITextSizeConstraint", { MaxTextSize = 40 }, lockIcon)

    local name = mk("TextLabel", {
        Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 118),
        BackgroundTransparency = 1, Text = cfg.name, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.Font.Bold, TextSize = 16, TextColor3 = C.text,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 24,
    }, card)

    -- Pastilla de estado: BLOQUEADO / DISPONIBLE / COMPRADO / DESPLEGADO.
    local status = mk("Frame", {
        Name = "Status", Size = UDim2.fromOffset(110, 22), Position = UDim2.fromOffset(10, 142),
        BackgroundColor3 = Theme.shade(accent, -0.72), BorderSizePixel = 0, ZIndex = 24,
    }, card)
    Theme.corner(status, 11)
    local statusStroke = Theme.stroke(status, accent, 1, 0.25)
    local statusText = mk("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "DISPONIBLE",
        Font = Theme.Font.Bold, TextSize = 11, TextColor3 = accent,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 25,
    }, status)

    local info = mk("TextLabel", {
        Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 166),
        BackgroundTransparency = 1, Text = cfg.description or "", TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = false, TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd, Font = Theme.Font.Med, TextColor3 = C.subtext, ZIndex = 24,
    }, card)

    local buyButton = Theme.button({
        Size = UDim2.new(1, -20, 0, 38), Position = UDim2.new(0, 10, 1, -132),
        Variant = "ghost", Accent = accent, TextSize = 14, ZIndex = 26, Name = "Buy",
    }, card)
    local deployButton = Theme.button({
        Size = UDim2.new(1, -20, 0, 38), Position = UDim2.new(0, 10, 1, -90),
        Variant = "ghost", Accent = C.good, TextSize = 14, ZIndex = 26, Name = "Deploy",
    }, card)
    local storeButton = Theme.button({
        Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 1, -48),
        Variant = "ghost", Accent = C.warn, TextSize = 13, ZIndex = 26, Name = "Store",
    }, card)

    local handlers = { onBuy = nil, onDeploy = nil, onStore = nil }
    buyButton.MouseButton1Click:Connect(function()
        if buyButton.Active ~= false and handlers.onBuy then
            handlers.onBuy()
        end
    end)
    deployButton.MouseButton1Click:Connect(function()
        if deployButton.Active ~= false and handlers.onDeploy then
            handlers.onDeploy()
        end
    end)
    storeButton.MouseButton1Click:Connect(function()
        if storeButton.Active ~= false and handlers.onStore then
            handlers.onStore()
        end
    end)

    local card2 = { frame = card, preview = preview, config = cfg, statusLabel = statusText }

    local function paint(button, text, enabled, color, variant)
        button.Text = text
        button.Active = enabled
        button.BackgroundColor3 = color
        button.TextColor3 = variant
    end

    function card2.setState(st)
        local stAccent = st.accent or accent
        local owned = st.owned == true
        local active = st.active == true
        local price = st.price or 0
        local puffs = st.puffs or 0
        local affordable = puffs >= price
        handlers.onBuy = st.onBuy
        handlers.onDeploy = st.onDeploy
        handlers.onStore = st.onStore

        -- Pastilla de estado.
        local label, color
        if active then
            label, color = "DESPLEGADO", C.good
        elseif owned then
            label, color = "COMPRADO", stAccent
        elseif affordable then
            label, color = "DISPONIBLE", C.cyan
        else
            label, color = "BLOQUEADO", C.muted
        end
        statusText.Text = label
        statusText.TextColor3 = color
        status.BackgroundColor3 = Theme.shade(color, -0.74)
        statusStroke.Color = color
        status.Size = UDim2.fromOffset(18 + #label * 8, 22)

        local locked = (not owned) and (not affordable)
        lockOverlay.Visible = locked
        preview.BackgroundColor3 = locked and Color3.fromRGB(9, 10, 15) or Color3.fromRGB(11, 13, 22)
        name.TextColor3 = locked and C.muted or C.text

        -- Linea informativa segun el estado (nunca deja al jugador a ciegas).
        if active then
            info.Text = "En la ciudad ahora mismo · subete con E"
            info.TextColor3 = C.good
        elseif owned then
            info.Text = "Comprado · listo para desplegar"
            info.TextColor3 = stAccent
        elseif affordable then
            info.Text = ("Precio: %d Puffs · ya puedes comprarlo"):format(price)
            info.TextColor3 = C.subtext
        else
            info.Text = ("Precio: %d Puffs · te faltan %d"):format(price, math.max(0, price - puffs))
            info.TextColor3 = C.muted
        end

        -- COMPRAR (solo si no lo tiene).
        if owned then
            paint(buyButton, "YA ES TUYO", false, Theme.shade(C.panel2, -0.15), C.muted)
        elseif affordable then
            paint(buyButton, ("COMPRAR   %d"):format(price), true, stAccent, Theme.shade(stAccent, -0.86))
        else
            paint(buyButton, ("FALTAN %d"):format(math.max(0, price - puffs)), false,
                Theme.shade(C.panel2, -0.15), C.muted)
        end

        -- SACAR a la calle (necesita ser dueno y no tenerlo ya desplegado).
        if not owned then
            paint(deployButton, "BLOQUEADO", false, Theme.shade(C.panel2, -0.15), C.muted)
        elseif active then
            paint(deployButton, "EN LA CIUDAD", false, Theme.shade(C.good, -0.8), Theme.shade(C.good, -0.2))
        else
            paint(deployButton, "SACAR A LA CALLE", true, Theme.shade(C.good, -0.7), C.good)
        end

        -- GUARDAR (solo cuando esta desplegado).
        if owned and active then
            paint(storeButton, "GUARDAR", true, Theme.shade(C.warn, -0.72), C.warn)
        else
            paint(storeButton, "GUARDAR", false, Theme.shade(C.panel2, -0.18), C.muted)
        end

        -- Borde de la tarjeta: verde si esta desplegado, acento si es tuyo.
        local stroke = card:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = active and C.good or Theme.shade(stAccent, owned and 0.1 or -0.5)
            stroke.Transparency = active and 0 or 0.35
            stroke.Thickness = active and 2 or 1.2
        end
        return card2
    end

    return card2
end

local function buildVehicles(screen)
    local modal = Theme.modal(screen, {
        name = "VehiclesFrame", title = "VEHICULOS",
        subtitle = "Compra, despliega y guarda tus vehiculos", accent = C.pink,
        width = 0.88, height = 0.84, maxSize = Vector2.new(980, 700), ZIndex = 20,
        footerHeight = 42,
    })
    registerModal("vehiclesFrame", modal)

    local scroll = mk("ScrollingFrame", {
        Name = "Grid", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.line,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22,
    }, modal.body)
    Theme.autoGrid(scroll, 214, 320, 14)
    refs.vehiclesList = scroll

    refs.vehiclesSummary = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(4, 8),
        BackgroundTransparency = 1, Text = "", Font = Theme.Font.Med, TextSize = 13,
        TextColor3 = C.subtext, ZIndex = 26,
    }, modal.footer)
    return modal
end

-- Modal de casa ----------------------------------------------------------------
local function buildHouseModal(screen)
    local modal = Theme.modal(screen, {
        name = "HouseModal", title = "CASA", subtitle = "Acceso permanente", accent = C.good,
        width = 0.5, height = 0.6, maxSize = Vector2.new(560, 480), ZIndex = 20,
        footerHeight = 110,
    })
    registerModal("houseFrame", modal)
    refs.houseTitle = modal.title
    refs.houseSubtitle = modal.subtitle

    local body = mk("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22,
    }, modal.body)
    Theme.new("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    }, body)
    refs.houseBody = body

    refs.houseUnlockBtn = Theme.button({
        Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 0, 0),
        Variant = "solid", Accent = C.good, Text = "DESBLOQUEAR", TextSize = 18, ZIndex = 26,
    }, modal.footer)
    refs.houseUnlockBtn.Text = "DESBLOQUEAR"
    refs.houseCloseBtn = Theme.button({
        Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 58),
        Variant = "ghost", Accent = C.subtext, Text = "Cerrar", TextSize = 14, ZIndex = 26,
    }, modal.footer)
    refs.houseCloseBtn.Text = "Cerrar"

    refs._houseHandler = nil
    refs.houseUnlockBtn.MouseButton1Click:Connect(function()
        if refs.houseUnlockBtn.Active ~= false and refs._houseHandler then
            refs._houseHandler()
        end
    end)
    refs.houseCloseBtn.MouseButton1Click:Connect(function()
        UIModule.CloseHouseModal()
    end)
    return modal
end

-- Mapa -------------------------------------------------------------------------
local function buildMap(screen)
    local modal = Theme.modal(screen, {
        name = "MapFrame", title = "MAPA DE LA CIUDAD", subtitle = "Plaza central y 8 distritos",
        accent = C.blue, width = 0.6, height = 0.9, maxSize = Vector2.new(720, 780), ZIndex = 20,
        footerHeight = 46,
    })
    registerModal("mapFrame", modal)

    local area = mk("Frame", {
        Name = "MapArea", Size = UDim2.fromOffset(MAP_SIZE, MAP_SIZE), Position = UDim2.new(0.5, -MAP_SIZE / 2, 0, 0),
        BackgroundColor3 = Color3.fromRGB(14, 16, 26), BorderSizePixel = 0, ZIndex = 22,
    }, modal.body)
    Theme.corner(area, Theme.Radius.md)
    Theme.stroke(area, C.line, 1.4)
    refs.mapArea = area

    -- Base dibujada una sola vez: calles, circunvalacion y plaza.
    local base = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22 }, area)
    for _, line in ipairs(CityGrid.LINES) do
        local w = CityGrid.WidthOf(line)
        local xa, _ = worldToMap(line, 0)
        local ya, _ = worldToMap(0, line)
        local thick = math.max(2, w / WORLD_HALF * MAP_SIZE * 0.9)
        local c = CityGrid.IsAvenue(line) and Color3.fromRGB(74, 82, 112) or Color3.fromRGB(52, 58, 82)
        mk("Frame", { Size = UDim2.fromOffset(thick, MAP_SIZE), Position = UDim2.fromOffset(xa - thick / 2, 0),
            BackgroundColor3 = c, BorderSizePixel = 0, ZIndex = 22 }, base)
        mk("Frame", { Size = UDim2.fromOffset(MAP_SIZE, thick), Position = UDim2.fromOffset(0, ya - thick / 2),
            BackgroundColor3 = c, BorderSizePixel = 0, ZIndex = 22 }, base)
    end
    local rx, _ = worldToMap(CityGrid.RING, 0)
    local rw = CityGrid.RING / WORLD_HALF * MAP_SIZE
    mk("Frame", { Size = UDim2.fromOffset(rw * 2, 3), Position = UDim2.fromOffset(rx - rw, rx - rw - 1.5),
        BackgroundColor3 = Color3.fromRGB(70, 78, 108), BorderSizePixel = 0, ZIndex = 22 }, base)
    mk("Frame", { Size = UDim2.fromOffset(rw * 2, 3), Position = UDim2.fromOffset(rx - rw, rx + rw - 1.5),
        BackgroundColor3 = Color3.fromRGB(70, 78, 108), BorderSizePixel = 0, ZIndex = 22 }, base)
    local ph = CityGrid.Plaza.half / WORLD_HALF * MAP_SIZE
    local pcx, _ = worldToMap(0, 0)
    local plazaBox = mk("Frame", { Size = UDim2.fromOffset(ph * 2, ph * 2),
        Position = UDim2.fromOffset(pcx - ph, pcx - ph), BackgroundColor3 = Color3.fromRGB(40, 46, 70),
        BorderSizePixel = 0, ZIndex = 22 }, base)
    Theme.corner(plazaBox, 4)

    refs.mapMarkers = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 23 }, area)
    refs.playerDot = mk("Frame", {
        Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 27, Visible = false,
    }, area)
    Theme.corner(refs.playerDot, 6)
    Theme.stroke(refs.playerDot, C.cyan, 3)
    local ping = mk("Frame", {
        Size = UDim2.fromScale(2.6, 2.6), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.cyan,
        BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 26,
    }, refs.playerDot)
    Theme.corner(ping, 999)
    task.spawn(function()
        while ping.Parent do
            ping.Size = UDim2.fromScale(1, 1)
            ping.BackgroundTransparency = 0.5
            local tw = game:GetService("TweenService"):Create(ping,
                TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.fromScale(4, 4), BackgroundTransparency = 1 })
            tw:Play()
            tw.Completed:Wait()
        end
    end)

    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(4, 8),
        BackgroundTransparency = 1, Text = "Punto blanco = tu posicion.  Cuadros = distritos conocidos.  Circulos = dealers.",
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Font.Med,
        TextSize = 12, TextColor3 = C.subtext, ZIndex = 26,
    }, modal.footer)
    return modal
end

-- Misiones ---------------------------------------------------------------------
local function buildMissions(screen)
    local modal = Theme.modal(screen, {
        name = "MissionsFrame", title = "MISIONES", subtitle = "Completa retos y gana Puffs",
        accent = C.warn, width = 0.72, height = 0.84, maxSize = Vector2.new(820, 700), ZIndex = 20,
    })
    registerModal("missionsFrame", modal)

    local scroll = mk("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 6, ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22,
    }, modal.body)
    Theme.vlist(scroll, 10)
    refs.missionsList = scroll
    return modal
end

-- Controles --------------------------------------------------------------------
local function buildControls(screen)
    local modal = Theme.modal(screen, {
        name = "ControlsFrame", title = "CONTROLES", subtitle = "PC, teclado y pantalla tactil",
        accent = C.good, width = 0.56, height = 0.72, maxSize = Vector2.new(640, 620), ZIndex = 20,
    })
    registerModal("controlsFrame", modal)

    local rows = {
        { "WASD", "Moverte por la ciudad" },
        { "SHIFT IZQ", "Correr (mantener pulsada). A 24 studs/s" },
        { "ESPACIO", "Saltar" },
        { "CLIC IZQ", "Usar (botones, dealers, puertas)" },
        { "BOTON PUFF", "Dar una calada y ganar Puffs" },
        { UIModule.Keybinds.inventory, "Abrir y cerrar el inventario" },
        { UIModule.Keybinds.vehicles, "Abrir y cerrar los vehiculos" },
        { UIModule.Keybinds.menu, "Abrir y cerrar el menu principal" },
        { UIModule.Keybinds.map, "Abrir el mapa de la ciudad" },
        { UIModule.Keybinds.missions, "Abrir las misiones" },
        { "WASD + E", "Al montar el patinete: acelerar, frenar y girar" },
        { "ESPACIO", "Bajarte del vehiculo mientras conduces" },
        { "ESCAPE", "Cerrar el panel abierto" },
        { "MOVIL", "Joystick y botones tactiles: la interfaz se adapta sola" },
    }
    local list = mk("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 6, ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22,
    }, modal.body)
    Theme.vlist(list, 8)
    for _, row in ipairs(rows) do
        local item = Theme.panel({
            Size = UDim2.new(1, -6, 0, 46), BackgroundColor3 = C.panel2, _corner = Theme.Radius.sm,
            _flat = true, ZIndex = 23,
        }, list)
        local key = mk("Frame", {
            Size = UDim2.fromOffset(110, 30), Position = UDim2.new(0, 10, 0.5, -15),
            BackgroundColor3 = C.panelHi, BorderSizePixel = 0, ZIndex = 24,
        }, item)
        Theme.corner(key, Theme.Radius.sm)
        Theme.stroke(key, C.good, 1, 0.4)
        mk("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = row[1],
            Font = Theme.Font.Bold, TextSize = 13, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 25,
        }, key)
        mk("TextLabel", {
            Size = UDim2.new(1, -140, 1, 0), Position = UDim2.new(0, 132, 0, 0),
            BackgroundTransparency = 1, Text = row[2], Font = Theme.Font.Med, TextSize = 13,
            TextColor3 = C.subtext, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 24,
        }, item)
    end
    return modal
end

-- Construccion principal -------------------------------------------------------
function UIModule.Build()
    if refs.screen then
        return refs
    end

    local screen = mk("ScreenGui", {
        Name = "MainUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 10,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)
    refs.screen = screen

    buildPuffCard(screen)
    buildProgressCard(screen)
    buildEquipCard(screen)
    buildDock(screen)
    buildPuffButton(screen)
    buildNotifications(screen)

    buildMenu(screen)
    buildInventory(screen)
    buildShop(screen)
    buildVehicles(screen)
    buildHouseModal(screen)
    buildMap(screen)
    buildMissions(screen)
    buildControls(screen)

    -- Animacion de las previsualizaciones + posicion en el mapa
    RunService.RenderStepped:Connect(function(dt)
        for i = #activePreviews, 1, -1 do
            local p = activePreviews[i]
            if p.viewport.Parent == nil then
                table.remove(activePreviews, i)
            elseif p.viewport:IsDescendantOf(screen) and p.viewport.Visible then
                -- Solo se anima lo visible (el inventario tiene 15 vistas 3D).
                local visible = true
                local node = p.viewport.Parent
                while node and node ~= screen do
                    if node:IsA("GuiObject") and node.Visible == false then
                        visible = false
                        break
                    end
                    node = node.Parent
                end
                if visible then
                    p.angle += dt * (p.speed or 0.55)
                    local r = p.radius or 5
                    local h = p.height or 0.4
                    local pos = Vector3.new(math.sin(p.angle) * r, h, math.cos(p.angle) * r)
                    p.camera.CFrame = CFrame.lookAt(pos, p.target or Vector3.new(0, 0, 0))
                end
            end
        end

        if refs.mapFrame and refs.mapFrame.Visible then
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                local mx, my = worldToMap(root.Position.X, root.Position.Z)
                refs.playerDot.Position = UDim2.fromOffset(mx, my)
                refs.playerDot.Visible = true
            end
        end
    end)

    return refs
end

-- API publica -----------------------------------------------------------------
function UIModule.Refs()
    return refs
end

function UIModule.SetPuffs(value)
    value = math.floor(value)
    if refs._lastPuffs and value > refs._lastPuffs then
        Theme.pulse(refs.puffLabel, C.cyan, 0.45)
    end
    refs._lastPuffs = value
    refs.puffLabel.Text = tostring(value)
end

function UIModule.SetRate(multiplier)
    refs.puffRate.Text = ("+%d Puffs por calada"):format(multiplier or 1)
end

function UIModule.SetEquipped(cfg)
    if not cfg then
        return
    end
    refs.equipName.Text = cfg.name
    refs.equipMult.Text = ("x%d Puffs"):format(cfg.multiplier or 1)
    refs.equipRarity.Text = EconomyConfig.RarityName(cfg.id)
    refs.equipRarity.TextColor3 = EconomyConfig.RarityColor(cfg.id)
    if refs.equipPreview and refs.equipPreviewId ~= cfg.id then
        refs.equipPreviewId = cfg.id
        for _, child in ipairs(refs.equipPreview:GetChildren()) do
            if child:IsA("Model") then
                child:Destroy()
            end
        end
        local model = VapeFactory.Build(cfg.id)
        if model then
            model.Parent = refs.equipPreview
        end
    end
end

function UIModule.SetProgress(title, current, requirement)
    refs.progressTitle.Text = title
    local frac = 0
    if requirement > 0 then
        frac = math.clamp(current / requirement, 0, 1)
    end
    refs.progressFill.Size = UDim2.new(frac, 0, 1, 0)
    refs.progressText.Text = ("%d / %d Puffs"):format(math.floor(current), requirement)
end

function UIModule.SetCooldown(frac)
    refs.cooldownFill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
end

function UIModule.Notify(text, color, icon)
    local item = Theme.panel({
        Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.panel, _corner = Theme.Radius.md,
        _flat = true, ZIndex = 31,
    }, refs.notifyList)
    item.BackgroundTransparency = 0.05
    local st = item:FindFirstChildOfClass("UIStroke")
    if st then
        st.Color = color or C.cyan
        st.Transparency = 0.2
    end
    local bar = mk("Frame", {
        Size = UDim2.fromOffset(4, 26), Position = UDim2.new(0, 8, 0.5, -13),
        BackgroundColor3 = color or C.cyan, BorderSizePixel = 0, ZIndex = 32,
    }, item)
    Theme.corner(bar, 2)
    mk("TextLabel", {
        Size = UDim2.new(0, 26, 1, 0), Position = UDim2.fromOffset(18, 0), BackgroundTransparency = 1,
        Text = icon or "•", Font = Theme.Font.Black, TextSize = 18, TextColor3 = color or C.cyan,
        ZIndex = 32,
    }, item)
    mk("TextLabel", {
        Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(44, 0), BackgroundTransparency = 1,
        Text = text, Font = Theme.Font.Med, TextSize = 14, TextColor3 = C.text,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32,
    }, item)
    Theme.slideIn(item, 12)

    task.delay(3.5, function()
        if item and item.Parent then
            item:Destroy()
        end
    end)
end

-- Paneles: apertura/cierre coordinados ----------------------------------------
function UIModule.CloseAllPanels()
    for _, key in ipairs({ "menuModal", "inventoryModal", "shopModal", "vehiclesModal", "mapModal",
        "missionsModal", "controlsModal", "houseModal" }) do
        if refs[key] then
            if refs[key].SetVisible then
                refs[key].SetVisible(false)
            else
                refs[key].Visible = false
            end
        end
    end
end

function UIModule.OpenMenu()
    UIModule.CloseAllPanels()
    setVisible(refs.menuModal, true)
end

function UIModule.CloseMenu()
    setVisible(refs.menuModal, false)
end

function UIModule.IsMenuOpen()
    return refs.menuFrame and refs.menuFrame.Visible == true
end

function UIModule.ToggleMenu()
    if UIModule.IsMenuOpen() then
        UIModule.CloseMenu()
    else
        UIModule.OpenMenu()
    end
end

function UIModule.OpenInventory()
    UIModule.CloseAllPanels()
    setVisible(refs.inventoryModal, true)
end

function UIModule.CloseInventory()
    setVisible(refs.inventoryModal, false)
end

function UIModule.IsInventoryOpen()
    return refs.inventoryFrame and refs.inventoryFrame.Visible == true
end

function UIModule.ClearInventory()
    for _, child in ipairs(refs.inventoryList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

function UIModule.GetInventoryList()
    return refs.inventoryList
end

function UIModule.OpenShop(title, subtitle)
    UIModule.CloseAllPanels()
    if title then
        refs.shopTitle.Text = title
    end
    refs.shopSubtitle.Text = subtitle or ""
    setVisible(refs.shopModal, true)
end

function UIModule.CloseShop()
    setVisible(refs.shopModal, false)
end

function UIModule.IsShopOpen()
    return refs.shopFrame and refs.shopFrame.Visible == true
end

function UIModule.ClearShop()
    for _, child in ipairs(refs.shopList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

function UIModule.GetShopList()
    return refs.shopList
end

function UIModule.SetShopHint(text, color)
    if refs.shopHint then
        refs.shopHint.Text = text or ""
        refs.shopHint.TextColor3 = color or C.subtext
    end
end

function UIModule.SetInventorySummary(text, color)
    if refs.inventorySummary then
        refs.inventorySummary.Text = text or ""
        refs.inventorySummary.TextColor3 = color or C.subtext
    end
end

-- Vehiculos -------------------------------------------------------------------
function UIModule.OpenVehicles()
    UIModule.CloseAllPanels()
    setVisible(refs.vehiclesModal, true)
end

function UIModule.CloseVehicles()
    setVisible(refs.vehiclesModal, false)
end

function UIModule.IsVehiclesOpen()
    return refs.vehiclesFrame and refs.vehiclesFrame.Visible == true
end

function UIModule.ClearVehicles()
    if not refs.vehiclesList then
        return
    end
    for _, child in ipairs(refs.vehiclesList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

function UIModule.GetVehiclesList()
    return refs.vehiclesList
end

function UIModule.SetVehiclesSummary(text, color)
    if refs.vehiclesSummary then
        refs.vehiclesSummary.Text = text or ""
        refs.vehiclesSummary.TextColor3 = color or C.subtext
    end
end

-- Modal de casa ---------------------------------------------------------------
-- info = { title, cost, puffs, missing, unlocked, district, dealerName }
function UIModule.OpenHouseModal(info, onUnlock)
    UIModule.CloseAllPanels()
    refs.houseTitle.Text = info.title or "CASA"
    refs.houseSubtitle.Text = ("Dealer: %s"):format(info.dealerName or "?")
    for _, child in ipairs(refs.houseBody:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    local function line(text, color, size)
        local l = Theme.label({
            Size = UDim2.new(1, 0, 0, size or 26), Text = text, Font = Theme.Font.Med,
            TextSize = 15, TextColor3 = color or C.text, TextWrapped = true, ZIndex = 23,
        }, refs.houseBody)
        return l
    end

    if info.unlocked then
        line("Ya tienes acceso permanente a esta casa.", C.good)
        line("Puedes entrar cuando quieras: el dealer te atendera dentro.", C.subtext)
        line(("Casa: %s"):format(info.title or "-"), C.subtext)
        refs.houseUnlockBtn.Text = "CERRAR"
        refs.houseUnlockBtn.BackgroundColor3 = C.panel2
        refs.houseUnlockBtn.TextColor3 = C.text
        refs.houseUnlockBtn.Active = true
        refs._houseHandler = function()
            UIModule.CloseHouseModal()
        end
    else
        line(("Coste de acceso: %d Puffs"):format(info.cost or 0), C.cyan)
        line(("Tus Puffs: %d"):format(info.puffs or 0), C.text)
        if (info.missing or 0) > 0 then
            line(("Te faltan %d Puffs. Sigue dando caladas."):format(info.missing), C.bad)
            refs.houseUnlockBtn.Text = ("FALTAN %d"):format(info.missing)
            refs.houseUnlockBtn.BackgroundColor3 = Theme.shade(C.panel2, -0.15)
            refs.houseUnlockBtn.TextColor3 = C.muted
            refs.houseUnlockBtn.Active = false
        else
            line("Al desbloquearla entra para siempre y podras comprar al dealer.", C.subtext)
            refs.houseUnlockBtn.Text = ("DESBLOQUEAR   %d"):format(info.cost or 0)
            refs.houseUnlockBtn.BackgroundColor3 = C.good
            refs.houseUnlockBtn.TextColor3 = Theme.shade(C.good, -0.86)
            refs.houseUnlockBtn.Active = true
        end
        refs._houseHandler = onUnlock
    end
    setVisible(refs.houseModal, true)
end

function UIModule.CloseHouseModal()
    if refs.houseModal then
        refs.houseModal.SetVisible(false)
    end
end

function UIModule.IsHouseModalOpen()
    return refs.houseFrame and refs.houseFrame.Visible == true
end

-- Mapa ------------------------------------------------------------------------
function UIModule.OpenMap()
    UIModule.CloseAllPanels()
    setVisible(refs.mapModal, true)
end

function UIModule.CloseMap()
    setVisible(refs.mapModal, false)
    refs.playerDot.Visible = false
end

function UIModule.IsMapOpen()
    return refs.mapFrame and refs.mapFrame.Visible == true
end

--[[ Pinta distritos conocidos y dealers descubiertos.
     state = { zones, houses, discovered } ]]
function UIModule.RenderMap(state)
    if not refs.mapMarkers then
        return
    end
    refs.mapMarkers:ClearAllChildren()
    for _, id in ipairs(ZoneConfig.DistrictOrder) do
        local d = ZoneConfig.Districts[id]
        local known = state.zones and state.zones[id]
        local mx, my = worldToMap(d.center.X, d.center.Z)
        local box = mk("Frame", {
            Size = UDim2.fromOffset(72, 72), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(mx, my),
            BackgroundColor3 = known and d.color or Color3.fromRGB(40, 43, 58),
            BackgroundTransparency = known and 0.35 or 0.55, BorderSizePixel = 0, ZIndex = 24,
        }, refs.mapMarkers)
        Theme.corner(box, 8)
        if known then
            Theme.stroke(box, d.color, 1.4, 0.2)
        end
        mk("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextWrapped = true,
            Text = known and d.short or "?", Font = Theme.Font.Bold, TextScaled = true,
            TextColor3 = known and Color3.fromRGB(12, 14, 20) or C.muted, ZIndex = 25,
        }, box)
    end
    -- Dealers descubiertos
    for _, id in ipairs(ZoneConfig.HouseOrder) do
        if state.discovered and state.discovered[id] then
            local house = ZoneConfig.Houses[id]
            local mx, my = worldToMap(house.position.X, house.position.Z)
            local unlocked = state.houses and state.houses[id]
            local dot = mk("Frame", {
                Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(mx, my), BackgroundColor3 = house.dealer.color,
                BorderSizePixel = 0, ZIndex = 26,
            }, refs.mapMarkers)
            Theme.corner(dot, 7)
            if unlocked then
                Theme.stroke(dot, Color3.fromRGB(255, 255, 255), 2)
            end
        end
    end
end

-- Misiones --------------------------------------------------------------------
function UIModule.OpenMissions()
    UIModule.CloseAllPanels()
    setVisible(refs.missionsModal, true)
end

function UIModule.CloseMissions()
    setVisible(refs.missionsModal, false)
end

function UIModule.IsMissionsOpen()
    return refs.missionsFrame and refs.missionsFrame.Visible == true
end

--[[ Pinta misiones con su progreso. values = { metric -> current } ]]
function UIModule.RenderMissions(values, completed)
    if not refs.missionsList then
        return
    end
    for _, child in ipairs(refs.missionsList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    for _, mission in ipairs(MissionConfig.GetOrdered()) do
        local done = completed and completed[mission.id]
        local current = values[mission.metric] or 0
        if current > mission.target then
            current = mission.target
        end
        local frac = mission.target > 0 and math.clamp(current / mission.target, 0, 1) or 0

        local row = Theme.panel({
            Size = UDim2.new(1, -6, 0, 104), BackgroundColor3 = C.panel, _corner = Theme.Radius.md,
            _flat = true, ZIndex = 23,
        }, refs.missionsList)
        local st = row:FindFirstChildOfClass("UIStroke")
        if st then
            st.Color = done and C.good or C.line
            st.Transparency = done and 0.1 or 0.5
        end
        mk("TextLabel", {
            Size = UDim2.new(1, -130, 0, 24), Position = UDim2.fromOffset(16, 12),
            BackgroundTransparency = 1, Text = (done and "✔  " or "") .. mission.name,
            TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Font.Bold, TextSize = 17,
            TextColor3 = done and C.good or C.text, ZIndex = 24,
        }, row)
        mk("TextLabel", {
            Size = UDim2.new(0, 110, 0, 22), Position = UDim2.new(1, -126, 0, 13),
            BackgroundTransparency = 1, Text = ("+%d Puffs"):format(mission.reward),
            TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Font.Bold, TextSize = 13,
            TextColor3 = done and C.good or C.warn, ZIndex = 24,
        }, row)
        mk("TextLabel", {
            Size = UDim2.new(1, -32, 0, 20), Position = UDim2.fromOffset(16, 38),
            BackgroundTransparency = 1, Text = mission.desc, TextXAlignment = Enum.TextXAlignment.Left,
            Font = Theme.Font.Med, TextSize = 12, TextColor3 = C.subtext,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 24,
        }, row)
        local bar = mk("Frame", {
            Size = UDim2.new(1, -32, 0, 12), Position = UDim2.fromOffset(16, 64),
            BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 24,
        }, row)
        Theme.corner(bar, 6)
        local fill = mk("Frame", {
            Size = UDim2.new(frac, 0, 1, 0), BackgroundColor3 = done and C.good or C.warn,
            BorderSizePixel = 0, ZIndex = 25,
        }, bar)
        Theme.corner(fill, 6)
        mk("TextLabel", {
            Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 80),
            BackgroundTransparency = 1,
            Text = done and "Recompensa conseguida" or ("%d / %d"):format(current, mission.target),
            TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Font.Med, TextSize = 12,
            TextColor3 = done and C.good or C.subtext, ZIndex = 24,
        }, row)
    end
end

-- Controles --------------------------------------------------------------------
function UIModule.OpenControls()
    UIModule.CloseAllPanels()
    setVisible(refs.controlsModal, true)
end

function UIModule.CloseControls()
    setVisible(refs.controlsModal, false)
end

function UIModule.IsControlsOpen()
    return refs.controlsFrame and refs.controlsFrame.Visible == true
end

function UIModule.IsAnyPanelOpen()
    return UIModule.IsMenuOpen() or UIModule.IsInventoryOpen() or UIModule.IsShopOpen()
        or UIModule.IsVehiclesOpen() or UIModule.IsMapOpen() or UIModule.IsMissionsOpen()
        or UIModule.IsHouseModalOpen() or UIModule.IsControlsOpen()
end

-- Helpers heredados (los usa ClientController) --------------------------------
function UIModule.MakePreview(vapeId, size)
    return buildVapePreview(vapeId, size)
end

function UIModule.MakePanel(props, parent)
    return Theme.panel(props, parent)
end

function UIModule.MakeButton(props, parent)
    return Theme.button(props, parent)
end

function UIModule.Theme()
    return Theme
end

return UIModule
