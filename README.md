# HOW TO VAPE

Simulador de progresión por Puffs ambientado en una ciudad abierta de Roblox.
Este repositorio contiene **el código fuente en Luau** y se sincroniza con
Roblox Studio usando **Rojo**.

Todo el contenido de vapeo es ficticio y propio del videojuego. No hay
instrucciones reales sobre consumo de nicotina.

Estado actual: **FASE 1 (arquitectura y configuración)** y **FASE 2 (mecánica
principal)** terminadas. La ciudad se genera por código, así que no hay que
colocar nada a mano.

---

## 1. Estructura del proyecto

```
How to vape/
├── default.project.json     <- mapa para Rojo (archivo clave)
├── rokit.toml               <- manifiesto de herramientas (opcional)
├── .gitignore
├── README.md
├── tools/
│   └── Build-Place.ps1      <- genera HowToVape.rbxlx sin necesidad de Rojo
└── src/
    ├── shared/              -> ReplicatedStorage > Shared   (ModuleScripts)
    │   ├── GameConfig.luau      balance, tiempos, nombres de remotos
    │   ├── AnimConfig.luau      parámetros de la animación de calada y del humo
    │   ├── VapeConfig.luau      los 15 vapers: precio, multiplicador, geometría
    │   ├── VehicleConfig.luau   catálogo de vehículos (velocidad, giro, acento)
    │   ├── EconomyConfig.luau   rarezas, precios y precios de vehículos
    │   ├── MissionConfig.luau   misiones y recompensas
    │   ├── ShopConfig.luau      los 21 locales comerciales
    │   ├── CityGrid.luau        retícula urbana compartida (calles, plaza, bloques)
    │   ├── ZoneConfig.luau      zonas, requisitos, dealers y casas
    │   ├── VapeFactory.luau     construye los modelos de los vapers
    │   ├── VehicleFactory.luau  construye los modelos de los vehículos (patinete)
    │   └── Net.luau             acceso único a los Remotes
    ├── server/              -> ServerScriptService          (Scripts/ModuleScripts)
    │   ├── MainServer.server.luau     Script · bootstrap del servidor
    │   ├── PlayerDataService.luau     ModuleScript · DataStores y perfil
    │   ├── PuffService.luau           ModuleScript · PUFF autoritativo
    │   ├── ShopService.luau           ModuleScript · compras/equipamiento
    │   ├── EquipmentService.luau      ModuleScript · vape en la mano + medición
    │   ├── ZoneService.luau           ModuleScript · desbloqueo de zonas
    │   ├── AccessService.luau         ModuleScript · acceso a casas
    │   ├── ProgressService.luau       ModuleScript · progreso y misiones
    │   ├── BuildKit.luau              ModuleScript · primitivas de construcción
    │   ├── CityKit.luau               ModuleScript · geometría urbana + presupuesto de luces
    │   ├── CityLayout.luau            ModuleScript · manzanas, solares y perfiles
    │   ├── TowerBuilder.luau          ModuleScript · rascacielos decorativos
    │   ├── BuildingBuilder.luau       ModuleScript · edificios por arquetipo
    │   ├── ShopBuilder.luau           ModuleScript · locales con interior
    │   ├── PlazaBuilder.luau          ModuleScript · plaza central y spawn
    │   ├── HouseBuilder.luau          ModuleScript · casas con dealer
    │   ├── VehicleService.luau        ModuleScript · compra/despliegue/limpieza de vehículos
    │   └── CityBuilder.luau           ModuleScript · orquesta toda la ciudad
    └── client/              -> StarterPlayer > StarterPlayerScripts
        ├── ClientController.client.luau   LocalScript · lógica de cliente
        ├── PuffAnimator.luau              ModuleScript · animación de la calada (IK)
        ├── MouthFX.luau                   ModuleScript · humo que sale de la boca
        ├── DoorClient.luau                ModuleScript · puertas locales
        ├── MovementController.luau        ModuleScript · sprint con SHIFT IZQUIERDO
        ├── VehicleController.luau         ModuleScript · conducción del patinete
        ├── UITheme.luau                   ModuleScript · sistema de diseño (colores, paneles, modales)
        └── UIModule.luau                  ModuleScript · toda la interfaz
```

> `HowToVape.rbxlx` no aparece en el árbol porque se genera (y `.gitignore` lo
> excluye). Ver la sección 10.

