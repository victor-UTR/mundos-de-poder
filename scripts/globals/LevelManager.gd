extends Node
## Orquesta las pantallas del Nivel 1: carga la escena destino, recuerda en
## qué punto de entrada hay que colocar al jugador y hace el fundido a negro.
##
## Uso desde una puerta:  LevelManager.go_to(2, "from_left")
##
## Cada escena de pantalla lleva el script LevelScreen.gd, que al arrancar
## lee `pending_spawn` y mueve al Player al Marker2D correspondiente.

## Rutas de las 5 pantallas, en orden. El índice de pantalla es 1-based
## (pantalla 1 = SCREENS[0]) porque así se lee igual que en docs/NIVEL1.md.
const SCREENS := [
	"res://scenes/levels/Screen1.tscn",
	"res://scenes/levels/Screen2.tscn",
	"res://scenes/levels/Screen3.tscn",
	"res://scenes/levels/Screen4.tscn",
	"res://scenes/levels/Screen5.tscn",
]

const FADE_TIME := 0.22

## Nombre del Marker2D donde debe aparecer el jugador en la próxima pantalla.
var pending_spawn: String = "start"
var current_screen: int = 1

var _transitioning: bool = false
var _fade: ColorRect


func _ready() -> void:
	# El fundido vive en el autoload, así sobrevive al cambio de escena.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func screen_count() -> int:
	return SCREENS.size()


## Cambia a `screen` (1-based) y coloca al jugador en el marcador `spawn`.
func go_to(screen: int, spawn: String = "from_left") -> void:
	if _transitioning:
		return
	if screen < 1 or screen > SCREENS.size():
		push_warning("LevelManager: pantalla fuera de rango: %d" % screen)
		return

	_transitioning = true
	pending_spawn = spawn
	current_screen = screen
	GameState.current_screen = screen
	GameState.save_game()

	await _fade_to(1.0)
	get_tree().change_scene_to_file(SCREENS[screen - 1])
	# Dos frames: uno para que se libere la escena vieja y otro para que la
	# nueva termine su _ready() (incluido el reposicionado del Player).
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)
	_transitioning = false


## Arranca el nivel en la pantalla guardada (o en la 1 si no hay progreso).
func start_or_resume() -> void:
	var screen: int = clampi(GameState.current_screen, 1, SCREENS.size())
	# `start` sólo existe en la pantalla 1; el resto usan `from_left`.
	var spawn := "start" if screen == 1 else "from_left"
	go_to(screen, spawn)


func _fade_to(alpha: float) -> void:
	if _fade == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished
