--[[
    DoorClient
    Ruta en Roblox Studio: StarterPlayer > StarterPlayerScripts > DoorClient
    Tipo: ModuleScript (cliente)

    Gestiona las puertas de las casas EN LOCAL, de forma que el acceso sea
    realmente por jugador:

      * La puerta es una Part DEL SERVIDOR con colision (CanCollide = true) y
        cerrada. El servidor guarda ademas ClosedCFrame y OpenCFrame como
        atributos.
      * En el cliente, si el jugador ya desbloqueo la casa, se anula la colision
        SOLO en este cliente (door.CanCollide = false) y se anima la puerta a
        la posicion abierta. Para el resto de jugadores sigue cerrada hasta que
        ellos la desbloqueen.
      * Cambiar propiedades de una Part anclada del servidor en local persiste
        en ese cliente (el servidor no la vuelve a tocar), asi que no hay que
        replicar nada por la red ni usar grupos de colision.

    El estado real (permanente, sin recobrar) vive en el servidor
    (profile.houses). Esto solo refleja ese estado fisicamente.

    Requiere: (nada). Usa CollectionService.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local DoorClient = {}

local unlocked = {}          -- houseId -> true (espejo de profile.houses)
local doorState = {}         -- [door] -> true/false (estado ya aplicado)

local function applyDoor(door, force)
    local houseId = door:GetAttribute("HouseId")
    if not houseId then
        return
    end
    local wantOpen = unlocked[houseId] == true
    if doorState[door] == wantOpen and not force then
        return
    end
    doorState[door] = wantOpen

    local closed = door:GetAttribute("ClosedCFrame")
    local open = door:GetAttribute("OpenCFrame")

    if wantOpen then
        door.CanCollide = false
        if open and typeof(open) == "CFrame" then
            TweenService:Create(door, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { CFrame = open }):Play()
        end
    else
        door.CanCollide = true
        if closed and typeof(closed) == "CFrame" then
            door.CFrame = closed
        end
    end
end

--[[ Actualiza el estado global (mapa houseId -> true) y reaplica a las puertas. ]]
function DoorClient.SetUnlocked(map)
    unlocked = map or {}
    for _, door in ipairs(CollectionService:GetTagged("HouseDoor")) do
        applyDoor(door)
    end
end

function DoorClient.Init()
    for _, door in ipairs(CollectionService:GetTagged("HouseDoor")) do
        applyDoor(door, true)
    end
    CollectionService:GetInstanceAddedSignal("HouseDoor"):Connect(function(door)
        if door:IsA("BasePart") then
            task.defer(function()
                applyDoor(door, true)
            end)
        end
    end)
    CollectionService:GetInstanceRemovedSignal("HouseDoor"):Connect(function(door)
        doorState[door] = nil
    end)
end

return DoorClient
