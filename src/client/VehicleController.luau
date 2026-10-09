--[[
    VehicleController
    Ruta en Roblox Studio: StarterPlayer > StarterPlayerScripts > VehicleController
    Tipo: ModuleScript (lo inicializa ClientController)

    CONDUCCION del patinete (y de cualquier vehiculo futuro de VehicleConfig).

    Reparto de responsabilidades:
      * El SERVIDOR despliega el modelo anclado y con DriveEnabled = false, y
        comprueba la propiedad y el limite de un vehiculo por jugador.
      * Al montarse, el servidor lo desancla, pone DriveEnabled = true y deja
        al conductor como dueno de la fisica (igual que un asiento normal de
        Roblox): asi su propio movimiento se ve sin latencia.
      * Este modulo coloca el vehiculo con PivotTo (movimiento cinematico) a la
        velocidad de VehicleConfig. Antes de avanzar sondea el suelo (delante y
        detras) y comprueba la pared con un Blockcast, por lo que el patinete:
          - no se hunde ni flota (la altura sigue al suelo, con subidas suaves),
          - no vuelca ni sale disparado (nunca se mete dentro de un muro: si hay
            choque se detiene),
          - no se queda atascado (puede pivotar parado, frenar y marcha atras).
      * Ademas 0.5s de fisica "tranquila": se anulan las velocidades del
        ensamblaje cada frame, asi que la gravedad no acumula nada.

    Animacion de conduccion sencilla: las ruedas giran con su Motor6D y el
    chasis se inclina hacia dentro al girar.

    Controles: W/S (o flechas) acelerar y frenar, A/D girar, ESPACIO bajarse.
    En tactil aparece un pad de 4 botones mientras se conduce.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local player = Players.LocalPlayer

local VehicleController = {}

local RIDE_GUI = "HTV_RideTouch"

--[[ Distancia del centro del vehiculo a la punta de la caja de colision. El
     patinete mide ~4 studs de largo: 1.1 + 1.1 = 2.2 deja la punta justo en el
     morro (2.0) con un pequeno margen. ]]
local PROBE_AHEAD = 1.1

local inited = false
local ride = nil          -- estado de la conduccion actual
local touch = nil         -- { fwd, back, left, right }
local touchGui = nil

local function moveTowards(current, target, amount)
    local delta = target - current
    if math.abs(delta) <= amount then
        return target
    end
    return current + (delta > 0 and amount or -amount)
end

local function yawOf(cframe)
    local look = cframe.LookVector
    return math.atan2(-look.X, -look.Z)
end

-- Pad tactil ------------------------------------------------------------------

local function buildTouchPad()
    if touchGui then
        return
    end
    local playerGui = player:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild(RIDE_GUI)
    if existing then
        touchGui = existing
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = RIDE_GUI
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 4
    gui.Visible = false
    gui.Parent = playerGui

    touch = { fwd = false, back = false, left = false, right = false }

    local layout = {
        fwd = { UDim2.fromOffset(0, 0), "▲" },
        left = { UDim2.fromOffset(-64, -64), "◀" },
        right = { UDim2.fromOffset(64, -64), "▶" },
        back = { UDim2.fromOffset(0, -128), "▼" },
    }
    local holder = Instance.new("Frame")
    holder.Name = "Pad"
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.new(0, 128, 1, -150)
    holder.Size = UDim2.fromOffset(64, 64)
    holder.BackgroundTransparency = 1
    holder.Parent = gui

    for key, data in pairs(layout) do
        local button = Instance.new("TextButton")
        button.Name = key
        button.AnchorPoint = Vector2.new(0.5, 0.5)
        button.Position = UDim2.new(0.5, data[1].X.Offset, 0.5, data[1].Y.Offset)
        button.Size = UDim2.fromOffset(58, 58)
        button.BackgroundColor3 = Color3.fromRGB(24, 27, 42)
        button.BackgroundTransparency = 0.15
        button.BorderSizePixel = 0
        button.Text = data[2]
        button.Font = Enum.Font.GothamBold
        button.TextSize = 22
        button.TextColor3 = Color3.fromRGB(236, 240, 255)
        button.AutoButtonColor = false
        button.Parent = holder
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = button
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 96, 190)
        stroke.Thickness = 1.4
        stroke.Transparency = 0.35
        stroke.Parent = button

        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and touch then
                touch[key] = true
            end
        end)
        button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and touch then
                touch[key] = false
            end
        end)
    end
    touchGui = gui
end

local function setTouchVisible(visible)
    if UserInputService.TouchEnabled then
        buildTouchPad()
        if touchGui then
            touchGui.Visible = visible
        end
    end
end

