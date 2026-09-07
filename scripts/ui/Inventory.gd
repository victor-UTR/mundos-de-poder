extends Control
## Vista de mochila (tecla I). Muestra los 3 poderes del Nivel 1, cuáles
## tienes, cuál estás usando y, si te falta alguno, qué robot lo suelta.
##
## Pausa el juego mientras está abierta y permite cambiar de poder con
## 1/2/3, para que se pueda consultar con calma sin que te maten mientras.

const LOCKED_COLOR := Color(0.28, 0.28, 0.32)

@onready var list: VBoxContainer = $Panel/Box/List
@onready var gifts_label: Label = $Panel/Box/Gifts
@onready var hint_label: Label = $Panel/Box/Hint

var is_open: bool = false


func _ready() -> void:
	visible = false
	# Debe seguir respondiendo con el árbol pausado, o no se podría cerrar.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Se consulta el estado de las acciones en vez de escuchar eventos: los
## botones táctiles usan Input.action_press(), que cambia el estado pero no
## genera un InputEvent que recorra el árbol, así que con _unhandled_input
## la mochila no se abriría desde el móvil.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		toggle()
		return
	if not is_open:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		close()
		return
	# Cambiar de poder desde la mochila. El juego está pausado, así que el
	# Player no puede atender él estas teclas.
	for slot in 3:
		if Input.is_action_just_pressed("power_%d" % (slot + 1)):
			_select(slot)
			return


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	visible = true
	_refresh()
	get_tree().paused = true


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false


func _select(slot: int) -> void:
	if slot < 0 or slot >= GameState.backpack.size():
		return
	var player := _player()
	if player and player.has_method("select_power_slot"):
		player.select_power_slot(slot)
	_refresh()


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _refresh() -> void:
	# free() y no queue_free(): las filas se reconstruyen en el mismo frame y
	# con queue_free() convivirían un frame con las nuevas, duplicando la
	# lista a la vista.
	for child in list.get_children():
		list.remove_child(child)
		child.free()

	var player := _player()
	var active: int = player.active_power if player else -1
	var shield: int = player.shield_charges if player else 0

	var slot := 0
	for power_id in GameState.POWER_ORDER:
		var owned := GameState.has_power(power_id)
		# La ranura 1/2/3 es la posición en la mochila, no el id del poder:
		# si sólo tienes el EMP, es tu poder número 1.
		var slot_text := ""
		if owned:
			slot += 1
			slot_text = str(slot)
		list.add_child(_make_row(power_id, owned, power_id == active, shield, slot_text))

	if GameState.gifts.is_empty():
		gifts_label.text = "Regalos recibidos: ninguno todavía"
	else:
		var names := []
		for g in GameState.gifts:
			names.append("%s (de %s)" % [
				GameState.power_name(int(g.get("power", -1))),
				String(g.get("from", "?"))])
		gifts_label.text = "Regalos recibidos: " + ", ".join(names)

	var have := GameState.backpack.size()
	hint_label.text = "Tienes %d de 3 poderes · 1/2/3 cambiar · I o Esc cerrar" % have


func _make_row(power_id: int, owned: bool, is_active: bool, shield: int, slot_text: String) -> Control:
	var info: Dictionary = GameState.POWER_INFO.get(power_id, {})
	var color: Color = GameState.power_color(power_id)

	var row := PanelContainer.new()
	row.self_modulate = Color(1, 1, 1, 0.5 if owned else 0.25)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(18, 18)
	dot.color = color if owned else LOCKED_COLOR
	hbox.add_child(dot)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	hbox.add_child(texts)

	var title := Label.new()
	var prefix := "[%s] " % slot_text if slot_text != "" else ""
	title.text = "%s%s" % [prefix, info.get("name", "?")]
	title.add_theme_color_override("font_color", color if owned else LOCKED_COLOR)
	texts.add_child(title)

	var desc := Label.new()
	if owned:
		desc.text = info.get("desc", "")
		if power_id == GameState.Power.SHIELD:
			desc.text += "  (cargas: %d)" % shield
	else:
		desc.text = "Bloqueado — lo suelta el %s" % info.get("source", "?")
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)

	var state := Label.new()
	if is_active:
		state.text = "EN USO"
		state.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	elif owned:
		state.text = "en mochila"
		state.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	else:
		state.text = "—"
		state.add_theme_color_override("font_color", LOCKED_COLOR)
	state.add_theme_font_size_override("font_size", 11)
	state.custom_minimum_size = Vector2(76, 0)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(state)

	return row
