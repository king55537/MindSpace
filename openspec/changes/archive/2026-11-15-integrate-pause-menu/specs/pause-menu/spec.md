# Spec Delta

## ADDED Requirements

### Requirement: Instancia en la escena jugable

La escena jugable SHALL instanciar el menú de pausa como hija, de modo que ESC
esté disponible durante toda la partida sin añadir autoloads nuevos.

#### Scenario: ESC durante la partida real

- **WHEN** el jugador entra en la escena jugable y pulsa ESC
- **THEN** se abre el menú de pausa con las tres acciones y el reloj queda congelado

#### Scenario: Reanudar desde la escena jugable

- **WHEN** el jugador cierra el menú con Continue o ESC
- **THEN** vuelve al juego en el mismo punto y el reloj sigue desde donde estaba