### Convención de nombres de Rojo

Rojo decide el **tipo** de instancia por el sufijo del nombre del archivo:

| Archivo en disco                | Se convierte en  | Nombre en Studio       |
| ------------------------------- | ---------------- | ---------------------- |
| `MainServer.server.luau`        | `Script`         | `MainServer`           |
| `ClientController.client.luau`  | `LocalScript`    | `ClientController`     |
| `UIModule.luau`                 | `ModuleScript`   | `UIModule`             |
| `carpeta/init.luau`             | la propia carpeta| nombre de la carpeta   |

Por eso el nombre del archivo **debe** llevar `.server` o `.client` cuando
corresponda. Si copias archivos a mano y te olvidas del sufijo, Rojo los
creará como `ModuleScript` y el script **nunca se ejecutará**.

---

## 2. Requisitos

- **Windows** (probado en Windows 10/11).
- **Roblox Studio** actualizado.
- **Rojo 7.3 o superior** (la versión 7.3 fue la primera en entender los
  archivos `.luau`; con una versión anterior tendrías que renombrar a `.lua`).

> `src/server/` no incluye ningún archivo `init.luau`, y `ReplicatedStorage/Shared`
> se declara como carpeta normal. Eso es intencionado y no hay que cambiarlo.

---

## 3. Comprobar si Rojo está instalado

Abre **PowerShell** y ejecuta:

```powershell
rojo --version
```

- Si responde con algo tipo `Rojo 7.4.4`, ya lo tienes instalado. Salta al
  paso 4.
- Si responde `El término 'rojo' no se reconoce...` (o `command not found`),
  **no está instalado**: ve al paso 3-bis.

> En esta máquina, a fecha de hoy, `rojo --version` **falla**: Rojo no está
> instalado. Tampoco hay `rokit`, `aftman`, `foreman` ni `cargo` en el PATH.
> Sí hay Git (`git version 2.55.0.windows.5`), pero la carpeta **no** es un
> repositorio Git todavía.

### 3-bis. Instalar Rojo

Elige **una** de las opciones. La Opción 1 es la más directa y no depende de
gestores de paquetes.

#### Opción 1 — Descargar el ejecutable (recomendada)

1. Abre la página de versiones:
   <https://github.com/rojo-rbx/rojo/releases>
2. En la última versión, descarga el archivo
   `rojo-<version>-windows-x86_64.zip`.
3. Descomprímelo y copia `rojo.exe` a una carpeta fija, por ejemplo
   `C:\Users\gcorr\rojo\rojo.exe`.
4. Añade esa carpeta al **PATH de usuario**. En PowerShell (una sola vez):

   ```powershell
   [Environment]::SetEnvironmentVariable(
     "Path",
     [Environment]::GetEnvironmentVariable("Path","User") + ";$env:USERPROFILE\rojo",
     "User"
   )
   ```

5. **Cierra y vuelve a abrir** la terminal (y Cursor, si lo tenías abierto
   con la terminal integrada), para que herede el PATH nuevo.
6. Comprueba otra vez:

   ```powershell
   rojo --version
   ```

#### Opción 2 — Rokit o Aftman (gestores de herramientas de Roblox)

1. Instala el gestor desde sus versiones oficiales:
   - Rokit: <https://github.com/rojo-rbx/rokit/releases>
   - Aftman: <https://github.com/LPGhatguy/aftman/releases>
2. En la raíz de este proyecto, añade Rojo:

   ```powershell
   rokit add rojo-rbx/rojo
   ```

   o, con Aftman:

   ```powershell
   aftman add rojo-rbx/rojo
   ```

   Ese comando actualiza el manifiesto (`rokit.toml` /
   `aftman.toml`) con la última versión y la instala.
3. Si ya existe `rokit.toml` (en este proyecto está creado con la versión
   `7.4.4`), simplemente ejecuta:

   ```powershell
   rokit install
   ```

   Si esa versión ya no existe, `rokit install` dará error: abre
   <https://github.com/rojo-rbx/rojo/releases>, copia el número de la última
   versión y sustitúyelo en `rokit.toml`.

#### Opción 3 — Cargo (si tienes Rust)

```powershell
cargo install rojo
```

Requiere tener Rust y `cargo` en el PATH. En esta máquina **no** hay `cargo`.

