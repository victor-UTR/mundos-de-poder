# Nivel 1 — Ciudad Desolada por Robots

## Resumen

Side-scroller 2D pixel-art. El niño avanza de izquierda a derecha por
5 pantallas conectadas hasta llegar al Empire State, donde resuelve un
puzzle final apagando el datacenter.

## Objetivo del jugador

1. Recolectar los 3 poderes derrotando a los 3 tipos de robot.
2. Llegar al Empire State (pantalla 5).
3. Apagar los 3 servidores usando el poder correcto en cada uno.

## Estructura por pantallas

| # | Nombre           | Contenido                                        |
|---|------------------|--------------------------------------------------|
| 1 | Calle 1          | Tutorial de movimiento + 1 Robot-Escáner.        |
| 2 | Calle 2          | Plataformas + 2 Robots-Escáner + 1 Torreta.      |
| 3 | Estación metro   | Puzzle simple con Visión (plataforma oculta).    |
| 4 | Avenida rota     | 2 Sirenas + 1 Torreta, oleadas.                  |
| 5 | Empire State     | Boss-puzzle: 3 servidores + oleada final.        |

## Enemigos

### Robot-Escáner
- HP: 2. Se mueve lento. Detecta al jugador en cono corto y le dispara.
- Suelta al morir: **Visión** (primera vez) o 10 puntos.

### Robot-Torreta
- HP: 3. Estático. Dispara láser horizontal que atraviesa.
- El láser puede bloquearse con **Escudo**.
- Suelta al morir: **Escudo** (primera vez) o 20 puntos.

### Robot-Sirena
- HP: 2. Se mueve rápido, embiste. Emite ondas sonoras que aturden.
- **EMP** lo apaga instantáneamente durante 2 s.
- Suelta al morir: **Pulso EMP** (primera vez) o 15 puntos.

## Puzzle final (Empire State)

Sala con 3 servidores rojos en fila:

- **Servidor A**: tiene un botón invisible → requiere **Visión** para verlo.
- **Servidor B**: dispara láser continuo → requiere **Escudo** para
  acercarse y desconectarlo.
- **Servidor C**: alimentación eléctrica activa → requiere **EMP** para
  desactivarla y poder tirar de la palanca.

Solo con los 3 poderes activados el datacenter se apaga. Si al llegar
falta alguno, el juego indica cuál y permite volver a las pantallas
anteriores.

No basta con llevar el poder en la mochila: hay que **usarlo** (`Q`) y
después interactuar (`E`). El servidor A sólo acepta la pulsación mientras
la Visión está activa, el B exige gastar una carga de Escudo (y quema a
quien se acerca sin ella) y el C sólo cede mientras el EMP lo tiene
aturdido. La luz de cada servidor se pone verde cuando se puede actuar.

## Recompensa

- Se marca `Nivel 1` como completado.
- Se genera el **código de compartir** con la mochila del jugador.
- Pantalla ofrece: copiar código, seguir a Nivel 2 (bloqueado en v0),
  volver al menú.

## Métricas objetivo

- Duración esperada primera partida: 10-15 minutos.
- Muertes tolerables antes de frustración (niño 10 años): 5-8.
- Deben poder terminarlo sin ayuda de un adulto.
