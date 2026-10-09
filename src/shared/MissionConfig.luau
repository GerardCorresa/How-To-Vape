--[[
    MissionConfig
    Ruta en Roblox Studio: ReplicatedStorage > Shared > MissionConfig
    Tipo: ModuleScript

    Misiones de exploracion/progresion. Son ligeras: cada una mide un contador
    del perfil (metric) y se completa al alcanzar `target`. ProgressService
    las evalua tras cada evento relevante (calada, compra, descubrimiento,
    desbloqueo) y paga `reward` Puffs una sola vez (se guarda en profile.missions).

    metric posibles (se calculan de profile):
        puffsClicked   acciones de PUFF totales
        totalPuffs     Puffs acumulados en toda la partida
        districts      distritos descubiertos
        houses         casas desbloqueadas
        vapes          dispositivos comprados
        puffs          saldo actual de Puffs
]]

local MissionConfig = {}

MissionConfig.Order = {
    "first_puff", "explorer3", "agent", "collector5",
    "trotamundos", "magnate", "tycoon", "legend",
}

MissionConfig.Missions = {
    first_puff = {
        id = "first_puff", name = "PRIMERA CALADA",
        desc = "Da 10 caladas en la zona de fumadores.",
        metric = "puffsClicked", target = 10, reward = 60,
    },
    explorer3 = {
        id = "explorer3", name = "EXPLORADOR",
        desc = "Descubre 3 distritos de la ciudad.",
        metric = "districts", target = 3, reward = 200,
    },
    agent = {
        id = "agent", name = "INMUEBLES",
        desc = "Desbloquea el acceso a 2 casas.",
        metric = "houses", target = 2, reward = 350,
    },
    collector5 = {
        id = "collector5", name = "COLECCIONISTA",
        desc = "Consigue 5 dispositivos distintos.",
        metric = "vapes", target = 5, reward = 900,
    },
    trotamundos = {
        id = "trotamundos", name = "TROTAMUNDOS",
        desc = "Descubre los 8 distritos.",
        metric = "districts", target = 8, reward = 2500,
    },
    magnate = {
        id = "magnate", name = "MAGNATE",
        desc = "Desbloquea 6 casas.",
        metric = "houses", target = 6, reward = 6000,
    },
    tycoon = {
        id = "tycoon", name = "ACUMULADOR",
        desc = "Reune 40.000 Puffs en total.",
        metric = "totalPuffs", target = 40000, reward = 4000,
    },
    legend = {
        id = "legend", name = "LEYENDA",
        desc = "Consigue los 15 dispositivos.",
        metric = "vapes", target = 15, reward = 25000,
    },
}

function MissionConfig.Get(id)
    return MissionConfig.Missions[id]
end

function MissionConfig.GetOrdered()
    local list = {}
    for _, id in ipairs(MissionConfig.Order) do
        table.insert(list, MissionConfig.Missions[id])
    end
    return list
end

return MissionConfig