---

## 4. Abrir el proyecto en Cursor

1. Abre Cursor.
2. `File > Open Folder...` y elige `C:\Users\gcorr\Desktop\How to vape`.
3. Abre una terminal integrada: `Terminal > New Terminal`. Debe aparecer
   situada en la raíz del proyecto.
4. Confirma que ves `default.project.json` y la carpeta `src/`.

---

## 5. Arrancar el servidor de Rojo

En la terminal integrada de Cursor, con la raíz del proyecto como directorio
actual:

```powershell
rojo serve
```

Salida esperada (algo parecido a):

```
Rojo 7.4.4
Serving on localhost:34872
```

Notas:

- `rojo serve` busca automáticamente un archivo `default.project.json` en el
  directorio actual. Si prefieres ser explícito:
  `rojo serve default.project.json`.
- El puerto por defecto es **34872**.
- **Deja esa terminal abierta**: es el canal de sincronización. Si la cierras,
  Studio se desconecta.

---

## 6. Instalar el plugin de Rojo en Roblox Studio

Elige **una** de las dos vías:

- **Vía A (CLI).** Con Rojo instalado, ejecuta (puede ser en otra terminal):

  ```powershell
  rojo plugin install
  ```

  Esto coloca el plugin en la carpeta de plugins de Roblox Studio.

- **Vía B (Creator Store).** Abre Roblox Studio, ve a la pestaña **Plugins** y
  busca **Rojo** en el Creator Store / Toolbox de plugins. Instálalo.

Después, **reinicia Roblox Studio** para que cargue el plugin.

---

## 7. Conectar Studio con Rojo

1. Abre Roblox Studio y crea/abre un sitio (Baseplate vacío está bien).
2. Pestaña **Plugins** > botón **Rojo**. Se abre un panel.
3. Verifica que la dirección es `localhost` y el puerto `34872`.
4. Pulsa **Connect**.
5. Comprueba que la conexión funciona:
   - El panel de Rojo deja de mostrar "Disconnected".
   - En el **Explorer** de Studio aparecen
     `ReplicatedStorage.Shared` (con los 5 ModuleScripts),
     `ServerScriptService` (con `MainServer`, los servicios y `CityBuilder`) y
     `StarterPlayer > StarterPlayerScripts` (con `ClientController` y `UIModule`).
   - Arriba del panel de Rojo aparece el nombre del proyecto: **HowToVape**.
   - La ventana **Output** de Studio no muestra errores de Rojo.

Prueba de sincronización en vivo: edita cualquier `.luau` en Cursor y guarda.
El cambio debe aparecer en Studio en uno o dos segundos, sin tocar nada.

---

## 8. Habilitar DataStores para probar el guardado

El sistema de guardado usa `DataStoreService`. Por defecto, en Studio el
proyecto usa un **almacén en memoria** para que puedas probar sin configurar
nada (verás en Output: `[PlayerDataService] Usando almacen en memoria`).

Para probar el guardado real:

1. En Studio: `Game Settings` > `Security` > activa
   **Allow Studio Access to API Services**.
2. En Cursor, abre `src/shared/GameConfig.luau` y cambia:

   ```lua
   GameConfig.StudioUseDataStore = false  -- -> true
   ```

   (`GameConfig.DataStoreEnabled` ya viene en `true`.)

3. Detén y vuelve a iniciar la sesión de prueba.

En un juego **publicado** no hace falta tocar `StudioUseDataStore`: el valor
`false` solo afecta a Studio.

> Importante: si la carga de datos falla tras los reintentos, el servidor
> **expulsa al jugador** en lugar de guardar un perfil vacío encima. Es
> deliberado: así nunca se pierde el progreso real.

---

## 9. Cómo probar el juego

Dentro de Studio, pulsa **Play** (F5). El `CityBuilder` construye la ciudad al
arrancar, así que el mapa no aparece hasta que se inicia la partida.

Lista de comprobación:

1. **Apareces** en la plaza, dentro del círculo azul, con el BASIC VAPE en la mano.
   Mira al horizonte: las torres de las cuatro esquinas (±390, ±390) se ven
   desde el spawn.
2. **Botón PUFF** (abajo, en el centro) -> el brazo sube, el vape se acerca a la
   boca, hay una pausa breve, **sale humo de la boca** y el brazo baja solo. El
   contador sube `+1`.
