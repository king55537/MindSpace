# Design

## Contexto

El menú de pausa es una escena `CanvasLayer` autónoma con ESC, Continue,
Settings y Save & exit. El guardado vive en `SaveManager` (clase estática) y
expone un estado pendiente que la escena que carga debe aplicar con
`GameSim.load_state()` y `EventLog.restore()`. La escena jugable es
`base.tscn`; el menú principal es `welcome.tscn`, que entra al juego pasando
por la selección de mundos y la introducción.

## Decisiones

### Instancia directa en `base.tscn`

El menú se añade como hija de la escena jugable. Se descarta un autoload porque
la pausa solo tiene sentido dentro de una partida y el proyecto no debe sumar
un quinto singleton. El `CanvasLayer` ya trae `PROCESS_MODE_ALWAYS`, así que
sigue recibiendo ESC con el árbol pausado.

### Continue directo a la escena guardada

**Continue** no pasa por la selección de mundos ni por la introducción: el
guardado ya contiene la escena, el mundo y el estado, y la introducción no
aporta nada al reanudar. Si el guardado no se puede leer o la escena ya no
existe, el menú muestra el error y no cambia de escena.

### La escena jugable aplica la carga

`base.tscn` comprueba `SaveManager.has_pending_load()` después de colocar el
astronauta en el mapa. Si hay carga pendiente:

1. `GameSim.load_state()` sustituye el estado y deja el reloj pausado.
2. `EventLog.restore()` recupera el ledger.
3. Se aplica la posición guardada del astronauta.
4. Se limpia el estado pendiente y se reanuda el reloj, salvo que la partida
   estuviera terminada.

Si no hay carga, el camino actual (`GameSim.start_run()`) no cambia. Así una
entrada normal sigue empezando en el tick 0 y una reanudación no consume ticks
durante la transición.

### Empezar una partida nueva descarta la carga pendiente

`Start game` llama a `SaveManager.clear_pending()` antes de navegar. Sin esto,
un **Continue** fallido seguido de **Start game** podría hacer que la escena
jugable cargara el guardado viejo en lugar de iniciar una partida limpia. El
archivo guardado no se borra: sigue disponible para el próximo **Continue**.

### Alcance del guardado

No se guarda el estado de la selección de mundos ni de la introducción; sus
escenas no son jugables y no tienen reloj. El guardado se rechaza si no hay una
partida activa (`GameSim.run_active`).

## Archivos

- `game/scenes/base/base.tscn` (instancia del menú).
- `game/scenes/base/base.gd` (rama de carga).
- `game/scenes/welcome/welcome.tscn` (botón Continue).
- `game/scenes/welcome/welcome.gd` (carga y navegación).
- `openspec/changes/integrate-pause-menu/` (artefactos).

## Alternativas descartadas

- **Autoload del menú de pausa.** Añade un singleton global y permite abrir la
  pausa en menús sin partida.
- **Pasar por mundos e intro al continuar.** Repite una introducción que el
  jugador ya vio y puede cambiar el mundo seleccionado.
- **Cargar en `welcome.gd` y pasar el estado por una escena intermedia.** Añade
  una escena de tránsito sin valor; el estado pendiente ya es estático.
- **Reiniciar y luego aplicar solo algunos campos.** Dejaría el ledgers y las
  máquinas en un estado híbrido que no corresponde al guardado.
