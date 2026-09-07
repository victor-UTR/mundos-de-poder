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

## Panel de diagnóstico. Se activa añadiendo ?debug a la URL y sirve para
## depurar en un móvil ajeno, donde no hay consola a la que asomarse.
var _diag: Label
var _diag_events: int = 0
var _env_info: String = ""


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
	_setup_diag()


func _setup_diag() -> void:
	if not _debug_requested():
		return
	_diag = Label.new()
	_diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diag.position = Vector2(8, 96)
	_diag.size = Vector2(400, 120)
	_diag.add_theme_font_size_override("font_size", 10)
	_diag.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	add_child(_diag)
	# En iOS (y cualquier pantalla Retina) el devicePixelRatio es 2 o 3. Si
	# las coordenadas del toque llegan multiplicadas por ese factor, caen
	# fuera de los botones y el personaje no responde.
	_env_info = str(JavaScriptBridge.eval(
		"'dpr=' + window.devicePixelRatio + ' css=' + Math.round(window.innerWidth) + 'x' + Math.round(window.innerHeight) + ' ua=' + (navigator.userAgent.match(/iPhone|iPad|Android/) || ['?'])[0]",
		true))
	_update_diag("esperando eventos")


## ?debug en la URL enciende el diagnóstico (sólo en el export web).
func _debug_requested() -> bool:
	if not OS.has_feature("web"):
		return false
	var query := str(JavaScriptBridge.eval("window.location.search", true))
	return query.find("debug") != -1


var _diag_last: String = "esperando eventos"


func _process(_delta: float) -> void:
	_sweep_stuck_actions()
	# El diagnóstico se refresca cada frame: así se ve si el juego avanza o
	# está congelado, que es la diferencia entre "no llega la entrada" y "la
	# entrada llega pero nada se mueve".
	if _diag:
		_update_diag(_diag_last)


func _update_diag(last_event: String) -> void:
	if _diag == null:
		return
	_diag_last = last_event
	var player := get_tree().get_first_node_in_group("player")
	var player_info := "SIN PLAYER"
	if player:
		player_info = "x=%.0f  vel=%.0f" % [
			player.global_position.x, player.velocity.x]
	var inv := get_parent().get_node_or_null("Inventory") if get_parent() else null
	_diag.text = "DIAG ev=%d  frame=%d  PAUSA=%s\nultimo: %s\nL=%s R=%s salto=%s\nplayer: %s\nmochila_abierta=%s\nvisible=%s touch=%s vp=%s\nmantenidas: %s\nentorno: " % [
		_diag_events,
		Engine.get_process_frames(),
		str(get_tree().paused),
		last_event,
		str(Input.is_action_pressed("move_left")),
		str(Input.is_action_pressed("move_right")),
		str(Input.is_action_pressed("jump")),
		player_info,
		str(inv.is_open) if inv else "?",
		str(visible),
		str(DisplayServer.is_touchscreen_available()),
		str(get_viewport().get_visible_rect().size),
		str(_finger_action.values()),
	] + _env_info


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


## Índice de "dedo" que se usa para el ratón, para que no choque con los
## índices reales de los toques (que empiezan en 0).
const MOUSE_FINGER := -1


func _input(event: InputEvent) -> void:
	if _diag and (event is InputEventScreenTouch or event is InputEventScreenDrag \
			or event is InputEventMouseButton or event is InputEventMouseMotion):
		_diag_events += 1
		var pos: Vector2 = event.position if "position" in event else Vector2.ZERO
		_update_diag("%s @ %s -> '%s'" % [
			event.get_class(), str(pos.round()), _action_at(pos)])

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
		_drag(event.index, event.position)
	# Respaldo por ratón. Godot emula el ratón a partir del táctil
	# (emulate_mouse_from_touch), así que si en algún navegador móvil no
	# llegan los eventos de dedo, estos clics sí llegan y el juego se puede
	# jugar igualmente (sin multitáctil). Sirve también para probar los
	# controles con el ratón en el escritorio.
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(MOUSE_FINGER, _action_at(event.position))
			else:
				_release(MOUSE_FINGER)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drag(MOUSE_FINGER, event.position)


func _drag(finger: int, pos: Vector2) -> void:
	var current: String = _finger_action.get(finger, "")
	var target := _action_at(pos)
	if target != current:
		_release(finger)
		_press(finger, target)


## Acciones que ha activado este nodo. Sirve de red de seguridad para no
## dejar ninguna "pegada", y para no soltar nunca una que venga del teclado.
var _my_actions: Dictionary = {}


func _press(finger: int, action: String) -> void:
	if action == "":
		return
	_finger_action[finger] = action
	_my_actions[action] = true
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
		_my_actions.erase(action)
		_set_button_held(action, false)


## Si no queda ningún dedo ni el ratón pulsados, ninguna acción nuestra
## debería seguir activa. En el móvil llegan dos eventos por toque (el dedo
## y el ratón emulado) y si el soltado se descuadra puede quedarse una
## pegada: con move_left y move_right activas a la vez el eje se anula y el
## personaje no se mueve aunque todo lo demás parezca correcto.
## Sólo se tocan las acciones activadas por estos botones, nunca las del
## teclado.
func _sweep_stuck_actions() -> void:
	if not _finger_action.is_empty() or _my_actions.is_empty():
		return
	for action in _my_actions.keys():
		Input.action_release(action)
		_set_button_held(action, false)
	_my_actions.clear()


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