3. **Sálete de la zona azul** y pulsa PUFF -> aviso de que hay que ir a la
   zona de fumadores. (Puedes desactivarlo con
   `GameConfig.RequireSmokingZone = false`.)
4. **Camina al dealer `ROOKIE`** (a unos 77 studs de la plaza) -> verás su
   nombre y su frase flotando sobre él.
5. **Acércate al dealer y mantén el prompt** (o abre el dock `MENU > TIENDA DEL
   DEALER` si ya desbloqueaste su casa) -> se abre la tienda (el `ROOKIE` no
   vende nada, te lo explica).
6. **Junta 1.200 Puffs** para descubrir `OLD TOWN` (los distritos son
   transitables libremente; el requisito es un hito que revela el distrito en
   el mapa y da recompensa). En la puerta de cada zona hay un arco con cartel.
7. **Casa `CASA N.1` (dealer `NICO`)**: cuesta 100 Puffs de acceso. Entra,
   compra el **NEON VAPE** (100 Puffs) y equípalo desde la tarjeta del
   inventario. El contador pasa a `+2 por calada` y el modelo de tu mano cambia.
8. **Dock derecho `VAPERS`** (o la tecla `I`): verás la cuadrícula de los 15
   vapers con vista 3D, multiplicador, rareza, precio, Puffs que faltan y la
   marca de cuál llevas equipado.
9. **Sigue la progresión**: vapers a 300 (CYBER), 700 (HYPER), 1.400 (GALAXY),
   2.600 (TITAN)…; casas a 350 / 800 / 1.600 / 3.000 / 5.000 / 9.000…; y
   distritos que se descubren a 2.400 / 4.200 / 7.000 / 13.000 / 25.000.
   Todos los números viven en `EconomyConfig.luau`.
10. **Sal y vuelve a entrar** (en Studio: `Stop` y `Play` otra vez, o con
    `StudioUseDataStore` activo) -> Puffs, vapers comprados, vape equipado y
    zonas desbloqueadas deben persistir.

Comprobaciones de interfaz (la barra de tienda inferior ya no existe):

- El **botón PUFF** queda centrado abajo y libre: el dock (`MENU`, `VAPERS`,
  `VEHICULOS`) está pegado al borde derecho, centrado en vertical, así que no se
  solapan en ninguna resolución.
- Prueba `1920x1080`, `1280x720` y el emulador de móvil/tablet de Studio
  (`Test > Device`): los paneles se reescalan solos (`UIScale` + fracciones).
- `ESC` cierra el panel abierto; `M` menú, `I` inventario, `V` vehículos,
  `K` mapa, `J` misiones.

Pruebas anti-manipulación (rápidas):

- El cliente **nunca** envía cantidades: `PuffRequest` solo pide "una calada" y
  el servidor recalcula `1 × multiplicador` desde el perfil guardado.
- Intenta comprar sin estar cerca de un dealer: aparece *"Acercate al dealer
  para comprar."*
- Intenta equipar algo que no tienes: aparece *"No tienes ese dispositivo."*
- Pulsa PUFF muy rápido: el servidor aplica un cooldown de `0.5 s` y descarta
  el resto.

### Probar vapers, vehículos y sprint (checklist de aceptación)

Todo lo que sigue se puede ejecutar en Studio con **Play** (F5), en modo
`Server & Clients` (`Test > Clients and Servers > 2 players`) cuando haga falta
comprobar el reparto servidor/cliente. Para el dinero rápido usa la consola del
servidor: `require(game.ServerScriptService.PlayerDataService)` y ajusta
`profile.puffs` desde una sesión de Studio, o simplemente pon
`GameConfig.StartingPuffs = 500` en una prueba suelta.

