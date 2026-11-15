# Proposal

## Why

El menú de pausa y el guardado ya existen, pero el menú no está instanciado en
la escena jugable y una partida guardada no se puede reanudar: ESC no hace nada
en el juego real y **Save & exit** deja el archivo sin ningún camino de vuelta.
Con las escenas compartidas ya autorizadas, este cambio cierra el ciclo:
instanciar el menú en `base.tscn`, añadir **Continue** al menú principal y
aplicar el estado guardado al entrar en la escena jugable.

## What Changes

- `scenes/base/base.tscn` instancia `scenes/ui/pause_menu/pause_menu.tscn`
  como hija. ESC abre la pausa durante la partida.
- `scenes/welcome/welcome.tscn` añade una acción **Continue**, visible solo
  cuando hay una partida guardada, por delante de **Start game**.
- `welcome.gd` lee el guardado con `SaveManager.request_load()`, selecciona el
  mundo guardado y entra directamente en la escena guardada.
- `base.gd` detecta una carga pendiente y aplica el estado restaurado, el
  ledger, la posición del astronauta, la velocidad y el estado del reloj en vez
  de reiniciar la partida. Si el reloj estaba congelado por muerte, sigue
  congelado.
- Empezar una partida nueva descarta cualquier carga pendiente.

## Capabilities

### New Capabilities

- Ninguna.

### Modified Capabilities

- `pause-menu`: se añade el requisito de que la escena jugable instancie el
  menú.
- `save-game`: se añaden la reanudación desde el menú principal y la aplicación
  del estado cargado en la escena jugable.
- `menu`: el contenido del menú y el foco inicial pasan a incluir **Continue**
  cuando hay partida guardada.
- `game-session`: entrar en la escena jugable con una carga pendiente restaura
  el guardado en lugar de reiniciar, y el reloj se reanuda tras la carga.

## Impact

- **Escenas:** `game/scenes/base/base.tscn`, `game/scenes/welcome/welcome.tscn`.
- **Scripts:** `game/scenes/base/base.gd`, `game/scenes/welcome/welcome.gd`.
- **Guardado:** sin cambios; se consume la API ya existente de
  `game/scripts/save/save_manager.gd`.
- **OpenSpec:** este cambio y las specs `pause-menu`, `save-game`, `menu` y
  `game-session`.
- No toca simulación, datos, `project.godot` ni autoloads.

## Fuera de alcance

- La pantalla de configuración real.
- Varios slots de guardado y autoguardado.
- Guardar desde el menú, la selección de mundos o la introducción.
- Migración de guardados de versiones anteriores.
