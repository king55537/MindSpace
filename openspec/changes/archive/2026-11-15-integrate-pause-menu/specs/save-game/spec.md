# Spec Delta

## ADDED Requirements

### Requirement: Reanudación desde el menú principal

Cuando exista una partida guardada, el menú principal SHALL ofrecer una acción
de continuar que cargue el archivo y entre directamente en la escena guardada,
sin pasar por la selección de mundos ni por la introducción.

#### Scenario: Continuar una partida guardada

- **WHEN** el jugador activa la acción de continuar con un guardado válido
- **THEN** el juego entra en la escena guardada con el estado del archivo y sin repetir la introducción

#### Scenario: Guardado ilegible

- **WHEN** el jugador activa la acción de continuar y el archivo no se puede leer o la escena guardada ya no existe
- **THEN** el menú muestra el motivo y no cambia de escena

### Requirement: Aplicación de la partida cargada

La escena jugable SHALL aplicar el estado pendiente en lugar de reiniciar la
partida: estado de simulación, ledger, posición del astronauta y velocidad.
Después de aplicar la carga, el reloj SHALL quedar activo salvo que la partida
guardada ya estuviera terminada.

#### Scenario: Carga completa en la escena jugable

- **WHEN** la escena jugable arranca con una carga pendiente
- **THEN** el tick, los recursos, las máquinas, el ledger y la posición del astronauta coinciden con el guardado y el reloj avanza de nuevo

#### Scenario: Partida guardada terminada

- **WHEN** la partida guardada tenía la salud a 0
- **THEN** la escena jugable aplica el estado y mantiene el reloj pausado

#### Scenario: Partida nueva tras una carga

- **WHEN** el jugador elige empezar una partida nueva después de una carga pendiente
- **THEN** la partida empieza en el tick 0 y no aplica el guardado anterior
