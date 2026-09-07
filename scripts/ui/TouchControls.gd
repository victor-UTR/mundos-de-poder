extends Control
## Controles en pantalla para móvil y tablet.
##
## No usa nodos Button a propósito: Godot emula un único ratón a partir del
## táctil, así que con botones normales no se podría correr y saltar a la
## vez. Aquí se leen los eventos de dedo (InputEventScreenTouch/Drag) y se
## lleva la cuenta de qué dedo está sobre qué botón, de modo que varios
## dedos funcionan a la vez y se puede deslizar de ◀ a ▶ sin levantarlo.

## Botón (nombre del nodo hijo) -> acción del InputMap que dispara.
const BUTTON_ACTIONS := {
	"Left": "move_left",
	"Right": "move_right",
	"Jump": "jump",
	"Attack": "attack",
	"Power": "use_power",
	"Interact": "interact",
	"Inventory": "inventory",
}

const IDLE_ALPHA := 0.28
const HELD_ALPHA := 0.60

## Dedo (índice de toque) -> acción que está manteniendo pulsada.
var _finger_action: Dictionary = {}


func _ready() -> void:
	# Deben seguir vivos con el juego pausado, o no se podría cerrar la
	# mochila desde el móvil.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node_name in BUTTON_ACTIONS:
		var b := get_node_or_null(node_name)
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.modulate.a = IDLE_ALPHA
	set_controls_visible(_is_touch_device())


## Detectar el táctil en el export web es poco de fiar: en Chrome de Android
## `is_touchscreen_available()` devuelve false a menudo, y entonces el juego
## se ve pero no hay forma de controlarlo. Se combinan varias señales, y
## además los controles aparecen solos al primer toque (ver _input), que es
## la única prueba que no falla: si tocas la pantalla, hay pantalla táctil.
func _is_touch_device() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	for f in ["mobile", "android", "ios", "web_android", "web_ios"]:
		if OS.has_feature(f):
			return true
	return false


## Muestra u oculta los controles y avisa al HUD para que recoloque lo que
## quede debajo de los botones.
func set_controls_visible(on: bool) -> void:
	visible = on
	if not on:
		_release_all()
	var hud := get_parent()
	while hud and not hud.has_method("set_touch_mode"):
		hud = hud.get_parent()
	if hud:
		hud.set_touch_mode(on)


func _unhandled_key_input(event: InputEvent) -> void:
	# F9 los enseña u oculta a mano: sirve para ajustarlos en escritorio sin
	# exportar a web, y para quitarlos de en medio en un portátil táctil,
	# donde la detección automática los sacaría sin hacer falta.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F9:
		set_controls_visible(not visible)


func _input(event: InputEvent) -> void:
	# Si llega un toque real y los controles estaban ocultos, es que la
	# detección se equivocó: se muestran en el acto.
	if event is InputEventScreenTouch and event.pressed and not visible:
		set_controls_visible(true)

	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, _action_at(event.position))
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		# Al arrastrar, el dedo puede pasar de un botón a otro.
		var current: String = _finger_action.get(event.index, "")
		var target := _action_at(event.position)
		if target != current:
			_release(event.index)
			_press(event.index, target)


func _press(finger: int, action: String) -> void:
	if action == "":
		return
	_finger_action[finger] = action
	Input.action_press(action)
	_set_button_held(action, true)


func _release(finger: int) -> void:
	if not _finger_action.has(finger):
		return
	var action: String = _finger_action[finger]
	_finger_action.erase(finger)
	# Si otro dedo mantiene la misma acción, no se suelta.
	if action not in _finger_action.values():
		Input.action_release(action)
		_set_button_held(action, false)


func _release_all() -> void:
	for finger in _finger_action.keys():
		var action: String = _finger_action[finger]
		Input.action_release(action)
		_set_button_held(action, false)
	_finger_action.clear()


## Devuelve la acción del botón que hay bajo un punto, o "" si no hay ninguno.
func _action_at(pos: Vector2) -> String:
	for node_name in BUTTON_ACTIONS:
		var b := get_node_or_null(node_name)
		if b and b.get_global_rect().has_point(pos):
			return BUTTON_ACTIONS[node_name]
	return ""


func _set_button_held(action: String, held: bool) -> void:
	for node_name in BUTTON_ACTIONS:
		if BUTTON_ACTIONS[node_name] != action:
			continue
		var b := get_node_or_null(node_name)
		if b:
			b.modulate.a = HELD_ALPHA if held else IDLE_ALPHA
