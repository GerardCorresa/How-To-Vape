--[[
    MovementController
    Ruta en Roblox Studio: StarterPlayer > StarterPlayerScripts > MovementController
    Tipo: ModuleScript (lo inicializa ClientController)

    SPRINT con la tecla SHIFT IZQUIERDA:
      * velocidad normal  : GameConfig.WalkSpeed   (16 studs/s)
      * velocidad corriendo: GameConfig.SprintSpeed (24 studs/s)
      * transicion suave entre ambas (GameConfig.SprintTransition)
      * sigue funcionando despues de reaparecer: se reengancha en
        CharacterAdded y NUNCA acumula conexiones (una de teclado global y una
        por personaje).
      * solo toca Humanoid.WalkSpeed: no interfiere con la animacion de fumar,
        con el inventario ni con los vehiculos. Mientras el jugador esta sentado
        (conduciendo) el sprint se ignora por completo, asi que Shift no puede
        alterar la velocidad del patinete.
      * en pantalla tactil se anade un boton "CORRER" con el mismo
        comportamiento (mantener pulsado = correr).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local player = Players.LocalPlayer

local MovementController = {}

local SPRINT_KEY = Enum.KeyCode.LeftShift
local TOUCH_GUI = "HTV_MoveTouch"

local inited = false
local sprintHeld = false
local humanoid = nil
local touchButton = nil

local function targetSpeed()
    if sprintHeld and humanoid and not humanoid.Sit and not humanoid.PlatformStand then
        return GameConfig.SprintSpeed
    end
    return GameConfig.WalkSpeed
end

--[[ Acerca WalkSpeed al objetivo de forma suave. Se ejecuta cada frame pero
     sale de inmediato cuando ya no hay nada que hacer (coste despreciable). ]]
local function step(dt)
    if not humanoid or humanoid.Parent == nil or humanoid.Health <= 0 then
        return
    end
    local target = targetSpeed()
    local current = humanoid.WalkSpeed
    if math.abs(current - target) < 0.02 then
        if current ~= target then
            humanoid.WalkSpeed = target
        end
        return
    end
    local span = math.max(0.05, GameConfig.SprintTransition)
    local rate = math.abs(GameConfig.SprintSpeed - GameConfig.WalkSpeed) / span
    local delta = target - current
    local amount = rate * dt
    if math.abs(delta) <= amount then
        humanoid.WalkSpeed = target
    elseif delta > 0 then
        humanoid.WalkSpeed = current + amount
    else
        humanoid.WalkSpeed = current - amount
    end
end

local function onCharacter(character)
    local hum = character:WaitForChild("Humanoid", 10)
    if not hum or not hum:IsA("Humanoid") then
        return
    end
    humanoid = hum
    -- Estado inicial limpio: velocidad de caminar y sprint segun la tecla.
    hum.WalkSpeed = targetSpeed()
end

-- Boton tactil ----------------------------------------------------------------

local function setTouchVisual(active)
    if not touchButton then
        return
    end
    touchButton.BackgroundColor3 = active and Color3.fromRGB(64, 226, 255) or Color3.fromRGB(24, 27, 42)
    touchButton.TextColor3 = active and Color3.fromRGB(10, 14, 24) or Color3.fromRGB(236, 240, 255)
end

local function buildTouchButton()
    local playerGui = player:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild(TOUCH_GUI) then
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = TOUCH_GUI
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 4
    gui.Parent = playerGui

    local button = Instance.new("TextButton")
    button.Name = "SprintButton"
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    -- Esquina inferior derecha, por encima del boton de salto de Roblox.
    button.Position = UDim2.new(1, -62, 1, -236)
    button.Size = UDim2.fromOffset(64, 64)
    button.BackgroundColor3 = Color3.fromRGB(24, 27, 42)
    button.BorderSizePixel = 0
    button.Text = "CORRER"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.TextColor3 = Color3.fromRGB(236, 240, 255)
    button.AutoButtonColor = false
    button.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(64, 226, 255)
    stroke.Thickness = 1.6
    stroke.Transparency = 0.35
    stroke.Parent = button

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            sprintHeld = true
            setTouchVisual(true)
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            sprintHeld = false
            setTouchVisual(false)
        end
    end)
    touchButton = button
end

-- API -------------------------------------------------------------------------

function MovementController.Init()
    if inited then
        return
    end
    inited = true

    -- Una sola conexion de teclado para toda la partida.
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == SPRINT_KEY then
            sprintHeld = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == SPRINT_KEY then
            sprintHeld = false
        end
    end)

    -- Una sola conexion por personaje (se reengancha al reaparecer).
    player.CharacterAdded:Connect(onCharacter)
    if player.Character then
        task.spawn(onCharacter, player.Character)
    end

    RunService.Heartbeat:Connect(step)

    if UserInputService.TouchEnabled then
        task.spawn(buildTouchButton)
    end
end

return MovementController
