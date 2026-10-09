--[[
    EquipmentService
    Ruta en Roblox Studio: ServerScriptService > EquipmentService
    Tipo: ModuleScript

    Coloca el vape equipado en la mano del personaje (servidor), de forma que
    todos los jugadores lo vean. Compatible con R15 ("RightHand") y R6
    ("Right Arm"). El modelo se suelda con un Weld al miembro.

    Ademas MIDE el dispositivo y publica el resultado como atributos en su Part
    primario, para que PuffAnimator (cliente) sepa donde esta la punta, hacia
    donde apunta y cuanto mide:

        VapeId        string   identificador del dispositivo
        VapeTipLocal  Vector3  punta (extremo de la boca) en espacio de la mano
        VapeUpLocal   Vector3  eje del dispositivo en espacio de la mano
        VapeLength    number   longitud total, para mantenerlo lejos de la cara

    Se mide por caja envolvente, asi que cualquier vaper nuevo funciona sin
    tocar ni este script ni el animador.

    Requiere: GameConfig, VapeConfig, VapeFactory.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VapeConfig = require(Shared:WaitForChild("VapeConfig"))
local VapeFactory = require(Shared:WaitForChild("VapeFactory"))

local EquipmentService = {}

local MODEL_NAME = "EquippedVape"

-- Busca el miembro de la mano segun el rig.
local function findHand(character)
    return character:FindFirstChild("RightHand")    -- R15
        or character:FindFirstChild("Right Arm")    -- R6
end

--[[ Mide la geometria REAL del dispositivo para que la animacion sepa donde
     esta la punta (extremo de la boca), hacia donde apunta su eje y cuanto
     mide. Se guardan como atributos en el Part primario y viajan al cliente
     junto con el modelo (los atributos se replican con la instancia).

     Se mide la caja envolvente de todas las piezas del modelo en su espacio
     local, asi funciona con cualquier vaper futuro sin tocar codigo. ]]
local function measureVape(model, hand, vapeId)
    local primary = model.PrimaryPart
    if not primary then
        return
    end
    local mcf = primary.CFrame

    local minY, maxY = math.huge, -math.huge
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local lcf = mcf:Inverse() * part.CFrame
            local half = part.Size * 0.5
            for ix = -1, 1, 2 do
                for iy = -1, 1, 2 do
                    for iz = -1, 1, 2 do
                        local corner = lcf:PointToWorldSpace(
                            Vector3.new(half.X * ix, half.Y * iy, half.Z * iz))
                        if corner.Y > maxY then
                            maxY = corner.Y
                        end
                        if corner.Y < minY then
                            minY = corner.Y
                        end
                    end
                end
            end
        end
    end

    if maxY == -math.huge then
        return
    end

    -- La punta es el punto mas alto sobre el eje del modelo: en los cinco
    -- vapers la boquilla esta arriba y el dispositivo apunta hacia su +Y local.
    local tipWorld = mcf * Vector3.new(0, maxY, 0)
    local upWorld = mcf:VectorToWorldSpace(Vector3.new(0, 1, 0))

    primary:SetAttribute("VapeId", vapeId)
    primary:SetAttribute("VapeTipLocal", hand.CFrame:PointToObjectSpace(tipWorld))
    primary:SetAttribute("VapeUpLocal", hand.CFrame:VectorToObjectSpace(upWorld).Unit)
    primary:SetAttribute("VapeLength", math.max(0.1, maxY - minY))
end

-- Elimina el vape equipado actual.
function EquipmentService.Unequip(player)
    local character = player.Character
    if not character then
        return
    end
    local existing = character:FindFirstChild(MODEL_NAME)
    if existing then
        existing:Destroy()
    end
end

--[[ Construye y suelda el vape a la mano. vapeId debe estar comprado. ]]
function EquipmentService.Equip(player, vapeId)
    local cfg = VapeConfig.Vapes[vapeId]
    if not cfg then
        return false
    end

    local character = player.Character
    if not character then
        return false
    end

    -- Espera breve por si el personaje aun se esta cargando.
    local hand = findHand(character)
    if not hand then
        for _ = 1, 20 do
            task.wait(0.1)
            hand = findHand(character)
            if hand then
                break
            end
        end
    end
    if not hand then
        warn("[EquipmentService] No se encontro la mano de", player.Name)
        return false
    end

    EquipmentService.Unequip(player)

    local model = VapeFactory.Build(vapeId)
    if not model then
        return false
    end
    model.Name = MODEL_NAME
    model:SetAttribute("OwnerUserId", player.UserId)

    -- Coloca el modelo segun la configuracion de agarre.
    local hold = cfg.hold or {}
    local offset = hold.offset or Vector3.new(0, -0.2, -0.4)
    local rot = hold.rot or Vector3.new(0, 0, 0)
    local desired = hand.CFrame
        * CFrame.new(offset)
        * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

    model:PivotTo(desired)
    -- Se mide ANTES de parentar: asi los atributos llegan al cliente en el
    -- mismo paquete que el modelo y PuffAnimator nunca los ve a medias.
    measureVape(model, hand, vapeId)

    local primary = model.PrimaryPart
    local weld = Instance.new("Weld")
    weld.Name = "VapeWeld"
    weld.Part0 = hand
    weld.Part1 = primary
    weld.C0 = hand.CFrame:Inverse() * desired
    weld.C1 = CFrame.new()
    weld.Parent = primary

    model.Parent = character
    CollectionService:AddTag(model, "VapeModel")

    return true
end

return EquipmentService
