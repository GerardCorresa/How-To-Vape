--[[
    ShopConfig
    Ruta en Roblox Studio: ReplicatedStorage > Shared > ShopConfig
    Tipo: ModuleScript

    Catalogo de los locales comerciales de la ciudad. Es AMBIENTACION del juego
    (no hay compra funcional): define nombre, rotulo, colores, escaparate e
    interior para que cada local sea reconocible y distinto.

    layout decide el mobiliario interior (ver ShopBuilder):
        counter    mostrador + mesas (restauracion)
        aisles     estanterias en pasillo (supermercado, farmacia...)
        racks      percheros y maniquies (ropa)
        tables     mesas expositoras (electronica)
        service    mostrador de atencion (barberia, banco, taller...)
        gym        sala de maquinas y esterillas
]]

local C = Color3.fromRGB

local ShopConfig = {}

ShopConfig.Order = {
    "burger", "pizza", "cafe", "donuts", "supermarket", "drinks",
    "urbanwear", "sneakers", "sportswear", "boutique",
    "mobiles", "computers", "electronics",
    "barber", "gym", "pharmacy", "laundry", "bank", "convenience",
    "workshop", "furniture",
}

ShopConfig.Shops = {
    burger = { name = "BURGER BLOCK", kind = "Hamburgueseria", layout = "counter",
        main = C(232, 132, 52), sub = C(38, 34, 32), awning = C(198, 70, 52), floor = C(146, 112, 88) },
    pizza = { name = "SLICE CORNER", kind = "Pizzeria", layout = "counter",
        main = C(214, 76, 58), sub = C(42, 36, 32), awning = C(150, 52, 44), floor = C(158, 122, 92) },
    cafe = { name = "PUFF COFFEE", kind = "Cafeteria", layout = "counter",
        main = C(122, 86, 58), sub = C(46, 40, 34), awning = C(92, 64, 44), floor = C(124, 92, 68) },
    donuts = { name = "SWEET RING", kind = "Pasteleria", layout = "counter",
        main = C(244, 140, 190), sub = C(50, 40, 48), awning = C(226, 108, 168), floor = C(196, 172, 196) },
    supermarket = { name = "MEGA MART", kind = "Supermercado", layout = "aisles",
        main = C(74, 176, 108), sub = C(34, 44, 38), awning = C(52, 148, 88), floor = C(206, 204, 196) },
    drinks = { name = "SIP & SNACK", kind = "Bebidas y snacks", layout = "aisles",
        main = C(96, 176, 226), sub = C(32, 40, 52), awning = C(70, 148, 208), floor = C(204, 206, 212) },

    urbanwear = { name = "STREET LINE", kind = "Ropa urbana", layout = "racks",
        main = C(140, 140, 150), sub = C(28, 28, 32), awning = C(60, 60, 68), floor = C(176, 176, 182) },
    sneakers = { name = "KICKS LAB", kind = "Zapatillas", layout = "racks",
        main = C(238, 196, 74), sub = C(34, 32, 28), awning = C(206, 160, 44), floor = C(212, 208, 196) },
    sportswear = { name = "RUN FAST", kind = "Ropa deportiva", layout = "racks",
        main = C(90, 214, 176), sub = C(30, 44, 42), awning = C(56, 184, 148), floor = C(200, 214, 208) },
    boutique = { name = "MAISON VAPE", kind = "Boutique", layout = "racks",
        main = C(206, 176, 226), sub = C(40, 34, 46), awning = C(174, 140, 200), floor = C(216, 206, 220) },

    mobiles = { name = "CELL POINT", kind = "Telefonia", layout = "tables",
        main = C(122, 158, 246), sub = C(30, 34, 46), awning = C(92, 128, 222), floor = C(202, 206, 216) },
    computers = { name = "BYTE STORE", kind = "Ordenadores", layout = "tables",
        main = C(126, 132, 148), sub = C(28, 30, 36), awning = C(88, 94, 110), floor = C(190, 192, 198) },
    electronics = { name = "VOLT CITY", kind = "Electronica", layout = "tables",
        main = C(240, 148, 62), sub = C(36, 32, 28), awning = C(212, 116, 40), floor = C(206, 200, 188) },

    barber = { name = "CUT CLUB", kind = "Barberia", layout = "service",
        main = C(206, 74, 74), sub = C(36, 32, 36), awning = C(168, 56, 60), floor = C(172, 168, 172) },
    gym = { name = "IRON PUFF", kind = "Gimnasio", layout = "gym",
        main = C(86, 96, 116), sub = C(26, 28, 34), awning = C(58, 66, 84), floor = C(120, 122, 130) },
    pharmacy = { name = "VITA PLUS", kind = "Farmacia", layout = "aisles",
        main = C(96, 214, 150), sub = C(32, 46, 40), awning = C(64, 188, 124), floor = C(214, 220, 216) },
    laundry = { name = "BUBBLE WASH", kind = "Lavanderia", layout = "service",
        main = C(148, 200, 234), sub = C(34, 42, 50), awning = C(112, 172, 216), floor = C(206, 214, 222) },
    bank = { name = "PUFF BANK", kind = "Banco", layout = "service",
        main = C(198, 176, 106), sub = C(34, 34, 30), awning = C(160, 138, 74), floor = C(196, 190, 174) },
    convenience = { name = "24/7 GO", kind = "Tienda de conveniencia", layout = "aisles",
        main = C(240, 96, 130), sub = C(38, 32, 42), awning = C(212, 68, 108), floor = C(212, 206, 210) },
    workshop = { name = "TORQUE GARAGE", kind = "Taller mecanico", layout = "service",
        main = C(120, 124, 132), sub = C(28, 28, 30), awning = C(90, 94, 102), floor = C(104, 104, 108) },
    furniture = { name = "HOME NEST", kind = "Muebles y decoracion", layout = "tables",
        main = C(178, 138, 96), sub = C(42, 36, 30), awning = C(146, 108, 70), floor = C(176, 152, 124) },
}

function ShopConfig.Get(id)
    return ShopConfig.Shops[id]
end

return ShopConfig
