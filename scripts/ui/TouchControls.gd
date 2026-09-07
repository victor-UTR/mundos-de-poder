extends Control
## Controles en pantalla para móvil y tablet.
##
## No usa nodos Button a propósito: Godot emula un único ratón a partir del
## táctil, así que con botones normales no se podría correr y saltar a la
## vez. Aquí se leen los eventos de dedo (InputEventScreenTouch/Drag) y se
## traducen a acciones del InputMap con Input.action_press/release.
##
## IMPORTANTE — por qué NO se usa `event.index`:
## En el export web sobre iOS/iPadOS, Godot devuelve un `index` basura (un
## entero enorme que se incrementa en CADA evento, sin relación con el dedo).
## Es el bug godotengine/godot#95941, sin arreglar en 4.7. Cualquier código
## que empareje el "soltar" con el "pulsar" por índice nunca encuentra la
## pareja, así que la acción se queda pulsada para siempre: con move_left y
## move_right pegadas a la vez el eje se anula y el personaje no se mueve.
## Por el mismo motivo tampoco sirve TouchScreenButton, que internamente
## compara índices igual.
##
## La coordenada del evento SÍ es correcta, así que aquí los dedos se
## identifican por posición: cada botón es una región separada de la
## pantalla, y eso basta para saber a cuál pertenece cada toque.

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

## Los botones ya llevan su propia transparencia en el color, así que el
## estado "pulsado" se marca subiendo el brillo, no la opacidad. Antes eran
## Panel con el estilo por defecto (gris azulado muy oscuro) al 28% de
## opacidad: sobre el fondo negro del juego resultaban invisibles y el
## primer probador nunca llegó a verlos.
const IDLE_MODULATE := Color(1, 1, 1, 1)
const HELD_MODULATE := Color(1.7, 1.7, 1.7, 1)

## Radio (en unidades del viewport, que mide 640x360 fijo) dentro del cual un
## evento de arrastre o de soltar se considera del mismo dedo que mantiene
## una acción. Los botones son de 64, así que 100 permite algo de deriva sin
## llegar a robarle el dedo al botón de al lado.
const FINGER_MATCH_RADIUS := 100.0

## Acción mantenida -> última posición conocida del dedo que la mantiene.
## Esto sustituye al antiguo mapa dedo->acción, que dependía de `event.index`.
var _held: Dictionary = {}

## Panel de diagnóstico. Se activa añadiendo ?debug a la URL y sirve para
## depurar en un móvil ajeno, donde no hay consola a la que asomarse.
var _diag: Label
var _diag_events: int = 0
var _env_info: String = ""
var _diag_last: String = "esperando eventos"


func _ready() -> void:
	# Deben seguir vivos con el juego pausado, o no se podría cerrar la
	# mochila desde el móvil.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node_name in BUTTON_ACTIONS:
		var b := get_node_or_null(node_name)
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.modulate = IDLE_MODULATE
	set_controls_visible(_should_show_controls())
	_setup_diag()
	# _process sólo existe para refrescar el diagnóstico.
	set_process(_diag != null)


## En web se muestran SIEMPRE, sin intentar adivinar si hay pantalla táctil.
##
## Antes se decidía con DisplayServer.is_touchscreen_available() y las
## feature tags, y falla en los dos sentidos: en Chrome de Android da false
## a menudo, y en Safari de iPhone tampoco los sacó (el juego se veía —vidas
## y puntos en pantalla— pero no había ningún botón que tocar). El coste de
## equivocarse es un juego literalmente injugable en el móvil, mientras que
## el coste de sacarlos de más en un navegador de escritorio es casi nulo:
## responden al ratón y F9 los quita.
func _should_show_controls() -> bool:
	if OS.has_feature("web"):
		return true
	return DisplayServer.is_touchscreen_available()


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


func _process(_delta: float) -> void:
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
		str(_held.keys()),
	] + _env_info


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
	# donde ahora salen siempre.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F9:
		set_controls_visible(not visible)


