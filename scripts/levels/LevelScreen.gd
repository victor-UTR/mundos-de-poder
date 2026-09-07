extends Node2D
## Raíz de cada pantalla del Nivel 1.
##
## Se encarga de lo repetitivo para que los .tscn sólo contengan lo propio de
## la pantalla (plataformas, enemigos, puertas):
##   - genera el suelo y los muros laterales a partir de `world_width`
##   - ajusta los límites de la cámara
##   - coloca al Player en el punto de entrada que pidió el LevelManager

## Índice 1-based de esta pantalla (ver docs/NIVEL1.md).
@export var screen_index: int = 1
## Ancho jugable en píxeles. El suelo y los muros se generan a esta medida.
@export var world_width: float = 1600.0
## Altura de la línea de suelo (borde superior del suelo).
@export var ground_top: float = 320.0
## Texto que aparece al entrar (nombre de la pantalla).
@export var screen_title: String = ""
## Huecos en el suelo, como pares (x_inicio, x_fin). El suelo se construye a
## trozos saltándose estos tramos. Caer en uno cuesta un golpe.
@export var gaps: Array[Vector2] = []

## Altura a la que se considera que el jugador se ha caído al vacío.
const FALL_LIMIT := 460.0

const GROUND_THICKNESS := 32.0
const WALL_HEIGHT := 400.0
## Grosor del borde superior del suelo. Una franja más clara que separa el
## suelo del fondo: sin ella, con el parallax detrás, cuesta ver dónde acaba
## el decorado y empieza lo que se pisa.
const GROUND_EDGE_H := 3.0

@onready var spawns: Node2D = $Spawns

## Punto al que se devuelve al jugador si se cae por un hueco.
var _respawn_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_background()
	_build_ground()
	_build_walls()
	_place_player()
	_setup_camera()
	_announce()


## Ciudad nocturna con parallax detrás de todo. Se monta aquí y no en cada
## .tscn para que las cinco pantallas la tengan sin duplicar nada.
func _build_background() -> void:
	var bg := Node2D.new()
	bg.name = "CityBackground"
	bg.set_script(load("res://scripts/levels/CityBackground.gd"))
	bg.ground_top = ground_top
	add_child(bg)
	move_child(bg, 0)


# --- Geometría generada ----------------------------------------------------
func _build_ground() -> void:
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.position = Vector2.ZERO
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("world")

	# El suelo se parte en segmentos para dejar los huecos de `gaps`.
	for seg in _ground_segments():
		var seg_width: float = seg.y - seg.x
		if seg_width <= 0.0:
			continue
		var center := Vector2(seg.x + seg_width * 0.5, ground_top + GROUND_THICKNESS * 0.5)

		var shape := RectangleShape2D.new()
		shape.size = Vector2(seg_width, GROUND_THICKNESS)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = center
		body.add_child(cs)

		var rect := ColorRect.new()
		rect.color = Palette.GROUND
		rect.position = Vector2(seg.x, ground_top)
		rect.size = Vector2(seg_width, GROUND_THICKNESS)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(rect)

		var edge := ColorRect.new()
		edge.color = Palette.GROUND_EDGE
		edge.position = Vector2(seg.x, ground_top)
		edge.size = Vector2(seg_width, GROUND_EDGE_H)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(edge)

	add_child(body)
	move_child(body, 0)


## Devuelve los tramos sólidos de suelo como pares (x_inicio, x_fin),
## resultado de restar `gaps` al ancho total.
func _ground_segments() -> Array:
	var sorted_gaps := gaps.duplicate()
	sorted_gaps.sort_custom(func(a, b): return a.x < b.x)
	var segments := []
	var cursor := 0.0
	for g in sorted_gaps:
		var start: float = max(g.x, cursor)
		if start > cursor:
			segments.append(Vector2(cursor, start))
		cursor = max(cursor, g.y)
	if cursor < world_width:
		segments.append(Vector2(cursor, world_width))
	return segments


func _build_walls() -> void:
	# Muros invisibles a ambos lados: evitan que el jugador se salga del
	# mundo. Las puertas van por dentro, así que siguen siendo alcanzables.
	_make_wall("LeftWall", -8.0)
	_make_wall("RightWall", world_width + 8.0)


func _make_wall(wall_name: String, x: float) -> void:
	var body := StaticBody2D.new()
	body.name = wall_name
	body.position = Vector2(x, ground_top - WALL_HEIGHT * 0.5 + GROUND_THICKNESS)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, WALL_HEIGHT)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


# --- Jugador y cámara ------------------------------------------------------
func _place_player() -> void:
	var player := get_node_or_null("Player")
	if player == null:
		return
	var marker := _find_spawn(LevelManager.pending_spawn)
	if marker:
		player.global_position = marker.global_position
		_respawn_point = marker.global_position
		# Mirar hacia dentro de la pantalla según por dónde se entra.
		if "facing" in player:
			player.facing = -1 if LevelManager.pending_spawn == "from_right" else 1


func _process(_delta: float) -> void:
	# Caída al vacío: cuesta un golpe y devuelve al punto de entrada.
	var player := get_node_or_null("Player")
	if player == null or player.global_position.y < FALL_LIMIT:
		return
	player.velocity = Vector2.ZERO
	player.global_position = _respawn_point
	if player.has_method("take_damage"):
		player.take_damage(1, Vector2.ZERO)
	var cam := get_node_or_null("Player/Camera2D")
	if cam:
		cam.reset_smoothing()


func _find_spawn(spawn_name: String) -> Marker2D:
	if spawns == null:
		return null
	var m := spawns.get_node_or_null(spawn_name)
	if m is Marker2D:
		return m
	# Fallback: el primer marcador que haya, para no dejar al jugador en (0,0).
	for child in spawns.get_children():
		if child is Marker2D:
			return child
	return null


func _setup_camera() -> void:
	var cam := get_node_or_null("Player/Camera2D")
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(world_width)
	cam.limit_bottom = 360
	# Sin esto la cámara viaja desde la posición anterior al entrar.
	cam.reset_smoothing()


func _announce() -> void:
	if screen_title.is_empty():
		return
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("_toast"):
		hud._toast(screen_title)
