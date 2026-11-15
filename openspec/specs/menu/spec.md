# menu Specification

## Purpose
Pantalla de entrada del juego: presenta el título y las acciones principales, y
es el punto desde el que se navega a cualquier otra fase.

## Requirements

### Requirement: Arranque en el menú

El juego SHALL arrancar en la pantalla de entrada sin intervención del jugador.

#### Scenario: Arranque limpio

- **WHEN** el ejecutable del juego arranca
- **THEN** se muestra la pantalla de entrada con su fondo y su título, sin pasar por ninguna otra escena

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

### Requirement: Acción Iniciar juego

Al activar la acción de iniciar partida, el juego SHALL entrar en la siguiente
fase si esa escena existe. Si no existe, SHALL avisar y permanecer en el menú.

#### Scenario: El destino existe

- **WHEN** el jugador activa la acción de iniciar partida y la escena de destino está disponible
- **THEN** el juego cambia a esa escena

#### Scenario: El destino todavía no existe

- **WHEN** el jugador activa la acción de iniciar partida y la escena de destino no está disponible
- **THEN** aparece un aviso que lo explica y el menú sigue en pantalla

### Requirement: Acción Configuración

Al activar la acción de ajustes, el juego SHALL entrar en la pantalla de ajustes
si existe. Si no existe, SHALL avisar y permanecer en el menú.

#### Scenario: El destino existe

- **WHEN** el jugador activa la acción de ajustes y la pantalla de ajustes está disponible
- **THEN** el juego cambia a esa pantalla

#### Scenario: El destino todavía no existe

- **WHEN** el jugador activa la acción de ajustes y la pantalla de ajustes no está disponible
- **THEN** aparece un aviso que lo explica y el menú sigue en pantalla

### Requirement: Aviso temporal

El aviso de acción no disponible SHALL desaparecer solo, sin pedir interacción.

#### Scenario: El aviso se apaga

- **WHEN** aparece un aviso y el jugador no hace nada
- **THEN** el aviso se desvanece pasados unos segundos y la pantalla queda como estaba

### Requirement: Navegación sin ratón

Al abrirse el menú, el foco SHALL estar en la primera acción disponible, para
poder recorrer todas las acciones solo con teclado.

#### Scenario: Foco inicial

- **WHEN** el jugador llega al menú sin una partida guardada
- **THEN** la acción de iniciar partida aparece enfocada y se puede cambiar de acción con el teclado

#### Scenario: Foco con partida guardada

- **WHEN** el jugador llega al menú con una partida guardada
- **THEN** la acción de continuar aparece enfocada y se puede cambiar de acción con el teclado

### Requirement: Nitidez del arte

El arte de la pantalla SHALL mostrarse sin interpolación y a escala entera, de
modo que cada píxel artístico ocupe un bloque cuadrado de píxeles de pantalla.

#### Scenario: Ventana en un múltiplo exacto

- **WHEN** la ventana mide un múltiplo entero del lienzo (por ejemplo, el doble)
- **THEN** el fondo ocupa la ventana completa y cada píxel artístico mide exactamente 2×2 píxeles de pantalla

#### Scenario: Ventana en un tamaño no múltiplo

- **WHEN** la ventana no es un múltiplo entero del lienzo
- **THEN** el arte se sigue viendo a escala entera y el espacio sobrante queda en bandas, nunca estirado a una fracción

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