## Se pone a true en cuanto llega el primer evento de dedo de verdad. A
## partir de ahí el ratón se ignora: Godot emula el ratón a partir del táctil
## (emulate_mouse_from_touch), así que cada toque llegaría dos veces.
var _has_real_touch: bool = false


func _input(event: InputEvent) -> void:
	if _diag and (event is InputEventScreenTouch or event is InputEventScreenDrag \
			or event is InputEventMouseButton or event is InputEventMouseMotion):
		_diag_events += 1
		var pos: Vector2 = event.position if "position" in event else Vector2.ZERO
		_update_diag("%s @ %s -> '%s'" % [
			event.get_class(), str(pos.round()), _action_at(pos)])

	if event is InputEventScreenTouch:
		if not _has_real_touch:
			_has_real_touch = true
			# Lo que hubiera activado el ratón emulado deja de contar.
			_release_all()
		# Si llega un toque real y los controles estaban ocultos, es que la
		# detección se equivocó: se muestran en el acto.
		if event.pressed and not visible:
			set_controls_visible(true)

	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_press_at(event.position)
		else:
			_release_at(event.position)
	elif event is InputEventScreenDrag:
		_move_at(event.position)
	# Respaldo por ratón, para el escritorio y para cualquier navegador que
	# no entregue eventos de dedo. Un ratón es un único puntero, así que las
	# mismas funciones por posición valen tal cual.
	elif event is InputEventMouseButton and not _has_real_touch:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_at(event.position)
			else:
				_release_at(event.position)
	elif event is InputEventMouseMotion and not _has_real_touch:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move_at(event.position)


# --- Seguimiento de dedos por posición -------------------------------------

func _press_at(pos: Vector2) -> void:
	var action := _action_at(pos)
	if action == "":
		return
	_held[action] = pos
	Input.action_press(action)
	_set_button_held(action, true)


## Al soltar, lo normal es que el dedo siga encima de su botón. Si no lo está
## (se ha deslizado fuera antes de levantarlo) se suelta la acción cuyo dedo
## estaba más cerca: sin índices fiables es la única forma de no dejarla
## pegada, y es la respuesta correcta en la práctica.
func _release_at(pos: Vector2) -> void:
	var action := _action_at(pos)
	if action == "" or not _held.has(action):
		action = _nearest_held(pos)
	if action == "":
		return
	_do_release(action)


## Un dedo puede deslizarse de un botón a otro sin levantarse (de ◀ a ▶).
func _move_at(pos: Vector2) -> void:
	var target := _action_at(pos)
	var owner_action := _nearest_held(pos)
	if owner_action != "" and owner_action != target:
		_do_release(owner_action)
	if target == "":
		return
	if not _held.has(target):
		_held[target] = pos
		Input.action_press(target)
		_set_button_held(target, true)
	else:
		_held[target] = pos


## Acción mantenida cuyo dedo está más cerca de `pos`, o "" si ninguna cae
## dentro de FINGER_MATCH_RADIUS. El radio evita que un dedo que arrastra por
## una zona vacía le robe el botón a otro que sí está pulsando.
func _nearest_held(pos: Vector2) -> String:
	var best := ""
	var best_dist := FINGER_MATCH_RADIUS
	for action in _held:
		var d: float = (_held[action] as Vector2).distance_to(pos)
		if d <= best_dist:
			best_dist = d
			best = action
	return best


func _do_release(action: String) -> void:
	if not _held.has(action):
		return
	_held.erase(action)
	Input.action_release(action)
	_set_button_held(action, false)


func _release_all() -> void:
	for action in _held.keys():
		Input.action_release(action)
		_set_button_held(action, false)
	_held.clear()


## Cambiar de pestaña o recibir una llamada con un dedo apoyado dejaría la
## acción pulsada al volver: el navegador no siempre entrega el "soltar".
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


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
			b.modulate = HELD_MODULATE if held else IDLE_MODULATE
