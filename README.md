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
- `E`: interactuar

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
scenes/       Escenas .tscn (Main, Player, niveles, UI)
scripts/      GDScript
  globals/    Autoloads (GameState, ShareCode)
  player/     Lógica del jugador
docs/         Diseño de niveles y mecánicas
.github/      CI: build web + deploy a Pages
```

## Compartir poderes con amigos (async, sin servidor)

Al terminar un nivel el juego genera un código tipo `MDP1-XXXX-XXXX-XXXX`.
El niño lo envía por WhatsApp; el amigo lo pega en el menú "Amigos" y
recibe 1 poder aleatorio de esa mochila marcado como regalo. En el Nivel 3
(futuro) solo los poderes compartidos/recibidos se podrán usar.

## Deploy

Cada push a `main` dispara el workflow de GitHub Actions que exporta a
web y publica en la rama `gh-pages`.