| # | Prueba | Cómo hacerlo | Resultado esperado |
|---|--------|--------------|--------------------|
| 1 | Saldo insuficiente | Con < 500 Puffs, `VEHICULOS > COMPRAR` | El botón dice `FALTAN n`, está desactivado y el servidor responde *"Te faltan n Puffs"*. No se cobra nada. |
| 2 | Compra exacta | Con 500 Puffs, `COMPRAR 500` | Se descuentan 500 **una sola vez** y el saldo queda en 0. Notificación *"Has comprado el PATINETE STREET"*. |
| 3 | Aparece en el menú | Vuelve a mirar la tarjeta | Estado `COMPRADO`, botón `SACAR A LA CALLE` activo. |
| 4 | Sin doble cobro | Pulsa `SACAR`, `GUARDAR` y vuelve a pulsar el botón de compra (ahora `YA ES TUYO`) | Nunca se vuelve a cobrar. El botón de compra queda desactivado. |
| 5 | Desplegar / conducir / bajar / repetir | `SACAR A LA CALLE` → `E` sobre el patinete → `WASD` → `ESPACIO` → `SACAR` otra vez | El patinete aparece al lado, se conduce con `WASD`, se frena con `S`, se gira con `A/D`, te bajas con `ESPACIO` y puedes volver a desplegarlo sin pagar. |
| 6 | Un solo vehículo | Pulsa `SACAR` dos veces seguidas | No se crean copias: aviso *"Ya tienes el PATINETE STREET desplegado"* y sigue habiendo **un** modelo en `workspace.HowToVape_Vehicles`. |
| 7 | Compra de vaper + equipar | Dealer → compra `NEON` → `VAPERS > EQUIPAR` | Sube `+2 Puffs` por calada, el modelo de la mano cambia y la tarjeta queda marcada como equipada. |
| 8 | Sprint | Mantén `SHIFT IZQ` y suéltalo | Pasa de 16 a 24 studs/s con transición suave (0,22 s) y vuelve a 16 al soltar. |
| 9 | Sprint + patinete | Conduce el patinete manteniendo `SHIFT` | La velocidad del patinete no cambia (24 studs/s). Al bajarte vuelves a caminar/correr con normalidad. |
| 10 | Sin coches decorativos | Recorre aparcamientos y avenidas | No hay ningún `ParkedCar`, ni ruedas ni sombras sueltas. Se conservan aparcamientos, plazas pintadas, aceras, farolas y edificios. |
| 11 | Persistencia | Compra un vaper y el patinete, luego `Stop` y `Play` (con `StudioUseDataStore = true`) | Vapers, vaper equipado y patinete siguen desbloqueados. El patinete aparece **guardado**, no desplegado: es estado de sesión. |
| 12 | Sin solapamientos | `1920x1080`, `1280x720` y `Test > Device` (móvil) | El dock (`MENU`, `VAPERS`, `VEHICULOS`) sigue en el borde derecho sin tapar el contador de Puffs, la tarjeta del vaper equipado ni el botón PUFF. |

Notas de las pruebas 5, 6 y 11:

- El despliegue busca hueco con raycast: si estás pegado a una pared y no hay
  sitio, sale *"No hay sitio libre a tu lado"* y no se crea nada.
- Al **morir** o **salir del servidor** el vehículo se retira solo (no se pierde
  la propiedad); se puede volver a desplegar.
- Si el patinete cae fuera del mapa (`Y < -30`) se limpia automáticamente.
- `VehicleConfig.luau` + `EconomyConfig.VehiclePrices` son las **dos únicas**
  fuentes de verdad. Para añadir un vehículo futuro: una entrada en
  `VehicleConfig.Vehicles`/`Order`, su precio en `EconomyConfig.VehiclePrices`
  y un layout en `VehicleFactory`; el menú, la compra y el despliegue aparecen
  solos, sin tocar servidor, cliente ni interfaz.

### Probar la animación de la calada

1. Con el vape en la mano, pulsa **PUFF** y observa la secuencia completa:
   - el brazo sube y el vaper se inclina hacia la boca,
   - hay una pausa breve (inhalación),
   - **el humo sale de la boca**, no de la punta del vaper,
   - el brazo baja solo y puedes moverte con normalidad.
2. Pulsa **PUFF** muy rápido varias veces: debe quedarse **una sola** animación
   en la boca (encadenando humo), no varias solapadas.
3. Prueba con un rig **R6** (`Home > Avatar > Body Type > R6`): el gesto es más
   rígido porque no hay codo, pero el humo debe salir igual de bien.
4. Prueba el vaper más grande (`galaxy`), que es el que más se acerca a la cara,
   y comprueba que no la atraviesa.
5. Multi-jugador: con dos clientes, el otro jugador debe ver tu humo.

