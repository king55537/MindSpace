# pause-menu Specification

## Purpose
Menú de pausa de la escena jugable: congela y reanuda la partida en el mismo
punto, ofrece las acciones de reanudar, ajustes y guardar y salir, y se puede
manejar sin ratón.

## Requirements

### Requirement: Apertura con ESC

Mientras haya una partida en curso, pulsar ESC SHALL abrir el menú de pausa,
congelar el árbol de escenas y congelar el reloj de simulación. El menú SHALL
quedar por encima del juego y bloquear la interacción con el mundo.

#### Scenario: Apertura durante la partida

- **WHEN** el jugador pulsa ESC con la partida en marcha
- **THEN** el menú de pausa aparece, el reloj deja de producir ticks y el astronauta deja de responder al movimiento

#### Scenario: El mundo no recibe clics

- **WHEN** el menú de pausa está abierto y el jugador hace clic fuera del panel
- **THEN** el clic no llega al mundo ni a sus paneles

### Requirement: Reanudación exacta

Cerrar el menú con la acción de reanudar o con ESC SHALL ocultarlo y devolver el
árbol y el reloj al estado que tenían justo antes de abrir la pausa. El tick, el
acumulador de tiempo, los recursos, las máquinas, el ledger y la posición del
astronauta SHALL permanecer sin cambios.

#### Scenario: Reanudar tras una pausa corta

- **WHEN** el jugador abre la pausa y la cierra sin tocar nada más
- **THEN** el tick, los recursos y la posición del astronauta son los mismos que antes de abrir, y el reloj vuelve a avanzar desde ese punto

#### Scenario: La partida ya estaba congelada

- **WHEN** el jugador abre y cierra la pausa en una partida cuyo reloj ya estaba pausado
- **THEN** el reloj sigue pausado al cerrar, no se reanuda por accidente

### Requirement: Acciones del menú

El menú SHALL mostrar tres acciones: reanudar, ajustes y guardar y salir. Las
acciones SHALL estar completas, sin recortes ni solapamientos, y el texto
visible SHALL estar en inglés como el resto de la interfaz.

#### Scenario: Presentación de las tres acciones

- **WHEN** el menú de pausa se abre
- **THEN** las tres acciones se ven completas dentro del panel y la primera recibe el foco

### Requirement: Ajustes no disponible

Mientras no exista la pantalla de ajustes, activar la acción de ajustes SHALL
mostrar un aviso temporal que lo explique y SHALL dejar el menú de pausa
abierto y la partida congelada.

#### Scenario: Ajustes sin pantalla

- **WHEN** el jugador activa la acción de ajustes
- **THEN** aparece un aviso que se desvanece solo y el menú de pausa sigue abierto

#### Scenario: La pantalla de ajustes existe

- **WHEN** el jugador activa la acción de ajustes y la escena de ajustes está disponible
- **THEN** el juego cambia a esa escena

### Requirement: Guardar y salir

Activar la acción de guardar y salir SHALL guardar la partida en curso y, solo
si el guardado termina bien, SHALL volver al menú principal. Si el guardado
falla, SHALL permanecer en la pausa y mostrar el motivo.

#### Scenario: Guardado correcto

- **WHEN** el jugador activa guardar y salir con una partida en curso y el archivo se escribe
- **THEN** el juego vuelve al menú principal y la partida queda disponible en el archivo de guardado

#### Scenario: Guardado fallido

- **WHEN** el jugador activa guardar y salir y el archivo no se puede escribir
- **THEN** el menú de pausa sigue abierto, la partida sigue congelada y aparece un aviso con el motivo

### Requirement: Navegación por teclado

Con el menú abierto, las acciones SHALL poder recorrerse y activarse solo con
el teclado, y el foco SHALL ser visible.

#### Scenario: Recorrido con teclado

- **WHEN** el jugador usa las flechas y la tecla de confirmación con el menú abierto
- **THEN** el foco cambia entre las tres acciones y la acción enfocada se puede activar

### Requirement: Presentación visual

El menú SHALL usar el tema de píxel del proyecto, mostrarse sin interpolación y
diseñarse para el lienzo de 850×480, con el fondo del juego atenuado detrás.

#### Scenario: Apertura sobre el juego

- **WHEN** el menú de pausa se abre sobre la escena jugable
- **THEN** el fondo del juego se sigue viendo atenuado y el panel y los textos se leen nítidos a tamaño real

### Requirement: Escena autónoma

El menú SHALL funcionar como una escena independiente que se pueda instanciar en
cualquier escena jugable, sin depender de nodos concretos de `base.tscn` ni de
una posición fija en el árbol.

#### Scenario: Instanciado en otra escena jugable

- **WHEN** el menú se instancia como hija de otra escena con el reloj de `GameSim` activo
- **THEN** ESC abre y cierra la pausa igual que en la escena original

### Requirement: Instancia en la escena jugable

La escena jugable SHALL instanciar el menú de pausa como hija, de modo que ESC
esté disponible durante toda la partida sin añadir autoloads nuevos.

#### Scenario: ESC durante la partida real

- **WHEN** el jugador entra en la escena jugable y pulsa ESC
- **THEN** se abre el menú de pausa con las tres acciones y el reloj queda congelado

#### Scenario: Reanudar desde la escena jugable

- **WHEN** el jugador cierra el menú con Continue o ESC
- **THEN** vuelve al juego en el mismo punto y el reloj sigue desde donde estaba
