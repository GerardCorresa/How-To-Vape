--[[
    UITheme
    Ruta en Roblox Studio: StarterPlayer > StarterPlayerScripts > UITheme
    Tipo: ModuleScript (cliente)

    SISTEMA DE DISENO de How to Vape. Aqui viven la paleta, la tipografia y los
    componentes (paneles, botones, tarjetas, modales, rejillas) para que TODA la
    interfaz comparta la misma identidad visual en vez de repetir numeros por
    varios archivos:

        * fondo oscuro + acentos neon (cian, azul electrico y morado),
        * esquinas redondeadas, bordes finos y borde superior luminoso,
        * estados de boton (normal / hover / pulsado / desactivado),
        * animaciones suaves con TweenService,
        * distribucion adaptable (fracciones de pantalla + UISizeConstraint
          + UIScale segun el tamano del viewport).

    No depende de ningun asset externo (nada de imagenes subidas): las sombras,
    brillos y degradados se hacen con Frame + UIGradient + UIStroke.

    Requiere: nada.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = {}

-- Paleta ----------------------------------------------------------------------
local C = {
    bg = Color3.fromRGB(9, 10, 17),
    panel = Color3.fromRGB(18, 20, 32),
    panel2 = Color3.fromRGB(24, 27, 42),
    panelHi = Color3.fromRGB(36, 40, 60),
    line = Color3.fromRGB(54, 60, 90),
    text = Color3.fromRGB(236, 240, 255),
    subtext = Color3.fromRGB(150, 158, 188),
    muted = Color3.fromRGB(104, 112, 140),
    cyan = Color3.fromRGB(64, 226, 255),
    blue = Color3.fromRGB(88, 132, 255),
    purple = Color3.fromRGB(176, 96, 255),
    pink = Color3.fromRGB(255, 96, 190),
    good = Color3.fromRGB(86, 240, 156),
    warn = Color3.fromRGB(255, 188, 84),
    bad = Color3.fromRGB(255, 92, 108),
    dark = Color3.fromRGB(7, 8, 14),
}
Theme.Palette = C
Theme.C = C

Theme.Font = {
    Black = Enum.Font.GothamBlack,
    Bold = Enum.Font.GothamBold,
    Med = Enum.Font.GothamMedium,
    Reg = Enum.Font.Gotham,
}

Theme.Radius = { sm = 8, md = 12, lg = 16, xl = 20, pill = 999 }

-- Utilidades de color ---------------------------------------------------------
function Theme.shade(color, f)
    if f >= 0 then
        return color:Lerp(Color3.new(1, 1, 1), f)
    end
    return color:Lerp(Color3.new(0, 0, 0), -f)
end

function Theme.alpha(color, a)
    -- No hay color con alfa en Roblox: se simula bajando la transparencia.
    return color, a
end


function Theme.new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" and string.sub(k, 1, 1) ~= "_" then
            inst[k] = v
        end
    end
    inst.Parent = parent
    return inst
end

function Theme.corner(gui, r)
    return Theme.new("UICorner", { CornerRadius = UDim.new(0, r or Theme.Radius.md) }, gui)
end

function Theme.stroke(gui, color, thickness, transparency)
    return Theme.new("UIStroke", {
        Color = color or C.line,
        Thickness = thickness or 1.4,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, gui)
end

function Theme.pad(gui, t, r, b, l)
    return Theme.new("UIPadding", {
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or t or 0),
        PaddingBottom = UDim.new(0, b or t or 0),
        PaddingLeft = UDim.new(0, l or r or t or 0),
    }, gui)
end

function Theme.gradient(gui, from, to, rotation)
    return Theme.new("UIGradient", {
        Color = ColorSequence.new(from, to),
        Rotation = rotation or 90,
    }, gui)
end

--[[ Sombra suave bajo un panel: un marco oscuro ligeramente mayor y difuminado
     por un degradado. Da profundidad sin usar imagenes. ]]
function Theme.shadow(gui, strength)
    local radius = 14
    local c = gui:FindFirstChildOfClass("UICorner")
    if c then
        radius = c.CornerRadius.Offset
    end
    local s = Theme.new("Frame", {
        Name = "Shadow", Size = UDim2.new(1, 6, 1, 10), Position = UDim2.fromOffset(-3, 4),
        AnchorPoint = Vector2.new(0, 0), BackgroundColor3 = C.dark,
        BackgroundTransparency = 1 - (strength or 0.5), BorderSizePixel = 0,
        ZIndex = (gui.ZIndex or 1) - 1,
    }, gui.Parent)
    Theme.corner(s, radius)
    s.ZIndex = (gui.ZIndex or 1) - 1
    return s
end

--[[ Filo luminoso en el borde superior: da el aire neon sin usar imagenes. ]]
function Theme.accentEdge(gui, color)
    local e = Theme.new("Frame", {
        Name = "AccentEdge", Size = UDim2.new(1, -18, 0, 2), Position = UDim2.new(0, 9, 0, 1),
        BackgroundColor3 = color or C.cyan, BorderSizePixel = 0, ZIndex = (gui.ZIndex or 1) + 2,
    }, gui)
    Theme.new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.15),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, e)
    return e