Para depurar, pon `AnimConfig.Debug = true` (en `ReplicatedStorage > Shared >
AnimConfig`): imprime el rig detectado, las longitudes de hueso y el tamaño del
vaper cada vez que lanzas una calada.

---

## 10. Generar un place para probar (`.rbxlx`)

### Sin Rojo (la vía rápida)

Si todavía no tienes Rojo instalado, este script genera un place con **todos**
los scripts ya colocados en su servicio y una baseplate para no caerte del
mapa. No necesita nada más que PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\Build-Place.ps1
```

Produce `HowToVape.rbxlx` en la raíz. Ábrelo con Studio
(`File > Open from File...`) y pulsa **Play**.

El mapeo carpeta → servicio lo lee de `default.project.json`, así que si mueves
algo allí, el script lo respeta. **Es una foto**: si editas `src/` después,
vuelve a ejecutarlo.

### Con Rojo

```powershell
rojo build -o HowToVape.rbxlx
```

### Elige una sola vía

No mezcles las dos sobre el mismo lugar: o sincronizas en vivo con
`rojo serve`, o trabajas sobre el `.rbxlx` generado. Si haces las dos cosas
sobre el mismo fichero acabarás con dos copias del código en paralelo.

---

## 11. Archivos de configuración

| Archivo                | Para qué sirve |
| ---------------------- | -------------- |
| `default.project.json` | Mapa que le dice a Rojo qué carpeta de disco corresponde a cada servicio de Roblox. Es el único archivo imprescindible. |
| `rokit.toml`           | Manifiesto opcional de Rokit para fijar la versión de Rojo. Solo se usa si instalas Rojo con Rokit. |
| `.gitignore`           | Evita versionar los `.rbxl`/`.rbxlx` generados y los archivos basura del sistema. |

### Qué mapea `default.project.json`

| Nodo en Studio                       | Carpeta en disco |
| ------------------------------------ | ---------------- |
| `ReplicatedStorage > Shared`         | `src/shared`     |
| `ServerScriptService`                | `src/server`     |
| `StarterPlayer > StarterPlayerScripts` | `src/client`   |

`Workspace` **no** está mapeado a propósito: la ciudad, las calles, los
distritos, las puertas y los dealers los crea `CityBuilder.luau` en tiempo de
ejecución, así que no hay cientos de objetos que mantener a mano.

Está activado `"$ignoreUnknownInstances": true` en el `DataModel` y en cada
servicio. Eso significa que **Rojo no borrará nada** que no esté declarado en
el proyecto (por ejemplo tu Baseplate o cualquier decoración que añadas a
mano en Studio).

---

## 12. Solución de problemas

**`rojo serve` dice "command not found" / no se reconoce.**
Rojo no está en el PATH. Repite el paso 3-bis y **reinicia la terminal y
Cursor** para que el PATH nuevo surta efecto.

**Studio no se conecta.**
- Comprueba que `rojo serve` sigue corriendo en la terminal.
- Comprueba que el puerto del plugin es `34872` (el mismo que imprimió Rojo).
- Un firewall puede bloquear `localhost`; revisa que no haya avisos pendientes.

**El script del cliente no se ejecuta.**
Comprueba en el Explorer de Studio que `StarterPlayerScripts > ClientController`
es un **LocalScript**. Si aparece como ModuleScript, el nombre del archivo en
disco ha perdido el sufijo `.client.luau`.

**Rojo da error al leer los `.luau`.**
Tu Rojo es más antiguo que 7.3. Actualízalo (paso 3-bis). Como alternativa
temporal, renombra todos los `.luau` a `.lua`.

**Errores tipo `Shared is not a valid member of ReplicatedStorage`.**
Significa que Rojo no está sincronizado o que desconectaste el plugin. Vuelve
a pulsar **Connect** en el panel de Rojo.

**Los datos no se guardan al reiniciar en Studio.**
Es el comportamiento esperado con `StudioUseDataStore = false`. Sigue el paso 8.

**Hay dos copias de un script en Studio.**
Es lo que pasa si antes pegaste los archivos a mano con nombres distintos a los
de `src/`. Borra a mano la copia antigua en Studio (la que no está gestionada
por Rojo) y deja que Rojo se encargue.

---

## 13. Animación de la calada (PuffAnimator + MouthFX)

Sistema **procedural** de animación y humo. No necesita subir nada a Roblox ni
usar `AnimationId`: se calcula en el cliente a partir de las articulaciones
reales del rig.

### Archivos

| Archivo | Tipo | Papel |
| --- | --- | --- |
| `src/shared/AnimConfig.luau` | ModuleScript | Todos los parámetros ajustables (tiempos, postura, humo). |
| `src/client/PuffAnimator.luau` | ModuleScript | IK de brazo + máquina de estados de la secuencia. |
| `src/client/MouthFX.luau` | ModuleScript | Attachment en la cabeza + dos `ParticleEmitter`. |

### Cómo funciona

1. **`EquipmentService`** mide el modelo del vaper (caja envolvente) y publica
   `VapeTipLocal`, `VapeUpLocal`, `VapeLength` como atributos. Así el animador
   sabe dónde está la punta del dispositivo en la mano, y los vapers grandes se
   mantienen automáticamente lejos de la cara.
2. **`PuffAnimator`** descubre los `Motor6D` (R15: `RightShoulder`, `RightElbow`,
   `RightWrist`, `Neck`, `Waist`; R6: `Right Shoulder`, `Neck`) y resuelve un
   **IK de dos huesos** para llevar la punta del vaper exactamente a la boca.
3. El resultado se escribe en `Motor6D.Transform` **mezclado** con el valor
   actual (`actual:Lerp(objetivo, peso)`). Nunca se tocan `C0`/`C1` ni se añaden
   articulaciones, así que la animación por defecto (idle, andar) sigue debajo y
   se recupera sola al bajar el peso.
4. La secuencia es una máquina de estados:
   `raise` (subir) → `pause` (inhalación) → `exhale` (se separa y **emite el
   humo**) → `lower` (regreso). Pulsar PUFF varias veces seguidas **encadena**
   ciclos `pause + exhale` en la misma animación en lugar de solaparlas.
5. El humo nace en un `Attachment` en la boca (nunca dentro de la cabeza) y su
   dirección se fuerza con `Acceleration` (hacia delante + arriba) según la
   orientación real de la cabeza, así que sale bien mire donde mire el jugador.
6. Los demás jugadores ven la animación: el servidor emite `PuffBroadcast` y
   cada cliente reproduce la secuencia en local. **No se replica ni un CFrame.**

### Ajustar la animación

Todo está en `AnimConfig.luau`. Lo que se toca más a menudo:

| Clave | Efecto |
| --- | --- |
| `Mouth.Offset` | Altura/profundidad de la punta del vaper respecto a la cabeza (fracción del tamaño de la cabeza). |
| `Mouth.TiltDeg` | Cuánto se inclina el dispositivo hacia la boca. |
| `Mouth.Clearance` / `Mouth.LengthFactor` | Cuánto se separa de la cara; el segundo escala con el tamaño del vaper. |
| `Mouth.ArcLift` | Arco que describe el brazo al subir (0 = línea recta). |
| `Timeline.*` | Duración de cada fase. |
| `Secondary.*` | Giro de cabeza/cintura durante la calada. |
| `Smoke.*` | Tamaño, opacidad, velocidad, dispersión y deriva del humo. |
| `Debug = true` | Imprime rig, longitudes de hueso y tamaño del vape al lanzar la calada. |

### Textura del humo

`AnimConfig.Smoke.Texture` está **vacía a propósito**: se usa el sprite redondo
por defecto de Roblox (no se inventa ningún `rbxassetid`). Si quieres una textura
de humo real, sube la tuya o coge una del Creator Store y pega su id ahí; se
aplica a los dos emisores.

### Animación publicada (no implementada)

La calada **no** usa `Animator:LoadAnimation`. Existe el campo
`AnimConfig.AnimationId` solo como marcador: ahora mismo no se lee. Si algún día
quieres sustituir la animación procedural por una publicada, hay que implementar
la carga y los marcadores de keyframe.

---

## 14. Siguientes pasos (no implementados todavía)

- **FASE 3**: mapa detallado, NPCs con rig real, señales de tráfico, más
  decoración y ampliación de la ciudad.
- **FASE 4**: pulido de interfaz (animaciones de entrada, iconos, adaptación
  fina a móvil/tablet con `UIScale` y `UISizeConstraint`).
- **FASE 5**: misiones, multiplicadores temporales, recompensas diarias y
  batería de pruebas funcionales automatizadas.