-- Entrada ----------------------------------------------------------------------

local function readInput()
    if touch then
        local t, s = 0, 0
        if touch.fwd then t += 1 end
        if touch.back then t -= 1 end
        if touch.left then s -= 1 end
        if touch.right then s += 1 end
        if t ~= 0 or s ~= 0 then
            return t, s
        end
    end

    local t, s = 0, 0
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
        t += 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
        t -= 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
        s += 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
        s -= 1
    end

    if t == 0 and s == 0 and UserInputService.GamepadEnabled then
        local ok, states = pcall(function()
            return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
        end)
        if ok and states then
            for _, state in ipairs(states) do
                if state.KeyCode == Enum.KeyCode.Thumbstick1 then
                    if math.abs(state.Position.X) > 0.15 then
                        s = state.Position.X
                    end
                    if math.abs(state.Position.Y) > 0.15 then
                        t = -state.Position.Y
                    end
                end
            end
        end
    end
    return t, s
end

-- Sondas del terreno -----------------------------------------------------------

local function probeParams(model)
    local ignore = { model }
    if player.Character then
        table.insert(ignore, player.Character)
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    return params
end

-- Altura del suelo en un punto (nil si no hay nada debajo).
local function probeGround(model, x, z, fromY)
    local hit = workspace:Raycast(
        Vector3.new(x, fromY + 6, z), Vector3.new(0, -14, 0), probeParams(model))
    return hit and hit.Position.Y or nil
end

--[[ Hueco libre hacia `moveDir` (unitario). La caja de la sonda arranca en el
     centro del vehiculo y su punta coincide con el morro/cola, asi que el valor
     devuelto es el espacio REAL que queda antes de chocar. Se sondea a la
     altura del cuerpo (por encima de bordillos y tapas bajas) para no quedarse
     clavado en un escalon, pero si detenerse ante un muro de verdad. Es mas
     estrecha que el vehiculo para poder rozar una pared de lado sin bloquearse. ]]
local function probeWall(model, pos, groundY, moveDir, length)
    local center = Vector3.new(pos.X, groundY + 1.5, pos.Z) + moveDir * PROBE_AHEAD
    local result = workspace:Blockcast(
        CFrame.new(center), Vector3.new(1.8, 1.9, PROBE_AHEAD * 2), moveDir * length, probeParams(model))
    return result and result.Distance or nil
end

-- Montaje / desmontaje ---------------------------------------------------------

local function collectWheels(model)
    local wheels = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d:GetAttribute("VehicleWheel") == true then
            local motor = d:FindFirstChild("SpinMotor")
            if motor and motor:IsA("Motor6D") then
                table.insert(wheels, {
                    motor = motor,
                    base = motor.C0,
                    radius = math.max(0.15, d:GetAttribute("WheelRadius") or (d.Size.Y * 0.5)),
                    angle = 0,
                })
            end
        end
    end
    return wheels
end

local function stopRide()
    if ride and ride.conn then
        ride.conn:Disconnect()
    end
    ride = nil
    setTouchVisible(false)
end

local function startRide(model, seat)
    local cfg = VehicleConfig.Get(model:GetAttribute("VehicleId"))
    local root = model.PrimaryPart
    if not cfg or not root then
        return
    end
    stopRide()
    ride = {
        model = model,
        root = root,
        seat = seat,
        cfg = cfg,
        yaw = yawOf(root.CFrame),
        speed = 0,
        -- `ride.height` es la ALTURA DEL SUELO bajo el vehiculo. El pivote del
        -- modelo esta en el plano del suelo (convencion de VehicleFactory), asi
        -- que al colocar se suma el pequeno `clearance` para no rozar.
        height = root.Position.Y,
        lean = 0,
        wheels = collectWheels(model),
        ready = model:GetAttribute("DriveEnabled") == true,
        readyAt = os.clock() + 1.5,
        conn = nil,
    }
    ride.conn = model:GetAttributeChangedSignal("DriveEnabled"):Connect(function()
        if ride and ride.model == model and model:GetAttribute("DriveEnabled") == true then
            ride.ready = true
        end
    end)
    setTouchVisible(true)
end

local function onSeated(isSeated, seat)
    if isSeated then
        if not (seat and seat:GetAttribute("VehicleSeat") == true) then
            return
        end
        local model = seat:FindFirstAncestorOfClass("Model")
        if not model or model:GetAttribute("OwnerUserId") ~= player.UserId then
            return
        end
        startRide(model, seat)
    elseif ride then
        stopRide()
    end
end

-- Bucle de conduccion ----------------------------------------------------------

