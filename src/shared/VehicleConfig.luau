--[[
    VehicleConfig
    Ruta en Roblox Studio: ReplicatedStorage > Shared > VehicleConfig
    Tipo: ModuleScript

    Catalogo de vehiculos. El PRECIO no se escribe aqui: vive en EconomyConfig
    (unica fuente de verdad de la economia) y se consulta con
    EconomyConfig.VehiclePrice(id). Este modulo solo describe QUE es cada
    vehiculo y COMO se conduce.

    Campos de cada vehiculo:
        id            identificador unico (string)
        name          nombre visible en el menu
        description   texto para la tarjeta del menu
        speed         velocidad objetivo al acelerar a fondo (studs/s)
        reverse       fraccion de `speed` que alcanza marcha atras
        turnRate      grados por segundo que gira con A/D a velocidad de crucero
        turnIdle      fraccion de `turnRate` disponible parado (poder pivotar)
        accelerate    studs/s^2 al acelerar (transicion suave)
        brake         studs/s^2 al frenar o soltar el acelerador
        lean          grados de inclinacion lateral al girar (animacion simple)
        clearance     separacion del suelo al desplegar/conducir (studs)
        climb         studs/s de subida suave del chasis al cambiar de nivel
        accent        color de acento en el menu y neon principal del modelo
        accent2       neon secundario del modelo (bajos / ruedas)
        icon          icono del dock y de las tarjetas
        layout        generador de modelo que usa VehicleFactory

    Anadir un vehiculo futuro = anadir una entrada aqui (y su precio en
    EconomyConfig) + un layout en VehicleFactory. No hay que tocar ni el
    servidor, ni el cliente, ni la interfaz: todo se construye desde esta lista.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local VehicleConfig = {}

-- Orden canonico del menu de vehiculos.
VehicleConfig.Order = { "scooter" }

VehicleConfig.Vehicles = {
    scooter = {
        id = "scooter",
        name = "PATINETE STREET",
        description = "Patinete urbano de una plaza: plataforma, dos ruedas y manillar. Agil para cruzar la ciudad.",
        speed = 24,          -- ~1,5x la velocidad de caminar (16) y por debajo del sprint
        reverse = 0.45,
        turnRate = 95,
        turnIdle = 0.45,
        accelerate = 26,
        brake = 40,
        lean = 10,
        clearance = 0.08,
        climb = 9,
        accent = Color3.fromRGB(255, 96, 190),
        accent2 = Color3.fromRGB(64, 226, 255),
        icon = "🛴",
        layout = "scooter",
    },
}

--[[ Devuelve la definicion de un vehiculo (o nil). ]]
function VehicleConfig.Get(id)
    if type(id) ~= "string" then
        return nil
    end
    return VehicleConfig.Vehicles[id]
end

--[[ Lista de vehiculos en el orden canonico, ignorando ids invalidos. ]]
function VehicleConfig.GetOrdered()
    local list = {}
    for _, id in ipairs(VehicleConfig.Order) do
        local cfg = VehicleConfig.Vehicles[id]
        if cfg then
            table.insert(list, cfg)
        end
    end
    return list
end

--[[ Precio en Puffs (delegado en EconomyConfig). ]]
function VehicleConfig.Price(id)
    return EconomyConfig.VehiclePrice(id)
end

--[[ Color de acento del vehiculo (para tarjetas y menu). ]]
function VehicleConfig.Accent(id)
    local cfg = VehicleConfig.Get(id)
    return (cfg and cfg.accent) or Color3.fromRGB(200, 204, 220)
end

return VehicleConfig
