# Proposal

## Why

La partida no se puede pausar: la tecla ESC no hace nada y el reloj de
simulación no se puede congelar sin matar el proceso. Tampoco existe forma de
guardar una partida y volver al menú. Para una demo que se juega en minutos y
delante de un juez, poder parar, reanudar exactamente donde estaba y salir sin
perder el progreso es tan importante como el propio loop.

La escena jugable y el menú principal son escenas compartidas y sus dueños no
han autorizado cambios en esta rama. Por eso este cambio entrega el módulo de
pausa y el sistema de guardado completos y probados, listos para instanciarse,
sin tocar `base.tscn` ni `welcome.tscn`.

## What Changes

- Nueva escena de pausa `scenes/ui/pause_menu/pause_menu.tscn` con su script.
  Es un `CanvasLayer` autónomo que congela el árbol y el reloj, y los restaura
  al cerrarse.
- ESC abre y cierra la pausa. Al abrir, el foco va a **Continue**; también se
  puede navegar con teclado.
- Botones **Continue**, **Settings** y **Save & exit**. Settings queda como
  aviso temporal ("coming soon") hasta que exista su pantalla. **Save & exit**
  guarda la partida y vuelve al menú principal; si el guardado falla, se queda
  en la pausa y muestra el error.
- Nuevo `scripts/save/save_manager.gd` (clase estática, sin autoload nuevo):
  guardado de un solo slot en `user://saves/savegame.json`, escritura atómica,
  cuarentena del archivo corrupto y rechazo de versiones no soportadas.
- El guardado incluye la escena actual, el mundo seleccionado, la posición del
  astronauta, el `SimState` completo (tick, recursos, salud, dosis, máquinas,
  eventos) y el ledger del `EventLog`.
- APIs mínimas y aditivas en los autoloads: `GameSim.load_state()` y
  `EventLog.restore()`, más la marca `run_active` para distinguir una partida
  viva de un menú.
- Comprobación headless `scripts/dev/save_smoke.gd` que hace ida y vuelta de un
  guardado y comprueba que el estado restaurado coincide.

## Capabilities

### New Capabilities

- `pause-menu`: menú de pausa, congelación y reanudación exacta, botones y
  navegación por teclado.
- `save-game`: persistencia de una partida en un slot, restauración del estado
  de simulación y del ledger, y manejo de errores del archivo.

### Modified Capabilities

- Ninguna. No se tocan las escenas compartidas ni el flujo actual del menú.

## Impact

- **Escenas nuevas:** `game/scenes/ui/pause_menu/pause_menu.tscn` y
  `pause_menu.gd`.
- **Guardado:** `game/scripts/save/save_manager.gd`.
- **Autoloads:** `game/scripts/autoloads/game_sim.gd` y
  `game/scripts/autoloads/event_log.gd` (solo métodos aditivos).
- **Desarrollo:** `game/scripts/dev/save_smoke.gd`.
- **OpenSpec:** este cambio.
- No toca simulación, datos, `project.godot`, `base.tscn` ni `welcome.tscn`.

## Fuera de alcance

- Instanciar el menú en `base.tscn` y añadir **Continue** en `welcome.tscn`
  (decisión del usuario: no tocar escenas compartidas por ahora).
- La pantalla de configuración real.
- Varios slots de guardado, autoguardado por tick y migración de versiones
  antiguas.
- Guardar desde menús, selección de mundos o introducción.