end

--[[ Panel con el estilo de la casa: fondo, degradado, borde y filo neon. ]]
function Theme.panel(props, parent)
    local p = Theme.new("Frame", {
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        ClipsDescendants = props and props._clip == true,
    }, nil)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" and k ~= "_corner" and k ~= "_accent" and k ~= "_clip" and k ~= "_flat"
            and string.sub(k, 1, 1) ~= "_" then
            p[k] = v
        end
    end
    p.Parent = parent
    Theme.corner(p, (props and props._corner) or Theme.Radius.lg)
    Theme.stroke(p, C.line, 1.4)
    if not (props and props._flat) then
        Theme.gradient(p, Theme.shade(C.panel, 0.06), Theme.shade(C.panel, -0.28), 90)
    end
    if props and props._accent then
        Theme.accentEdge(p, props._accent)
    end
    return p
end

--[[ Texto con jerarquia consistente. ]]
function Theme.label(props, parent)
    local l = Theme.new("TextLabel", {
        BackgroundTransparency = 1,
        Font = Theme.Font.Med,
        TextColor3 = C.text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, nil)
    for k, v in pairs(props or {}) do
        if string.sub(k, 1, 1) ~= "_" then
            l[k] = v
        end
    end
    l.Parent = parent
    return l
end

--[[ Etiqueta compacta tipo "pastilla" (multiplicador, rareza, estado). ]]
function Theme.pill(text, color, parent)
    local holder = Theme.new("Frame", {
        Size = UDim2.new(0, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.shade(color or C.cyan, -0.72), BorderSizePixel = 0,
    }, parent)
    Theme.corner(holder, 11)
    Theme.stroke(holder, color or C.cyan, 1, 0.25)
    Theme.pad(holder, 0, 10, 0, 10)
    local t = Theme.label({
        Size = UDim2.fromScale(1, 1), Text = text, Font = Theme.Font.Bold, TextSize = 12,
        TextColor3 = color or C.cyan, TextXAlignment = Enum.TextXAlignment.Center,
    }, holder)
    t.AutomaticSize = Enum.AutomaticSize.X
    holder.AutomaticSize = Enum.AutomaticSize.X
    return holder, t
end

--[[ Boton con estados normal / hover / pulsado / desactivado. `opts`:
        Accent     color de acento (borde en hover y relleno por defecto)
        Variant    "solid" | "ghost" | "danger" | "success"
        Text/Icon  contenido
        _handler   se puede reasignar luego (se lee en cada clic)
     Devuelve el TextButton. ]]
function Theme.button(props, parent)
    local opts = props or {}
    local b = Theme.new("TextButton", {
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Font = Theme.Font.Bold,
        TextSize = 16,
        TextColor3 = C.text,
    }, nil)
    for k, v in pairs(opts) do
        if k ~= "Parent" and k ~= "Accent" and k ~= "Variant" and k ~= "Icon"
            and string.sub(k, 1, 1) ~= "_" then
            b[k] = v
        end
    end
    b.Parent = parent

    local variant = opts.Variant or "solid"
    local accent = opts.Accent or C.cyan
    local base, textColor
    if variant == "solid" then
        base, textColor = accent, Theme.shade(accent, -0.86)
    elseif variant == "danger" then
        base, textColor = C.bad, Theme.shade(C.bad, -0.86)
    elseif variant == "success" then
        base, textColor = C.good, Theme.shade(C.good, -0.86)
    elseif variant == "ghost" then
        base, textColor = C.panel2, C.text
    else -- "soft"
        base, textColor = Theme.shade(accent, -0.72), accent
    end

    b.BackgroundColor3 = base
    b.TextColor3 = textColor
    Theme.corner(b, opts._corner or Theme.Radius.md)
    local st = Theme.stroke(b, variant == "ghost" and C.line or Theme.shade(base, 0.25), 1.4, 0.15)
    if variant == "soft" then
        st.Color = accent
        st.Transparency = 0.35
    end
    Theme.pad(b, 0, opts._padX or 10, 0, opts._padX or 10)

    if opts.Text then
        b.Text = opts.Text
    end
    if opts.Icon then
        b.Text = opts.Icon .. "   " .. (opts.Text or "")
    end

    local hover = {}
    local normal = {}
    --[[ En la variante "ghost" el hover se calcula sobre el color ACTUAL del
         boton (no sobre un gris fijo). Asi las tarjetas pueden pintar sus
         botones con su propio color de estado (comprar, equipar, desplegar,
         guardar) sin que pasar el raton los devuelva a gris. ]]
    local preHover = nil
    local ghostHover = nil
    local function style()
        if variant == "ghost" then
            hover = { BackgroundColor3 = C.panelHi, TextColor3 = C.text }
            normal = { BackgroundColor3 = C.panel2, TextColor3 = C.text }
        else
            hover = { BackgroundColor3 = Theme.shade(base, 0.16), TextColor3 = textColor }
            normal = { BackgroundColor3 = base, TextColor3 = textColor }
        end
    end
    style()

    local function tweenTo(tbl, time)
        TweenService:Create(b, TweenInfo.new(time or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), tbl):Play()
    end

    b.MouseEnter:Connect(function()
        if b.Active == false then
            return
        end
        if variant == "ghost" then
            preHover = { BackgroundColor3 = b.BackgroundColor3, TextColor3 = b.TextColor3 }
            ghostHover = { BackgroundColor3 = Theme.shade(b.BackgroundColor3, 0.18), TextColor3 = b.TextColor3 }
            tweenTo(ghostHover)
        else
            tweenTo(hover)
        end
        st.Color = accent
        st.Transparency = 0.05
    end)
    b.MouseLeave:Connect(function()
        if b.Active == false then
            preHover, ghostHover = nil, nil
            return
        end
        if preHover then
            tweenTo(preHover)
        else
            tweenTo(normal)
        end
        preHover, ghostHover = nil, nil
        st.Color = variant == "ghost" and C.line or Theme.shade(base, 0.25)
        st.Transparency = 0.15
    end)
    b.MouseButton1Down:Connect(function()
        if b.Active == false then
            return
        end
        if variant == "ghost" then
            tweenTo({ BackgroundColor3 = Theme.shade(b.BackgroundColor3, -0.18), TextColor3 = b.TextColor3 }, 0.06)
        else
            tweenTo({ BackgroundColor3 = Theme.shade(base, -0.18) }, 0.06)
        end
    end)
    b.MouseButton1Up:Connect(function()
        if b.Active == false then
            return
        end
        if variant == "ghost" and ghostHover then
            tweenTo(ghostHover)
        else
            tweenTo(hover)
        end
    end)

    b:GetPropertyChangedSignal("Active"):Connect(function()
        if b.Active == false then
            tweenTo({ BackgroundColor3 = Theme.shade(C.panel2, -0.15), TextColor3 = C.muted })
            st.Transparency = 0.6
        else
            -- No se repinta el fondo al reactivar: el codigo que lo reactiva
            -- decide su color acto seguido (verde al equipar, ambar al guardar,
            -- etc.). Repintarlo aqui borraria esa distincion.
            st.Transparency = 0.15
        end
    end)

    return b
end

function Theme.iconButton(icon, props, parent)
    local p = props or {}
    p.Icon = icon
    p.Text = nil
    p.TextSize = p.TextSize or 22
    p._corner = p._corner or Theme.Radius.md
    if p.Size == nil then
        p.Size = UDim2.fromOffset(58, 58)
    end
    return Theme.button(p, parent)
end

--[[ Rejilla que se reparte el ancho disponible: calcula sola el numero de
     columnas, de forma que el inventario se ve bien en PC, tablet y movil. ]]
function Theme.autoGrid(scroll, minCellW, cellH, padding)
    local grid = Theme.new("UIGridLayout", {
        CellSize = UDim2.new(0, minCellW, 0, cellH),
        CellPadding = UDim2.new(0, padding, 0, padding),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)
    local function update()
        local w = scroll.AbsoluteSize.X - (scroll.ScrollBarThickness or 6) - 4
        if w <= minCellW * 0.5 then
            return
        end
        local cols = math.max(1, math.floor((w + padding) / (minCellW + padding)))
        local cw = math.floor((w - padding * (cols - 1)) / cols)
        grid.CellSize = UDim2.new(0, cw, 0, cellH)
    end
    scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
    update()
    return grid
end

--[[ Lista vertical con separacion uniforme. ]]
function Theme.vlist(holder, padding)
    return Theme.new("UIListLayout", {
        Padding = UDim.new(0, padding or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, holder)
end

-- Adaptacion a la pantalla ----------------------------------------------------
--[[ Aplica un UIScale que se recalcula al cambiar el viewport. Se usa en los
     elementos de HUD con tamano en offsets para que no se solapen ni se salgan
     en pantallas pequenas. ]]
function Theme.autoScale(gui, baseW, baseH, minScale, maxScale)
    local scale = Theme.new("UIScale", {}, gui)
    local cam = Workspace.CurrentCamera
    local function update()
        local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
        local s = math.min(vp.X / (baseW or 1600), vp.Y / (baseH or 900))
        scale.Scale = math.clamp(s, minScale or 0.7, maxScale or 1.1)
    end
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(update)
    end
    update()
    return scale
end

-- Animaciones -----------------------------------------------------------------
function Theme.slideIn(gui, distance, time)
    local target = gui.Position
    gui.Position = target + UDim2.fromOffset(0, distance or 18)
    TweenService:Create(gui, TweenInfo.new(time or 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Position = target }):Play()
end

function Theme.pulse(gui, color, time)
    local base = gui.TextColor3 or C.text
    local tw = TweenService:Create(gui, TweenInfo.new((time or 0.5) * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { TextColor3 = color or C.cyan, TextTransparency = 0 })
    tw:Play()
    tw.Completed:Connect(function()
        TweenService:Create(gui, TweenInfo.new((time or 0.5) * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { TextColor3 = base }):Play()
    end)
end

function Theme.flash(gui, color, time)
    if not gui or not gui.Parent then
        return
    end
    TweenService:Create(gui, TweenInfo.new((time or 0.4) * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = color or C.cyan,
    }):Play()
    task.delay(time or 0.4, function()
        if gui.Parent then
            TweenService:Create(gui, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                BackgroundColor3 = C.panel,
            }):Play()
        end
    end)
end

--[[ Modal estandar: fondo oscurecido + panel centrado + cabecera + cuerpo.
     Devuelve las piezas para que cada menu las rellene. ]]
function Theme.modal(parent, opts)
    opts = opts or {}
    local z = opts.ZIndex or 20
    local overlay = Theme.new("TextButton", {
        Name = (opts.name or "Modal") .. "Overlay",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(4, 5, 10),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = z,
    }, parent)

    local panel3 = Theme.new("Frame", {
        Name = opts.name or "Modal",
        Size = UDim2.new(opts.width or 0.86, 0, opts.height or 0.84, 0),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = z + 1,
    }, parent)
    Theme.corner(panel3, Theme.Radius.xl)
    Theme.stroke(panel3, C.line, 1.4)
    Theme.gradient(panel3, Theme.shade(C.panel, 0.07), Theme.shade(C.panel, -0.3), 90)
    Theme.accentEdge(panel3, opts.accent or C.cyan)
    local maxS = opts.maxSize or Vector2.new(1000, 720)
    Theme.new("UISizeConstraint", { MaxSize = Vector2.new(maxS.X - 8, maxS.Y - 8) }, panel3)

    local header = Theme.new("Frame", {
        Name = "Header", Size = UDim2.new(1, -40, 0, 62), Position = UDim2.fromOffset(20, 12),
        BackgroundTransparency = 1, ZIndex = z + 2,
    }, panel3)
    Theme.new("Frame", {
        Name = "HeaderLine", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 2),
        BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = z + 2,
    }, header)

    local title = Theme.label({
        Name = "Title", Size = UDim2.new(1, -70, 0, 30), Position = UDim2.fromOffset(0, 2),
        Text = opts.title or "", Font = Theme.Font.Black, TextSize = 28, TextColor3 = C.text,
        ZIndex = z + 3,
    }, header)
    local subtitle = Theme.label({
        Name = "Subtitle", Size = UDim2.new(1, -70, 0, 22), Position = UDim2.fromOffset(0, 34),
        Text = opts.subtitle or "", Font = Theme.Font.Med, TextSize = 14, TextColor3 = C.subtext,
        ZIndex = z + 3,
    }, header)

    local close = Theme.button({
        Name = "Close", Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -38, 0, 4),
        Text = "X", Variant = "ghost", Accent = C.bad, TextSize = 18, ZIndex = z + 3,
        _corner = Theme.Radius.sm,
    }, header)

    local footerH = opts.footerHeight or 0
    local body = Theme.new("Frame", {
        Name = "Body", Size = UDim2.new(1, -40, 1, -(96 + footerH)), Position = UDim2.fromOffset(20, 82),
        BackgroundTransparency = 1, ZIndex = z + 2,
    }, panel3)

    local footer = Theme.new("Frame", {
        Name = "Footer", Size = UDim2.new(1, -40, 0, footerH),
        Position = UDim2.new(0, 20, 1, -(footerH + 20)),
        BackgroundTransparency = 1, ZIndex = z + 2,
    }, panel3)

    local api
    local function setVisible(v)
        overlay.Visible = v
        panel3.Visible = v
        if v then
            Theme.slideIn(panel3, 16)
        end
    end
    overlay.MouseButton1Click:Connect(function()
        setVisible(false)
        if api.OnClose then
            api.OnClose()
        end
    end)
    close.MouseButton1Click:Connect(function()
        setVisible(false)
        if api.OnClose then
            api.OnClose()
        end
    end)

    api = {
        overlay = overlay,
        frame = panel3,
        header = header,
        title = title,
        subtitle = subtitle,
        body = body,
        footer = footer,
        closeButton = close,
        SetVisible = setVisible,
        IsVisible = function() return panel3.Visible end,
    }
    return api
end

return Theme
