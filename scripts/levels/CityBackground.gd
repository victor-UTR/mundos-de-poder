extends Node2D
## Fondo de ciudad nocturna con parallax de tres capas.
##
## Antes el juego se dibujaba sobre el `default_clear_color`: un vacío liso.
## Los rectángulos flotaban en la nada, y eso es lo que más hacía que
## pareciera un prototipo. Esto le da un sitio donde estar.
##
## Se construye entero por código y sin un solo PNG, con siluetas generadas
## a partir de una semilla fija (misma pantalla = mismo skyline siempre).
## Cuando lleguen los sprites de la Fase 3, se sustituye el `_draw()` por
## texturas y el resto de la estructura se queda igual.
##
## Estructura:
##   CanvasLayer(-100) -> cielo en degradado, no se mueve nunca
##   Parallax2D x3     -> skyline lejano / medio / cercano
##
## Perspectiva atmosférica invertida para legibilidad: lo lejano es lo más
## oscuro (se funde con el cielo) y lo cercano lo más claro, pero SIEMPRE
## más oscuro que el suelo y las plataformas, para que el niño distinga de
## un vistazo lo que es decorado de lo que se puede pisar.

## Altura de la línea de suelo. La pasa LevelScreen.
@export var ground_top: float = 324.0

## Ancho del patrón que se repite. Los edificios se dibujan dentro de este
## ancho sin cruzar los bordes, así el tileado no tiene costuras.
const TILE_W := 720.0
const REPEAT_TIMES := 8

## scroll_scale por capa. 0 = infinitamente lejos (no se mueve), 1 = pegado
## al mundo (sin parallax). En Y va 1.0 siempre, para que las bases de los
## edificios se apoyen exactamente en la línea de suelo.
const LAYERS := [
	{"scroll": 0.15, "seed": 1001, "count": 26, "min_h": 70.0, "max_h": 145.0,
		"min_w": 22.0, "max_w": 46.0, "color": "CITY_FAR", "windows": true},
	{"scroll": 0.32, "seed": 2002, "count": 17, "min_h": 110.0, "max_h": 215.0,
		"min_w": 38.0, "max_w": 74.0, "color": "CITY_MID", "windows": true},
	{"scroll": 0.55, "seed": 3003, "count": 10, "min_h": 150.0, "max_h": 275.0,
		"min_w": 64.0, "max_w": 120.0, "color": "CITY_NEAR", "windows": false},
]


func _ready() -> void:
	# Muy al fondo: por debajo de suelo, plataformas, enemigos y jugador.
	z_index = -100
	_build_sky()
	for cfg in LAYERS:
		_build_layer(cfg)


# --- Cielo -----------------------------------------------------------------
func _build_sky() -> void:
	# En un CanvasLayer aparte para que no lo afecte la cámara: el cielo se
	# queda quieto por muy lejos que camine el jugador.
	var layer := CanvasLayer.new()
	layer.name = "Sky"
	layer.layer = -100
	add_child(layer)

	var grad := Gradient.new()
	grad.set_color(0, Palette.SKY_TOP)
	grad.set_color(1, Palette.SKY_BOTTOM)

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 4
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)

	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)


# --- Capas de edificios ----------------------------------------------------
func _build_layer(cfg: Dictionary) -> void:
	var par := Parallax2D.new()
	par.name = "City_%d" % cfg["seed"]
	# En Y va 1.0 a propósito: no queremos parallax vertical, queremos que
	# los edificios se apoyen en el suelo.
	par.scroll_scale = Vector2(cfg["scroll"], 1.0)
	par.repeat_size = Vector2(TILE_W, 0)
	par.repeat_times = REPEAT_TIMES
	add_child(par)

	var canvas := Node2D.new()
	canvas.name = "Draw"
	var shapes := _generate(cfg)
	canvas.draw.connect(_paint.bind(canvas, shapes, cfg))
	par.add_child(canvas)


## Genera el skyline de una capa. Semilla fija => mismo resultado siempre,
## así el fondo no baila entre partidas ni entre frames.
func _generate(cfg: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = cfg["seed"]

	var out := []
	var count: int = cfg["count"]
	# Reparto uniforme con jitter, para que no queden alineados como peine.
	var slot := TILE_W / float(count)

	for i in count:
		var w := rng.randf_range(cfg["min_w"], cfg["max_w"])
		var x := i * slot + rng.randf_range(-slot * 0.22, slot * 0.22)
		x = clampf(x, 0.0, TILE_W - w)
		var h := rng.randf_range(cfg["min_h"], cfg["max_h"])

		# 1 de cada 4 sale "roto": el remate no es plano, tiene un mordisco.
		# Es lo que separa una ciudad de una ciudad DESTRUIDA.
		var broken := rng.randf() < 0.25
		out.append({
			"rect": Rect2(x, ground_top - h, w, h),
			"broken": broken,
			"bite_w": w * rng.randf_range(0.25, 0.55),
			"bite_h": h * rng.randf_range(0.08, 0.22),
			"bite_left": rng.randf() < 0.5,
			"win_seed": cfg["seed"] + i,
		})
	return out


func _paint(canvas: Node2D, shapes: Array, cfg: Dictionary) -> void:
	var base: Color = Palette.get(cfg["color"])

	for s in shapes:
		var r: Rect2 = s["rect"]
		canvas.draw_rect(r, base)

		# El "mordisco" del edificio roto: se repinta un trozo del remate
		# con el color del cielo para simular que le falta la esquina.
		if s["broken"]:
			var bx: float = r.position.x if s["bite_left"] else r.end.x - s["bite_w"]
			canvas.draw_rect(
				Rect2(bx, r.position.y, s["bite_w"], s["bite_h"]),
				Palette.SKY_BOTTOM)

		if cfg["windows"]:
			_paint_windows(canvas, r, s)


## Cuatro ventanas mal contadas, apagadas y desalineadas. La ciudad está
## desolada: si se iluminan todas parece un centro financiero a las 8pm.
func _paint_windows(canvas: Node2D, r: Rect2, s: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s["win_seed"]

	var cols := int(r.size.x / 11.0)
	var rows := int(r.size.y / 15.0)
	if cols <= 0 or rows <= 0:
		return

	for cx in cols:
		for cy in rows:
			if rng.randf() > 0.09:
				continue
			var wx := r.position.x + 4.0 + cx * 11.0
			var wy := r.position.y + 7.0 + cy * 15.0
			if wx + 4.0 > r.end.x - 2.0 or wy + 6.0 > r.end.y:
				continue
			canvas.draw_rect(Rect2(wx, wy, 4.0, 6.0), Palette.CITY_WINDOW)
