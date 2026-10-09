--[[
    Net
    Ruta en Roblox Studio: ReplicatedStorage > Shared > Net
    Tipo: ModuleScript

    Acceso unico a los Remotes. En el servidor crea la carpeta Remotes y los
    objetos si no existen; en el cliente los espera. Evita duplicar nombres y
    garantiza que cliente y servidor usan exactamente los mismos eventos.

    Requiere: GameConfig (mismo directorio).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Net = {}
local cache = {}

--[[ Solo en el servidor: crea la carpeta y los Remotes una sola vez. ]]
function Net.init()
    if not RunService:IsServer() then
        return
    end
    local folder = ReplicatedStorage:FindFirstChild(GameConfig.RemotesFolderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = GameConfig.RemotesFolderName
        folder.Parent = ReplicatedStorage
    end
    for name, class in pairs(GameConfig.RemoteTypes) do
        if not folder:FindFirstChild(name) then
            local remote = Instance.new(class)
            remote.Name = name
            remote.Parent = folder
        end
    end
end

--[[ Devuelve el Remote por nombre (crea/espera segun el lado). ]]
function Net.get(name)
    if cache[name] then
        return cache[name]
    end
    local folder
    if RunService:IsServer() then
        folder = ReplicatedStorage:FindFirstChild(GameConfig.RemotesFolderName)
        if not folder then
            Net.init()
            folder = ReplicatedStorage:WaitForChild(GameConfig.RemotesFolderName)
        end
    else
        folder = ReplicatedStorage:WaitForChild(GameConfig.RemotesFolderName)
    end
    local remote = folder:WaitForChild(name)
    cache[name] = remote
    return remote
end

return Net
