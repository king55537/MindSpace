# Tasks

## 1. Instancia del menú

- [x] Añadir la instancia de `scenes/ui/pause_menu/pause_menu.tscn` como hija
      de `scenes/base/base.tscn`.
- [x] Verificar en una escena de prueba que ESC abre y cierra la pausa en la
      escena jugable real.

## 2. Continue en el menú principal

- [x] Añadir el botón Continue a `scenes/welcome/welcome.tscn`, oculto cuando no
      hay guardado.
- [x] En `scenes/welcome/welcome.gd`, mostrar/ocultar Continue, darle el foco
      cuando exista, cargar con `SaveManager.request_load()`, seleccionar el
      mundo guardado y entrar en la escena guardada.
- [x] Descartar la carga pendiente al iniciar una partida nueva.

## 3. Aplicar la carga en la escena jugable

- [x] En `scenes/base/base.gd`, detectar `SaveManager.has_pending_load()` y
      aplicar estado, ledger, posición, velocidad y estado del reloj en lugar de
      llamar a `GameSim.start_run()`.
- [x] Mantener el reloj pausado si la partida guardada estaba terminada.

## 4. Validación y cierre

- [x] PRUEBA DE CARGA: guardar un estado con tick y posición conocidos, cargarlo
      e instanciar `base.tscn`; comprobar que el estado y la posición coinciden.
- [x] Comprobación headless `check-gdscript.ps1 -p game --strict` y arranque
      `godot --headless --path game --quit`.
- [x] Abrir el menú principal con un guardado real y comprobar que Continue
      aparece enfocado y entra a la partida.
- [x] Commit y `openspec archive integrate-pause-menu --yes`.
