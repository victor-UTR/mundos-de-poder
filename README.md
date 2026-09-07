# Mundos de Poder

Videojuego didáctico para niños de 10 años. Godot 4.7 · 2D · export web.

Ver [`GameScope.md`](GameScope.md) para el diseño original y
[`docs/`](docs/) para el diseño en detalle del Nivel 1.

## Cómo jugar (versión web)

Publicado en GitHub Pages: `https://victor-utr.github.io/mundos-de-poder/`

**Controles** (teclado):
- `A` / `D` o flechas ← →: mover
- `Espacio` o `↑`: saltar
- `J`: atacar
- `Q`: usar poder activo
- `TAB`: cambiar de poder activo
- `1` / `2` / `3`: seleccionar poder por ranura
- `I`: abrir la mochila (pausa el juego)
- `E`: interactuar

**Móvil / tablet**: los controles en pantalla aparecen solos si el
dispositivo es táctil. Movimiento abajo a la izquierda; Salto, Golpe,
Poder y Usar abajo a la derecha; Mochila arriba a la derecha. Admiten
varios dedos a la vez, así que se puede correr y saltar a la vez, y se
puede deslizar de `<` a `>` sin levantar el dedo.

Atajos de depuración: `F10` reinicia la partida, `F11` borra el guardado,
`F12` vuelca el estado por consola, `F9` enseña u oculta los controles
táctiles (para ajustarlos desde el escritorio).

## Desarrollo local

Requisitos: [Godot 4.7](https://godotengine.org/) (versión estándar, sin .NET).

```powershell
# Abrir el editor
godot --editor project.godot

# Ejecutar el juego directamente
godot project.godot
```

## Estructura

```
scenes/
  Boot.tscn   Escena inicial: manda al LevelManager a la pantalla guardada
  levels/     Screen1..Screen5 + piezas reutilizables (Platform, Door)
  player/     Player
  enemies/    Los 3 robots
  ui/         HUD
scripts/      GDScript
  globals/    Autoloads (GameState, ShareCode, Audio, LevelManager)
  levels/     LevelScreen, Door, Platform, Goal
  player/     Lógica del jugador
tests/        SmokeTest.tscn (se ejecuta en CI)
docs/         Diseño de niveles y mecánicas
.github/      CI: smoke test + build web + deploy a Pages
```

El Nivel 1 son 5 pantallas encadenadas. `LevelScreen.gd` genera el suelo,
los muros y los pozos a partir de `world_width` y `gaps`, así que los `.tscn`
sólo contienen lo propio de cada pantalla. Las puertas son bidireccionales:
si llegas al Empire State sin los 3 poderes, puedes volver a buscarlos.

### Pruebas

```powershell
godot --headless res://tests/SmokeTest.tscn
```

Comprueba que las 5 pantallas montan, que el suelo y los pozos se generan y
que cada puerta apunta a un punto de aparición que existe en su destino.

## Compartir poderes con amigos (async, sin servidor)

Al terminar un nivel el juego genera un código tipo `MDP1-XXXX-XXXX-XXXX`.
El niño lo envía por WhatsApp; el amigo lo pega en el menú "Amigos" y
recibe 1 poder aleatorio de esa mochila marcado como regalo. En el Nivel 3
(futuro) solo los poderes compartidos/recibidos se podrán usar.

## Deploy

Cada push a `main` dispara el workflow de GitHub Actions que exporta a
web y publica en la rama `gh-pages`.
