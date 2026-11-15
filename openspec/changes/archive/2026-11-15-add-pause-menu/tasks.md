# Tasks

## 0. Artefactos OpenSpec

- [x] Crear `openspec/changes/add-pause-menu/` con proposal, design, specs
      delta y este archivo.
- [x] Ejecutar `openspec validate add-pause-menu --strict`.

## 1. Soporte de guardado en los autoloads

- [x] En `game/scripts/autoloads/game_sim.gd`, añadir `run_active`, marcarlo
      en `start_run()`/`stop_run()` y añadir `load_state(state, speed)` sin
      cambiar el comportamiento actual de una partida nueva.
- [x] En `game/scripts/autoloads/event_log.gd`, añadir `restore(entries)` que
      sustituye el ledger validando tipo y payload, sin emitir señales.
- [x] Comprobar que `sim_smoke.gd` y el arranque headless siguen pasando.

## 2. SaveManager

- [x] Crear `game/scripts/save/save_manager.gd` con:
      serialización de `SimState`, `MachineState`, `PlayerStats`,
      `ActiveEvent`, `PendingEvent` y `LogEntry`; guardado de escena, mundo y
      posición del astronauta; escritura atómica; cuarentena `.bak`; versión.
- [x] Implementar `save_run()`, `has_save()`, `request_load()`, los accesos al
      estado pendiente y `last_error`, sin tocar los autoloads desde la clase.
- [x] Crear `game/scripts/dev/save_smoke.gd`: guarda un estado conocido, lo
      recarga y compara tick, recursos, máquinas, eventos y ledger.

## 3. Menú de pausa

- [x] Crear `game/scenes/ui/pause_menu/pause_menu.tscn` con fondo atenuado,
      panel, título, tres botones, aviso temporal y pista de ESC, usando
      `themes/pixel_theme.tres`.
- [x] Crear `game/scenes/ui/pause_menu/pause_menu.gd`: ESC abre/cierra,
      `PROCESS_MODE_ALWAYS`, pausa del árbol y del reloj, restauración del
      estado previo, foco en **Continue**, aviso de Settings y **Save & exit**
      con vuelta a `scenes/welcome/welcome.tscn`.
- [x] Verificar que el menú funciona en una escena de prueba sin tocar
      `base.tscn` ni `welcome.tscn`.

## 4. Validación y cierre

- [x] `powershell -NoProfile -File ~/.config/opencode/skills/godot/scripts/check-gdscript.ps1 -p game --strict`.
- [x] Arranque headless `godot --headless --path game --quit` sin `ERROR` ni
      `SCRIPT ERROR`.
- [x] Captura real del menú de pausa sobre una escena de prueba en `tests/`
      (ignorada por Git).
- [x] Commit en la rama `pause-menu` y `openspec archive add-pause-menu --yes`.
- [x] Avisar de que la instanciación en `base.tscn` y el **Continue** del menú
      principal quedan pendientes por decisión del usuario.
