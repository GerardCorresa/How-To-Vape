--[[
    PuffAnimator
    Ruta en Roblox Studio: StarterPlayer > StarterPlayerScripts > PuffAnimator
    Tipo: ModuleScript (cliente)

    Animacion de la calada, 100% procedural y compartida por todos los clientes:
    cada cliente la calcula en local para todos los personajes cercanos, asi que
    no se replica ni un solo CFrame por la red.

    COMO FUNCIONA (y por que no pelea con el Animator)
    --------------------------------------------------
    1. Descubre las articulaciones reales del rig (R15 y R6) leyendo sus Motor6D.
        * R15: RightShoulder (RightUpperArm), RightElbow (RightLowerArm),
               RightWrist (RightHand), Neck (Head), Waist (UpperTorso)
        * R6 : "Right Shoulder" (Right Arm), Neck (Head)
    2. Construye la cadena de reposo a partir de C0/C1. Los pivotes y las
       longitudes salen gratis:  L1 = |elbow.C0.Position - shoulder.C1.Position|
       y L2 = |wrist.C0.Position - elbow.C1.Position|, todo en el espacio del
       torso. No hay que medir nada "en vivo" ni asumir ejes.
    3. Calcula el CFrame que debe tener la MANO para que la PUNTA del
       dispositivo toque la boca. La punta se mide sola en EquipmentService a
       partir de la geometria real del modelo, asi que funciona con vapers
       grandes y pequenos sin tocar codigo.
    4. Resuelve un IK de dos huesos (hombro + codo) para colocar la muneca, y
       fija la rotacion exacta de la muneca. El codo se coloca en el plano que
       marca su posicion de reposo, asi que flexiona de forma natural.
       En R6 (sin codo) se apunta el brazo entero a un punto delante de la boca.
    5. Escribe los resultados en Motor6D.Transform (la propiedad que usa el
       Animator), MEZCLANDO con el valor actual: Transform = actual:Lerp(objetivo,
       peso). Nunca se toca C0/C1 ni se anaden Articulaciones: la animacion
       base (idle, andar) sigue debajo y se recupera sola al bajar el peso.

    La secuencia la lleva una maquina de estados (raise -> pause -> exhale ->
    lower) que marca cuando se emite el humo. Las caladas encadenadas reutilizan
    el mismo ciclo (pause+exhale) en vez de lanzar animaciones en paralelo.

    Requiere: AnimConfig, MouthFX.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local MouthFX = require(script.Parent:WaitForChild("MouthFX"))

local PuffAnimator = {}

local EPS = 1e-4
local CONTROLLED_JOINTS = { "shoulder", "elbow", "wrist", "neck", "waist" }

-- ============================================================ utilidades math

local function unit(v)
    local m = v.Magnitude
    if m < EPS then
        return Vector3.new(0, 1, 0)
    end
    return v / m
end

local function smoothstep(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

--[[ Rotacion minima que lleva el vector a al vector b.
     a y b pueden venir en espacios distintos: lo que se construye es la
     rotacion R tal que R*a = b (util para "apunta el eje X al eje Y"). ]]
local function minimalRotation(a, b)
    a, b = unit(a), unit(b)
    local dot = math.clamp(a:Dot(b), -1, 1)
    local cross = a:Cross(b)
    if cross.Magnitude < 1e-5 then
        if dot > 0 then
            return CFrame.new()
        end
        local axis = a:Cross(Vector3.new(0, 1, 0))
        if axis.Magnitude < 1e-4 then
            axis = a:Cross(Vector3.new(1, 0, 0))
        end
        return CFrame.fromAxisAngle(unit(axis), math.pi)
    end
    return CFrame.fromAxisAngle(unit(cross), math.acos(dot))
end

--[[ Rotacion R que cumple R*a1 = b1 y ademas alinea a2 con b2 lo mejor posible
     (usa dos bases ortonormales). Necesaria en R6, donde solo hay una
     articulacion y hay que fijar direccion Y orientacion a la vez. ]]
local function rotationFromTwoVectors(a1, a2, b1, b2)
    local e1 = unit(a1)
    local e2 = a2 - e1 * a2:Dot(e1)
    local E1 = unit(b1)
    local E2 = b2 - E1 * b2:Dot(E1)
    if e2.Magnitude < 1e-4 or E2.Magnitude < 1e-4 then
        return minimalRotation(e1, E1)
    end
    e2, E2 = unit(e2), unit(E2)
    local e3 = e1:Cross(e2)
    local E3 = E1:Cross(E2)
    local L = CFrame.fromMatrix(Vector3.zero, e1, e2, e3)
    local T = CFrame.fromMatrix(Vector3.zero, E1, E2, E3)
    return T * L:Inverse()
end

--[[ Devuelve la articulacion que MUEVE una pieza concreta.

     Es el criterio estandar de Roblox en TODOS los rigs: en un Motor6D, Part1
     es siempre el miembro "hijo" que la articulacion mueve y Part0 el padre.
     Asi la deteccion no depende ni del nombre de la articulacion ni de donde
     cuelgue en el arbol, y funciona igual en R15 y en R6:

        R15: RightShoulder(Part1=RightUpperArm), RightElbow(Part1=RightLowerArm),
             RightWrist(Part1=RightHand),    Neck(Part1=Head), Waist(Part1=UpperTorso)
        R6 : "Right Shoulder"(Part1=Right Arm), Neck(Part1=Head)
]]
local function jointFor(character, drivenPartName)
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("Motor6D") and d.Part0 and d.Part1 and d.Part1.Name == drivenPartName then
            return d
        end
    end
    return nil
end

-- ======================================================== deteccion del rig

local function detectRig(character)
    local head = character:FindFirstChild("Head")
    if not head then
        return nil
    end

    -- R15
    local shoulder = jointFor(character, "RightUpperArm")
    local elbow = jointFor(character, "RightLowerArm")
    local wrist = jointFor(character, "RightHand")
    local rigType = "R15"

    if not (shoulder and elbow and wrist) then
        -- R6: una sola articulacion para todo el brazo
        shoulder = jointFor(character, "Right Arm")
        elbow, wrist = nil, nil
        rigType = "R6"
    end

    if not (shoulder and shoulder.Part0 and shoulder.Part1) then
        return nil
    end

    return {
        character = character,
        head = head,
        rigType = rigType,
        upperArm = shoulder.Part1,
        lowerArm = elbow and elbow.Part1,
        hand = (wrist and wrist.Part1) or shoulder.Part1,
        shoulder = shoulder,
        elbow = elbow,
        wrist = wrist,
        neck = jointFor(character, "Head"),          -- Neck
        waist = jointFor(character, "UpperTorso"),   -- Waist (solo R15)
    }
end

-- Cadena de reposo, toda en el espacio de shoulder.Part0 (el torso).
local function buildRest(c)
    local sh = c.shoulder
    c.torso = sh.Part0

    c.upperRest = sh.C0 * sh.C1:Inverse()
    c.S = sh.C0.Position

    if c.elbow and c.wrist then
        c.lowerRest = c.upperRest * c.elbow.C0 * c.elbow.C1:Inverse()
        c.handRest = c.lowerRest * c.wrist.C0 * c.wrist.C1:Inverse()

        local E = (c.upperRest * c.elbow.C0).Position
        local W = (c.lowerRest * c.wrist.C0).Position
        c.E_rest, c.W_rest = E, W
        c.L1 = (E - c.S).Magnitude
        c.L2 = (W - E).Magnitude
        c.poleRest = unit(E - c.S)                 -- el codo flexiona hacia abajo
        c.aU_rest = unit(E - c.S)
        c.aL_rest = unit(W - E)
        c.armAxisLocalU = unit(c.elbow.C0.Position - sh.C1.Position)
        c.armAxisLocalL = unit(c.wrist.C0.Position - c.elbow.C1.Position)
    else
        -- R6: el "hand" es el propio brazo.
        c.handRest = c.upperRest
        c.poleRest = Vector3.new(0, -1, 0)
    end
end

-- ================================================== objetivo de la mano

--[[ Devuelve (posicion de la boca, direccion del eje del dispositivo) en el
     espacio del torso. ]]
local function mouthTargetTL(c)
    local head = c.head
    local cfg = AnimConfig.Mouth
    local torsoInv = c.torso.CFrame:Inverse()
    local length = c.vapeLength or 0.7
    local clearance = cfg.Clearance + cfg.LengthFactor * length

    local localPos = Vector3.new(
        cfg.Offset.X * head.Size.X,
        cfg.Offset.Y * head.Size.Y,
        -(cfg.Offset.Z * head.Size.Z + clearance)
    )
    local mouthWorld = head.CFrame * localPos

    local headTL = torsoInv * head.CFrame
    local tilt = math.rad(cfg.TiltDeg)
    local upTL = headTL:VectorToWorldSpace(Vector3.new(0, math.cos(tilt), math.sin(tilt)))

    return torsoInv * mouthWorld, unit(upTL)
end

--[[ CFrame que debe tener la MANO para que la punta del dispositivo llegue a
     la boca. Se interpola desde la posicion de reposo con `approach` y se le
     anade un pequeno arco para que el gesto no sea una linea recta. ]]
local function handTargetTL(c, approach, separation)
    local mouthTL, upTL = mouthTargetTL(c)
    local tipLocal = c.tipLocal
    local upLocal = c.upLocal

    -- Rotacion de la mano: el eje del dispositivo apunta hacia la boca.
    local rot = minimalRotation(upLocal, upTL)
        * CFrame.fromAxisAngle(unit(upLocal), math.rad(AnimConfig.Mouth.RollDeg))
    -- Coloca el origen de la mano para que la punta caiga en la boca.
    local mouthHand = CFrame.new(mouthTL - rot:VectorToWorldSpace(tipLocal)) * rot

    if separation > 0 then
        mouthHand = mouthHand - upTL * (separation * AnimConfig.Mouth.Separation)
    end

    local D = c.handRest:Lerp(mouthHand, approach)
    if approach > 0.001 then
        -- Arco: sube y baja durante el recorrido (espacio local del torso, +Y = arriba).
        D = D + Vector3.new(0, math.sin(math.pi * approach) * AnimConfig.Mouth.ArcLift, 0)
    end
    return D
end

-- ================================================== IK y transforms

--[[ IK de dos huesos. Devuelve los Transform de hombro, codo y muneca. ]]
local function solveArmTL(c, handTL)
    local Wt = handTL * c.wrist.C1.Position      -- pivote de la muneca objetivo
    local S = c.S
    local v = Wt - S
    local dist = v.Magnitude
    local minD = math.abs(c.L1 - c.L2) + 1e-3
    local maxD = c.L1 + c.L2 - 1e-3
    local reachable = dist <= maxD
    local d = math.clamp(dist, minD, maxD)
    local dir = unit(v)

    -- Plano del codo: se mantiene del lado donde el brazo cae en reposo.
    local pole = c.poleRest - dir * c.poleRest:Dot(dir)
    if pole.Magnitude < 1e-4 then
        pole = Vector3.new(0, -1, 0) - dir * dir.Y
        if pole.Magnitude < 1e-4 then
            pole = Vector3.new(0, 0, 1)
        end
    end
    pole = unit(pole)

    local cosA = math.clamp((c.L1 * c.L1 + d * d - c.L2 * c.L2) / (2 * c.L1 * d), -1, 1)
    local A = math.acos(cosA)
    local eDir = dir * math.cos(A) + pole * math.sin(A)
    local E = S + eDir * c.L1
    local wDir = unit(Wt - E)

    local upperTL = CFrame.new(S)
        * (minimalRotation(c.aU_rest, eDir) * c.upperRest.Rotation)
        * CFrame.new(-c.shoulder.C1.Position)
    local lowerTL = CFrame.new(E)
        * (minimalRotation(c.aL_rest, wDir) * c.lowerRest.Rotation)
        * CFrame.new(-c.elbow.C1.Position)

    -- T = (Part0 * C0)^-1 * Part1 * C1  (todo en el espacio del torso)
    local tShoulder = c.shoulder.C0:Inverse() * upperTL * c.shoulder.C1
    local tElbow = (upperTL * c.elbow.C0):Inverse() * lowerTL * c.elbow.C1
    local tWrist = (lowerTL * c.wrist.C0):Inverse() * handTL * c.wrist.C1

    c.lastReachable = reachable
    return tShoulder, tElbow, tWrist
end

--[[ R6: sin codo. Se busca el punto delante de la boca que queda justo a la
     distancia del brazo, para que la punta llegue cerca de la cara sin
     atravesarla (el brazo en R6 no puede acortarse). ]]
local function solveArmR6(c, approach)
    local tipLocal = c.tipLocal
    local upLocal = c.upLocal
    local pivotLocal = c.shoulder.C1.Position
    local armAxisLocal = unit(tipLocal - pivotLocal)
    local reach = math.max(0.1, (tipLocal - pivotLocal).Magnitude)

    local mouthTL, upTL = mouthTargetTL(c)
    local headTL = c.torso.CFrame:Inverse() * c.head.CFrame
    -- Direccion "hacia fuera de la cara": el frente de la cabeza, algo hacia abajo.
    local outward = unit(headTL:VectorToWorldSpace(unit(Vector3.new(0, -0.35, -1))))

    local v = mouthTL - c.S
    local b = v:Dot(outward)
    local disc = b * b - (v:Dot(v) - reach * reach)
    local g = disc > 0 and (-b + math.sqrt(disc)) or 0
    local tipTarget = mouthTL + outward * g

    local tipTL = CFrame.new(c.S)
        * rotationFromTwoVectors(armAxisLocal, upLocal, unit(tipTarget - c.S), upTL)
        * CFrame.new(-pivotLocal)

    -- Mezcla desde el reposo igual que en R15.
    local handTL = c.handRest:Lerp(tipTL, approach)
    if approach > 0.001 then
        handTL = handTL + Vector3.new(0, math.sin(math.pi * approach) * AnimConfig.Mouth.ArcLift, 0)
    end

    local tShoulder = c.shoulder.C0:Inverse() * handTL * c.shoulder.C1
    return tShoulder
end

-- ================================================== estado por personaje

local controllers = {}

-- Lee los datos medidos por EquipmentService (punta, eje y longitud del vape).
local function refreshVape(c)
    local model = c.character:FindFirstChild("EquippedVape")
    if model ~= c.vapeModel then
        c.vapeModel = model
        c.primary = model and model.PrimaryPart
    end
    local primary = c.primary
    if primary and primary.Parent then
        c.tipLocal = primary:GetAttribute("VapeTipLocal") or c.tipLocal
        c.upLocal = primary:GetAttribute("VapeUpLocal") or c.upLocal
        c.vapeLength = primary:GetAttribute("VapeLength") or c.vapeLength
    else
        c.vapeModel, c.primary = nil, nil
    end
    -- Valores de respaldo si el vape es antiguo o no trae atributos.
    c.tipLocal = c.tipLocal or Vector3.new(0, 0.45, 0)
    c.upLocal = unit(c.upLocal or Vector3.new(0, 1, 0))
    c.vapeLength = c.vapeLength or 0.7
end

local function applyJoint(motor, target, weight)
    if not motor or not motor.Parent then
        return
    end
    if weight >= 0.999 then
        motor.Transform = target
    else
        motor.Transform = motor.Transform:Lerp(target, weight)
    end
end

local function resetJoints(c)
    for _, key in ipairs(CONTROLLED_JOINTS) do
        local motor = c[key]
        if motor and motor.Parent then
            motor.Transform = CFrame.new()
        end
    end
end

local function stopController(c, interrupted)
    c.phase = "idle"
    c.t = 0
    c.elapsed = 0
    c.queue = 0
    if interrupted then
        -- Interrupcion (muerte, desequipar...): devolvemos el control entero al
        -- Animator para no dejar una postura a medias.
        resetJoints(c)
    end
end

local function fireExhale(c)
    MouthFX.emit(c.character)
end

local function fireDeviceWisp(c)
    local model = c.vapeModel
    if not model then
        return
    end
    local emitter = model:FindFirstChild("VapeSmoke", true)
    if emitter and emitter:IsA("ParticleEmitter") then
        emitter:Emit(AnimConfig.DeviceWisp.Count)
    end
end

local function getController(character)
    local c = controllers[character]
    if c then
        return c
    end
    local rig = detectRig(character)
    if not rig then
        if AnimConfig.Debug then
            warn("[PuffAnimator] Rig no compatible en", character.Name)
        end
        return nil
    end
    c = rig
    c.humanoid = character:FindFirstChildOfClass("Humanoid")
    c.phase = "idle"
    c.t = 0
    c.elapsed = 0
    c.queue = 0
    c.tipLocal, c.upLocal, c.vapeLength = nil, nil, nil
    buildRest(c)
    refreshVape(c)
    controllers[character] = c
    return c
end

-- ================================================== bucle principal

local function updateController(c, dt)
    if c.phase == "idle" then
        return
    end

    -- Interrupciones: personaje muerto, sin vape equipado o rig invalido.
    local humanoid = c.humanoid
    if not (c.character.Parent and humanoid and humanoid.Health > 0 and c.torso) then
        stopController(c, true)
        return
    end
    refreshVape(c)
    if not c.vapeModel then
        stopController(c, true)
        return
    end

    local d = AnimConfig.Timeline
    c.t += dt
    c.elapsed += dt

    -- Transiciones de fase
    if c.phase == "raise" then
        if c.t >= d.Raise then
            c.phase, c.t = "pause", 0
        end
    elseif c.phase == "pause" then
        if c.t >= d.Pause then
            c.phase, c.t = "exhale", 0
            fireExhale(c)                      -- marcador de expulsion
        end
    elseif c.phase == "exhale" then
        if c.t >= d.Exhale then
            if c.queue > 1 then                -- calada encadenada: reutilizamos ciclo
                c.queue -= 1
                c.phase, c.t = "pause", 0
            else
                c.phase, c.t = "lower", 0
            end
        end
    elseif c.phase == "lower" then
        if c.t >= d.Lower then
            stopController(c, false)
            return
        end
    end

    -- Parametros de postura segun la fase
    local approach, separation
    if c.phase == "raise" then
        approach = smoothstep(c.t / d.Raise)
    elseif c.phase == "pause" then
        approach = 1
    elseif c.phase == "exhale" then
        approach = 1
        separation = math.sin(math.clamp(c.t / d.Exhale, 0, 1) * math.pi)
    elseif c.phase == "lower" then
        local p = math.clamp(c.t / d.Lower, 0, 1)
        approach = 1 - smoothstep(math.min(1, p / 0.55))
    end
    approach = approach or 0
    separation = separation or 0

    -- Peso: entra suave al empezar y se apaga al final, para no dar tirones.
    local weight = math.clamp(c.elapsed / AnimConfig.Blend.In, 0, 1)
    if c.phase == "lower" then
        local p = c.t / d.Lower
        if p > 0.6 then
            weight = weight * math.clamp((1 - p) / 0.4, 0, 1)
        end
    end

    -- Movimiento del cuello y la cintura, proporcional a lo cerca que esta la boca
    local sec = AnimConfig.Secondary
    local lift = math.sin(math.pi * math.clamp(approach, 0, 1))
    applyJoint(c.neck,
        CFrame.Angles(math.rad(sec.NeckPitch * lift), math.rad(sec.NeckYaw * lift), 0),
        weight)
    applyJoint(c.waist, CFrame.Angles(math.rad(sec.WaistPitch * lift), 0, 0), weight)

    -- Brazo
    if c.wrist then
        local handTL = handTargetTL(c, approach, separation)
        local tS, tE, tW = solveArmTL(c, handTL)
        applyJoint(c.shoulder, tS, weight)
        applyJoint(c.elbow, tE, weight)
        applyJoint(c.wrist, tW, weight)
    else
        applyJoint(c.shoulder, solveArmR6(c, approach), weight)
    end
end

local function step(dt)
    for character, c in pairs(controllers) do
        if character.Parent then
            updateController(c, dt)
        else
            MouthFX.clear(character)
            controllers[character] = nil
        end
    end
end

-- ================================================== API publica

--[[ Lanza (o encadena) la calada del personaje. ]]
function PuffAnimator.play(character)
    if not character then
        return
    end
    local c = getController(character)
    if not c then
        return
    end
    refreshVape(c)
    if not c.vapeModel then
        return                              -- hay que llevar el vape equipado
    end

    if c.phase == "idle" then
        c.phase, c.t, c.elapsed = "raise", 0, 0
        c.queue = 1
        fireDeviceWisp(c)
        if AnimConfig.Debug then
            print(("[PuffAnimator] %s rig=%s L1=%.2f L2=%.2f vape=%.2f")
                :format(character.Name, c.rigType, c.L1 or 0, c.L2 or 0, c.vapeLength or 0))
        end
    else
        -- Ya hay una calada en curso: se encadena en lugar de solaparse.
        c.queue = math.min(c.queue + 1, AnimConfig.Timeline.MaxQueue)
    end
end

--[[ Detiene la secuencia y devuelve el control al Animator. ]]
function PuffAnimator.stop(character)
    local c = controllers[character]
    if c then
        stopController(c, true)
    end
end

function PuffAnimator.isPlaying(character)
    local c = controllers[character]
    return c ~= nil and c.phase ~= "idle"
end

function PuffAnimator.init()
    local function hook(character)
        getController(character)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        player.CharacterAdded:Connect(hook)
        if player.Character then
            hook(player.Character)
        end
    end
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(hook)
        if player.Character then
            hook(player.Character)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            MouthFX.clear(player.Character)
            controllers[player.Character] = nil
        end
    end)

    -- Una sola conexion para todos los personajes (nada de conexiones por calada).
    RunService.RenderStepped:Connect(step)
end

return PuffAnimator
