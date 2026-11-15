# save-game Specification

## Purpose
Persistencia de una partida en un único archivo local: qué se guarda, cómo se
escribe sin corromper el guardado anterior, cómo se restaura sin dejar el estado
a medias y cómo se informan los errores.

## Requirements

### Requirement: Guardado de una partida en curso

Pedir un guardado con una partida en curso SHALL escribir un archivo local con
la escena actual, el mundo seleccionado, la posición del astronauta, el estado
completo de la simulación y el ledger de hechos.

#### Scenario: Guardado completo

- **WHEN** se pide guardar con una partida en curso
- **THEN** el archivo contiene la escena, el mundo, la posición del astronauta, el tick, los recursos, la salud, la dosis, el hambre, la sed, las máquinas, los eventos activos y pendientes y los hechos del ledger

### Requirement: Contenido restaurable

Al cargar un guardado válido, el juego SHALL recuperar el tick, los recursos,
la salud, la dosis y su pico, el hambre, la sed, la reserva del traje, el estado
de cada máquina, las estadísticas del jugador, los eventos activos y pendientes
y el ledger, de modo que los contadores de evaluación sean los mismos que en el
momento de guardar.

#### Scenario: Ida y vuelta

- **WHEN** se guarda una partida con máquinas dañadas, un evento en curso y hechos en el ledger, y después se carga
- **THEN** el estado restaurado coincide con el guardado en todos esos valores

#### Scenario: Fila de evento desaparecida

- **WHEN** el guardado referencia un evento que ya no existe en el registro
- **THEN** ese evento se omite y el resto del estado se carga correctamente

### Requirement: Reloj pausado al cargar

Tras aplicar un guardado, el reloj de simulación SHALL quedar pausado hasta que
la escena jugable lo reactive, para que la carga no consuma ticks ni recursos.

#### Scenario: Carga en el menú

- **WHEN** se aplica un guardado antes de entrar a la escena jugable
- **THEN** el tick no avanza y no se registran hechos nuevos hasta que la escena jugable arranca

### Requirement: Un solo slot

El guardado SHALL ocupar un único slot local y cada guardado nuevo SHALL
sustituir al anterior, conservando el mundo y la escena dentro del archivo.

#### Scenario: Segundo guardado

- **WHEN** el jugador guarda una segunda partida sobre una primera
- **THEN** solo queda la segunda y al cargar se recupera esa, no la primera

### Requirement: Escritura atómica

La escritura SHALL completarse sobre un archivo completo antes de sustituir al
guardado anterior, de modo que una interrupción no deje un archivo truncado.

#### Scenario: Fallo durante la escritura

- **WHEN** la escritura no puede completarse
- **THEN** no se sustituye el guardado anterior y la operación informa del error

### Requirement: Archivo ilegible

Si el archivo existe pero no se puede interpretar, el juego SHALL conservarlo
como copia de seguridad, SHALL informar del problema y no SHALL tratarlo como un
guardado vacío.

#### Scenario: JSON corrupto

- **WHEN** el archivo de guardado contiene datos que no son un objeto válido
- **THEN** se mueve a una copia de seguridad, se informa del error y no se carga ningún estado

### Requirement: Versión del guardado

El archivo SHALL incluir la versión de su esquema. Una versión distinta de la
soportada SHALL rechazarse sin aplicar ningún cambio.

#### Scenario: Versión desconocida

- **WHEN** el archivo declara una versión que el juego no soporta
- **THEN** la carga falla, se informa del motivo y el estado actual no se modifica

### Requirement: Carga sin efectos parciales

La carga SHALL validar el archivo completo antes de mutar la simulación o el
ledger. Si cualquier parte no es válida, no SHALL aplicarse ningún cambio.

#### Scenario: Guardado incompleto

- **WHEN** el archivo es un objeto válido pero le falta el estado de simulación o está mal tipado
- **THEN** la carga falla, se informa del motivo y el tick, los recursos y el ledger quedan como estaban

### Requirement: Sin partida en curso

Pedir un guardado cuando no hay una partida activa SHALL fallar con un aviso y
no SHALL escribir ni modificar el archivo existente.

#### Scenario: Guardar desde un menú

- **WHEN** se pide guardar desde una escena que no ha arrancado una partida
- **THEN** la operación falla, el archivo anterior no cambia y se informa de que no hay partida

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
