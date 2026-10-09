--[[
    AnimConfig
    Ruta en Roblox Studio: ReplicatedStorage > Shared > AnimConfig
    Tipo: ModuleScript

    Parametros de la animacion de calada (PuffAnimator) y del humo de boca
    (MouthFX). Todo lo ajustable visualmente vive aqui.

    Unidades: distancias en studs, angulos en grados, tiempos en segundos.
    Los offsets de la boca se expresan como FRACCION del tamano de la cabeza,
    asi que escalan solos con avatares grandes o pequenos.
]]

local AnimConfig = {}

-- Secuencia de una calada -----------------------------------------------------
-- raise  : A -> B  subir el dispositivo hacia la boca
-- pause  : C       mantener cerca de la boca (inhalacion ficticia)
-- exhale : D       separar un poco y expulsar el humo
-- lower  : E       volver al reposo
-- Cada calada encadenada anade un ciclo pause+exhale (ver MaxQueue).
AnimConfig.Timeline = {
    Raise  = 0.42,
    Pause  = 0.30,
    Exhale = 0.40,
    Lower  = 0.55,
    MaxQueue = 6,     -- caladas encadenadas maximas antes de forzar el regreso
}

-- Mezcla con la animacion que ya este reproduciendo el Animator.
-- In: tiempo que tarda la accion en tomar el control del brazo.
AnimConfig.Blend = {
    In = 0.16,
}

-- Postura en la boca ---------------------------------------------------------
-- Offset: posicion de la PUNTA del dispositivo respecto al centro de la cabeza,
-- como fraccion del tamano de la cabeza. Z es una magnitud positiva que se
-- aplica hacia delante (la cara esta en -Z de la cabeza).
AnimConfig.Mouth = {
    Offset      = Vector3.new(0, -0.28, 0.50),
    Clearance   = 0.02,   -- separacion extra de la cara (studs)
    LengthFactor = 0.18,  -- separacion proporcional a la longitud del dispositivo
    TiltDeg     = 36,     -- inclinacion del dispositivo hacia la boca (grados)
    RollDeg     = 0,      -- giro de la muneca sobre el eje del dispositivo
    Separation  = 0.16,   -- cuanto se separa el dispositivo al expulsar (studs)
    ArcLift     = 0.12,   -- arco que describe el dispositivo al subir (studs)
}

-- Movimiento secundario (cabeza y torso) -------------------------------------
-- Angulos maximos; se aplican de forma progresiva con la subida.
AnimConfig.Secondary = {
    NeckPitch = -6,
    NeckYaw   = 5,
    WaistPitch = 2.5,
}

-- Wisp corto del dispositivo al empezar la calada (no es el humo de la boca) --
AnimConfig.DeviceWisp = {
    Count = 5,
}

-- Humo de la boca ------------------------------------------------------------
-- size/transparency son keypoints {t, valor} de 0 a 1.
AnimConfig.Smoke = {
    -- Nube principal
    Main = {
        count        = 11,
        lifetime     = { 1.1, 1.9 },
        speed        = { 2.0, 3.4 },
        size         = { { 0.00, 0.35 }, { 0.35, 1.15 }, { 1.00, 2.10 } },
        transparency = { { 0.00, 0.55 }, { 0.25, 0.45 }, { 1.00, 1.00 } },
        drag         = 3,
        spread       = 14,
        rotation     = { -25, 25 },
        rotSpeed     = { -35, 35 },
        color        = Color3.fromRGB(226, 226, 236),
    },
    -- Dispersion secundaria (mas tenue, mas ancha, se apaga antes)
    Secondary = {
        count        = 6,
        lifetime     = { 1.4, 2.3 },
        speed        = { 1.1, 2.1 },
        size         = { { 0.00, 0.20 }, { 0.40, 1.30 }, { 1.00, 2.70 } },
        transparency = { { 0.00, 0.72 }, { 0.30, 0.62 }, { 1.00, 1.00 } },
        drag         = 4,
        spread       = 28,
        rotation     = { -35, 35 },
        rotSpeed     = { -45, 45 },
        color        = Color3.fromRGB(205, 205, 220),
    },
    -- Deriva: se aplica como aceleracion, de modo que la direccion de salida no
    -- depende de como este orientado el Attachment (a prueba de convenciones).
    Forward = 5.5,
    Up      = 2.2,
    -- Textura opcional. Dejala vacia para usar el sprite redondo por defecto de
    -- Roblox. Si quieres una textura de humo, sube la tuya o usa una del Creator
    -- Store y pega aqui su rbxassetid (no se inventa ningun ID).
    Texture = "",
}

-- Animacion publicada opcional (NO implementada todavia) ----------------------
-- La calada se resuelve de forma procedural y no necesita subir nada a Roblox.
-- Si en el futuro quieres sustituirla por una animacion publicada, habria que
-- implementar la carga con Animator:LoadAnimation y usar AnimationId aqui.
-- Se deja el campo solo como marcador; ahora mismo no se lee.
-- AnimConfig.AnimationId = ""

AnimConfig.Debug = false

return AnimConfig
