# Spec Delta

## MODIFIED Requirements

### Requirement: Contenido de la pantalla de entrada

La pantalla SHALL mostrar el título del juego, un subtítulo y las acciones de
iniciar partida y de abrir los ajustes. Cuando exista una partida guardada,
SHALL mostrar además una acción para continuarla.

#### Scenario: Presentación completa

- **WHEN** el jugador llega al menú sin una partida guardada
- **THEN** ve el título, el subtítulo y las acciones de iniciar partida y de ajustes completas, sin recortes ni solapamientos

#### Scenario: Presentación con partida guardada

- **WHEN** el jugador llega al menú con una partida guardada
- **THEN** ve además la acción de continuar, completa y sin solaparse con las demás

### Requirement: Navegación sin ratón

Al abrirse el menú, el foco SHALL estar en la primera acción disponible, para
poder recorrer todas las acciones solo con teclado.

#### Scenario: Foco inicial

- **WHEN** el jugador llega al menú sin una partida guardada
- **THEN** la acción de iniciar partida aparece enfocada y se puede cambiar de acción con el teclado

#### Scenario: Foco con partida guardada

- **WHEN** el jugador llega al menú con una partida guardada
- **THEN** la acción de continuar aparece enfocada y se puede cambiar de acción con el teclado

## ADDED Requirements

### Requirement: Acción Continuar

Cuando exista una partida guardada, activar la acción de continuar SHALL cargar
el archivo y entrar en la escena guardada. Si la carga falla, SHALL avisar y
permanecer en el menú sin aplicar ningún cambio.

#### Scenario: Continuar con guardado válido

- **WHEN** el jugador activa la acción de continuar y el guardado es válido
- **THEN** el juego carga la partida y entra en la escena guardada

#### Scenario: Continuar con guardado no válido

- **WHEN** el jugador activa la acción de continuar y el guardado no se puede leer
- **THEN** aparece un aviso con el motivo y el menú sigue en pantalla

### Requirement: Partida nueva sin carga pendiente

La acción de iniciar partida SHALL descartar cualquier carga pendiente antes de
navegar, para que una partida nueva no adopte por error el guardado anterior.

#### Scenario: Iniciar tras un continuar fallido

- **WHEN** el jugador intenta continuar, la carga falla y después elige iniciar partida
- **THEN** la partida nueva empieza limpia y no aplica el guardado anterior
