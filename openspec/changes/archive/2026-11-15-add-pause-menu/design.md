# Design

## Contexto

El juego tiene una única escena jugable (`base.tscn`) que compone el mapa, el
astronauta y el reloj de `GameSim`. El menú principal y el selector de mundos
viven en otras escenas. `GameSim` ya expone `set_paused()` y `is_paused()`, y el
astronauta consulta `is_paused()` antes de moverse. `WorldStore` ya guarda los
mundos en JSON con escritura atómica; el guardado de partida debe seguir ese
mismo patrón para que el proyecto tenga una sola forma de persistir.

La escena jugable y el menú principal son compartidos y no se pueden editar en
esta rama. El módulo se entrega sin instanciar; la integración queda como tarea
aparte para el dueño de esas escenas.

## Decisiones

### Módulo autónomo, sin autoload

El menú es una escena `CanvasLayer` que se instancia como hija de la escena
jugable. Se descarta un autoload porque añadiría un quinto singleton al proyecto
(la regla del repositorio exige pedirlo) y porque la pausa solo tiene sentido
dentro de una partida. `SaveManager` es una clase estática, igual que
`WorldStore`, así que tampoco necesita autoload.

### Pausa del árbol y del reloj, con restauración del estado previo

`get_tree().paused = true` congela `_process` y `_physics_process` de la escena
y de la UI; `GameSim.set_paused(true)` congela el reloj de forma explícita e
independiente. Al abrir se memoriza `GameSim.is_paused()` y al cerrar se
restaura ese valor, no se fuerza `false`: si la partida ya estaba congelada
(por ejemplo, tras una muerte o en una escena que aún no ha arrancado el reloj),
reanudar no la despierta por accidente. El acumulador de ticks vive dentro de
`GameSim` y no se toca, así que la reanudación no adelanta ni pierde fracciones
de tick.

### Guardado en JSON de un solo slot

Se usa `user://saves/savegame.json` con escritura atómica (`.tmp` + rename) y
cuarentena `.bak` si el archivo no se puede parsear, replicando `WorldStore`.
`ConfigFile` se descarta porque el proyecto ya usa JSON para persistencia y
porque el archivo se puede inspeccionar con cualquier editor. Varios slots se
descartan: la acción es **Save & exit**, un único destino explícito, y el id del
mundo viaja dentro del archivo. La versión del esquema se guarda y se rechaza
cualquier versión distinta de la actual: no hay migración en esta entrega.

### La serialización vive en `SaveManager`

`SimState`, `MachineState`, `PlayerStats`, `ActiveEvent` y `PendingEvent` siguen
siendo clases puras de simulación: no se les añaden métodos de guardado. El
esquema JSON está en un único archivo, que es el único que hay que tocar cuando
cambie el modelo. Los eventos se guardan por id de fila y se resuelven contra
`GameSim.get_events()` al cargar; una fila desaparecida se omite sin romper la
carga. El ledger se guarda entero porque los contadores de evaluación salen de
él; su contrato de payload plano (`LogEntry.is_plain_payload`) garantiza que es
serializable.

### Carga sin efectos parciales

`request_load()` parsea y valida todo (versión, estado, ledger) antes de
exponer nada. Si algo falla, no hay estado pendiente y `last_error` explica el
motivo. `SaveManager` no toca los autoloads: recibe el estado y el ledger al
guardar, y devuelve el estado y el ledger pendientes al cargar. La escena que
integre la carga llama a `GameSim.load_state()` y `EventLog.restore()`, y decide
cuándo reanudar. La posición del astronauta y el mundo se exponen por separado
para esa misma integración. Así el guardado se puede probar sin árbol de escenas
y la simulación conserva un único dueño.

### ESC y textos

Se usa la acción incorporada `ui_cancel` (ESC por defecto), así que no hay que
editar el input map de `project.godot`. Todos los textos visibles van en inglés,
como el resto de la UI. Settings muestra el mismo aviso temporal que ya usa el
menú principal, sin crear una pantalla nueva.

## Archivos

- `game/scenes/ui/pause_menu/pause_menu.tscn` (nuevo).
- `game/scenes/ui/pause_menu/pause_menu.gd` (nuevo).
- `game/scripts/save/save_manager.gd` (nuevo).
- `game/scripts/dev/save_smoke.gd` (nuevo, comprobación headless).
- `game/scripts/autoloads/game_sim.gd` (añade `run_active`, `load_state()`).
- `game/scripts/autoloads/event_log.gd` (añade `restore()`).
- `openspec/changes/add-pause-menu/` (artefactos de este cambio).

## Alternativas descartadas

- **Autoload para el menú de pausa.** Añade un singleton global y permite
  abrir la pausa en menús donde no hay partida; además choca con la regla de no
  añadir autoloads sin permiso.
- **Solo `get_tree().paused`, sin tocar `GameSim`.** El astronauta ya respeta
  `GameSim.is_paused()`, pero el reloj quedaría a merced del modo de proceso de
  cada nodo y la reanudación no podría restaurar el estado previo.
- **Guardar cada clase desde sí misma.** Reparte el esquema JSON por toda la
  simulación y obliga a tocar cinco archivos cada vez que cambia el modelo.
- **Varios slots o autoguardado.** La UI crecería y el alcance pedido es una
  acción concreta de guardar y salir.
- **Editar `base.tscn` y `welcome.tscn`.** Resuelve la integración completa,
  pero el usuario pidió expresamente no instanciar el menú ni tocar las escenas
  compartidas en esta rama.