local function updateRide(dt)
    if not ride then
        return
    end
    local model, root, cfg = ride.model, ride.root, ride.cfg
    if not model.Parent or not root or not ride.seat.Occupant then
        stopRide()
        return
    end
    if not ride.ready and os.clock() < ride.readyAt then
        return
    end

    local dtc = math.min(dt, 1 / 30)
    local throttle, steer = readInput()

    -- 1) Velocidad con transicion suave (acelerar / frenar / marcha atras).
    local target = 0
    if throttle > 0.05 then
        target = cfg.speed * math.clamp(throttle, 0, 1)
    elseif throttle < -0.05 then
        target = -cfg.speed * (cfg.reverse or 0.45) * math.clamp(-throttle, 0, 1)
    end
    local rate = (math.abs(target) > math.abs(ride.speed)) and cfg.accelerate or cfg.brake
    ride.speed = moveTowards(ride.speed, target, rate * dtc)

    -- 2) Giro. Parado conserva algo de giro para poder salir de un rincon.
    local speedFrac = math.clamp(math.abs(ride.speed) / math.max(1, cfg.speed), 0, 1)
    local idle = cfg.turnIdle or 0.45
    local turnFrac = idle + (1 - idle) * speedFrac
    ride.yaw -= math.rad(cfg.turnRate * turnFrac * math.clamp(steer, -1, 1)) * dtc

    -- 3) Avance comprobando muros (si choca, se detiene: nada de rebotes).
    local pos = root.Position
    local dir = Vector3.new(-math.sin(ride.yaw), 0, -math.cos(ride.yaw))
    local travel = ride.speed * dtc
    local allowed = math.abs(travel)
    if allowed > 1e-5 then
        local moveDir = dir * (travel >= 0 and 1 or -1)
        local free = probeWall(model, pos, ride.height, moveDir, allowed + 0.45)
        if free then
            allowed = math.max(0, free - 0.1)
            if allowed < 0.04 then
                ride.speed = 0
            end
        end
    end
    local moved = math.min(allowed, math.abs(travel)) * (travel >= 0 and 1 or -1)
    local newX = pos.X + dir.X * moved
    local newZ = pos.Z + dir.Z * moved

    -- 4) Seguir el suelo (rueda delantera y trasera) con subidas suaves.
    local frontY = probeGround(model, newX + dir.X * 1.5, newZ + dir.Z * 1.5, ride.height)
    local rearY = probeGround(model, newX - dir.X * 1.5, newZ - dir.Z * 1.5, ride.height)
    local groundY = nil
    if frontY and rearY then
        groundY = math.max(frontY, rearY)
    else
        groundY = frontY or rearY
    end
    if groundY then
        local climb = cfg.climb or 9
        local delta = groundY - ride.height
        local up = climb * dtc
        local down = climb * 2.5 * dtc
        if delta > up then
            delta = up
        elseif delta < -down then
            delta = -down
        end
        ride.height = ride.height + delta
    else
        ride.height -= 25 * dtc
    end

    -- 5) Animacion: inclinacion al girar (la rueda, mas abajo).
    local targetLean = -math.clamp(steer, -1, 1) * (cfg.lean or 0) * (0.35 + 0.65 * speedFrac)
    ride.lean = moveTowards(ride.lean, targetLean, 55 * dtc)

    -- 6) Colocacion final del vehiculo.
    local cf = CFrame.new(newX, ride.height + (cfg.clearance or 0.08), newZ)
        * CFrame.Angles(0, ride.yaw, 0)
    model:PivotTo(cf * CFrame.Angles(0, 0, math.rad(ride.lean)))

    -- 7) Fisica tranquila: el juego mueve el vehiculo, no la gravedad.
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    -- 8) Ruedas girando segun la velocidad real.
    for _, w in ipairs(ride.wheels) do
        w.angle -= (ride.speed / w.radius) * dtc
        w.motor.C0 = w.base * CFrame.Angles(w.angle, 0, 0)
    end
end

-- API -------------------------------------------------------------------------

function VehicleController.Init()
    if inited then
        return
    end
    inited = true

    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then
            humanoid.Seated:Connect(onSeated)
        end
    end)
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Seated:Connect(onSeated)
        end
    end

    -- ESPACIO = bajarse. (La accion de salto queda anulada mientras se conduce.)
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not ride then
            return
        end
        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
            local humanoid = ride.seat and ride.seat.Occupant
            if humanoid and humanoid.Parent then
                humanoid.Sit = false
            end
        end
    end)

    RunService.RenderStepped:Connect(updateRide)
end

--[[ Dato util para la interfaz (si el jugador esta conduciendo). ]]
function VehicleController.IsRiding()
    return ride ~= nil
end

return VehicleController
