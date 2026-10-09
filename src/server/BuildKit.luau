--[[
    BuildKit
    Ruta en Roblox Studio: ServerScriptService > BuildKit
    Tipo: ModuleScript

    Primitivas de construccion reutilizadas por CityBuilder y HouseBuilder.
    Centralizarlas evita duplicar codigo y garantiza que TODA la decoracion
    tenga las mismas propiedades fisicas correctas (anclada, sin colision
    cuando no hace falta, sin sombras en piezas pequenas para rendir).

    Solo servidor: el cliente nunca construye mapa.
]]

local BuildKit = {}

local M = Enum.Material

--[[ Crea una Part con valores por defecto sensatos y solo las propiedades
     indicadas. Evita repetir 10 lineas en cada llamada. ]]
function BuildKit.Part(props)
    local part = Instance.new("Part")
    part.Anchored = props.anchored ~= false
    part.CanCollide = props.canCollide == true
    part.CanQuery = props.canQuery ~= false
    part.CanTouch = false
    part.CastShadow = props.castShadow ~= false
    part.Material = props.material or M.SmoothPlastic
    part.Color = props.color or Color3.fromRGB(200, 200, 200)
    part.Size = props.size or Vector3.new(4, 4, 4)
    part.CFrame = props.cframe or CFrame.new(0, 0, 0)
    part.Transparency = props.transparency or 0
    part.Reflectance = props.reflectance or 0
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Name = props.name or "Part"
    if props.shape then
        part.Shape = props.shape
    end
    if props.parent then
        part.Parent = props.parent
    end
    return part
end

function BuildKit.Model(name, parent)
    local model = Instance.new("Model")
    model.Name = name
    if parent then
        model.Parent = parent
    end
    return model
end

--[[ Cartel con SurfaceGui. Acepta Vector3 o CFrame ya orientado.
     La cara visible del SurfaceGui es Front, que es la -Z local del cartel.
     Para que se lea hay que mirarlo desde "cf.LookVector invertido":
     usa CFrame.lookAt(boardPos, boardPos + direccionHaciaElLector). ]]
function BuildKit.Sign(text, posOrCF, color, parent, size, bg)
    local cf = typeof(posOrCF) == "CFrame" and posOrCF or CFrame.new(posOrCF)
    local board = BuildKit.Part({
        name = "SignBoard",
        size = size or Vector3.new(16, 6, 1),
        color = bg or Color3.fromRGB(18, 18, 24),
        material = M.SmoothPlastic,
        cframe = cf,
        parent = parent,
    })
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.CanvasSize = Vector2.new(640, 260)
    gui.Parent = board

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.TextWrapped = true
    label.Parent = gui
    return board
end

function BuildKit.Prompt(anchor, actionText, promptType, id, holdDuration)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = actionText
    prompt.ObjectText = "Interactuar"
    prompt.HoldDuration = holdDuration or 0
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt:SetAttribute("PromptType", promptType)
    prompt:SetAttribute("ZoneId", id)      -- compatibilidad: id de distrito o casa
    if promptType == "House" then
        prompt:SetAttribute("HouseId", id)
    end
    prompt.Parent = anchor
    return prompt
end

--[[ Arbol ligero: tronco + copa. Decorativo (sin colision). ]]
function BuildKit.Tree(position, parent, scale)
    scale = scale or 1
    local model = BuildKit.Model("Tree", parent)
    BuildKit.Part({
        name = "Trunk", size = Vector3.new(0.8, 5, 0.8) * scale,
        color = Color3.fromRGB(90, 62, 40), material = M.Wood,
        cframe = CFrame.new(position + Vector3.new(0, 2.5 * scale, 0)), parent = model,
    })
    local leafColor = Color3.fromRGB(70 + math.random(0, 40), 120 + math.random(0, 50), 70 + math.random(0, 30))
    BuildKit.Part({
        name = "Leaves", shape = Enum.PartType.Ball, size = Vector3.new(6, 6, 6) * scale,
        color = leafColor, material = M.Grass, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, 6 * scale, 0)), parent = model,
    })
    return model
end

function BuildKit.Bush(position, parent, scale)
    scale = scale or 1
    return BuildKit.Part({
        name = "Bush", shape = Enum.PartType.Ball, size = Vector3.new(2.6, 2.0, 2.6) * scale,
        color = Color3.fromRGB(72, 120, 70), material = M.Grass, castShadow = false,
        cframe = CFrame.new(position + Vector3.new(0, 0.9 * scale, 0)), parent = parent,
    })
end

--[[ Valla: fila de postes y travesanos a lo largo de una recta. ]]
function BuildKit.Fence(fromCF, length, parent, railColor)
    railColor = railColor or Color3.fromRGB(200, 200, 205)
    local model = BuildKit.Model("Fence", parent)
    local posts = math.max(2, math.floor(length / 6))
    for i = 0, posts do
        local t = i / posts
        local pos = fromCF * CFrame.new(0, 0, -length * t)
        BuildKit.Part({
            name = "Post", size = Vector3.new(0.4, 3.4, 0.4), color = railColor, material = M.Wood,
            castShadow = false, cframe = CFrame.new(pos.Position + Vector3.new(0, 1.7, 0)), parent = model,
        })
    end
    for _, h in ipairs({ 1.4, 2.8 }) do
        BuildKit.Part({
            name = "Rail", size = Vector3.new(0.25, 0.25, length), color = railColor, material = M.Wood,
            castShadow = false,
            cframe = fromCF * CFrame.new(0, h, -length / 2), parent = model,
        })
    end
    return model
end

function BuildKit.Lamppost(position, color, parent)
    local model = BuildKit.Model("Lamppost", parent)
    BuildKit.Part({
        name = "Pole", size = Vector3.new(0.6, 14, 0.6), color = Color3.fromRGB(45, 45, 52),
        material = M.Metal, cframe = CFrame.new(position + Vector3.new(0, 7, 0)), parent = model,
    })
    local head = BuildKit.Part({
        name = "Head", size = Vector3.new(1.4, 1.4, 1.4), color = color, material = M.Neon,
        cframe = CFrame.new(position + Vector3.new(0, 14.5, 0)), parent = model,
    })
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = 2
    light.Range = 26
    light.Shadows = false
    light.Parent = head
    return model
end

function BuildKit.Window(parent, cframe, size)
    return BuildKit.Part({
        name = "Window", size = size, color = Color3.fromRGB(150, 200, 230),
        material = M.Glass, transparency = 0.45, canCollide = false, castShadow = false,
        reflectance = 0.2, cframe = cframe, parent = parent,
    })
end

--[[ Caja de texto con nombre + frase opcional sobre una pieza (dealers). ]]
function BuildKit.FloatingLabel(anchor, title, subtitle, color)
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 240, 0, 74)
    billboard.StudsOffset = Vector3.new(0, 6, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = anchor

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.fromScale(1, 0.5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = title
    nameLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Parent = billboard

    if subtitle then
        local lineLabel = Instance.new("TextLabel")
        lineLabel.Position = UDim2.fromScale(0, 0.5)
        lineLabel.Size = UDim2.fromScale(1, 0.5)
        lineLabel.BackgroundTransparency = 1
        lineLabel.Font = Enum.Font.Gotham
        lineLabel.Text = subtitle
        lineLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
        lineLabel.TextScaled = true
        lineLabel.TextWrapped = true
        lineLabel.Parent = billboard
    end
    return billboard
end

return BuildKit
