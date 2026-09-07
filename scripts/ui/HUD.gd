extends CanvasLayer
## HUD del Nivel 1: vidas (3 casillas), puntos y poder activo.
## Se conecta a las señales de GameState y del Player.

@onready var life_boxes: HBoxContainer = $Root/TopLeft/Lives
@onready var hit_pips: HBoxContainer = $Root/TopLeft/HitPips
@onready var score_label: Label = $Root/TopRight/Score
@onready var power_label: Label = $Root/BottomLeft/PowerName
@onready var power_dot: ColorRect = $Root/BottomLeft/PowerDot
@onready var slots: HBoxContainer = $Root/BottomLeft/Slots
@onready var shield_badge: Panel = $Root/BottomLeft/ShieldBadge
@onready var shield_label: Label = $Root/BottomLeft/ShieldBadge/Count
@onready var toast_label: Label = $Root/Toast

## Los colores viven en GameState.POWER_INFO para que el HUD y la vista de
## mochila no se desincronicen.


func _ready() -> void:
	add_to_group("hud")
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.power_collected.connect(_on_power_collected)
	_refresh_all()
	_set_shield_visible(false)
	# Espera 1 frame a que el Player entre en el grupo antes de buscarlo.
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p = players[0]
		if p.has_signal("active_power_changed"):
			p.active_power_changed.connect(_on_active_power_changed)
			_on_active_power_changed(p.active_power)
		if p.has_signal("shield_charges_changed"):
			p.shield_charges_changed.connect(_on_shield_charges_changed)
			_on_shield_charges_changed(p.shield_charges)
		if p.has_signal("hits_before_life_changed"):
			p.hits_before_life_changed.connect(_on_hits_before_life_changed)
			_on_hits_before_life_changed(p._hits_left_this_life)
		if p.has_signal("notice"):
			p.notice.connect(_toast)


func _refresh_all() -> void:
	_on_lives_changed(GameState.lives)
	_on_score_changed(GameState.score)
	_refresh_slots(-1)


## Pinta las 3 ranuras: apagada = aún no tienes ese poder, tenue = lo tienes,
## encendida = es el activo. Así se ve de un vistazo cuántos llevas.
func _refresh_slots(active_power: int) -> void:
	for i in slots.get_child_count():
		var slot: ColorRect = slots.get_child(i)
		var power_id := i + 1
		var base: Color = GameState.power_color(power_id)
		if not GameState.has_power(power_id):
			slot.color = Palette.UI_SLOT
		elif power_id == active_power:
			slot.color = base
		else:
			slot.color = Palette.alpha(base, 0.4)


func _on_lives_changed(n: int) -> void:
	for i in life_boxes.get_child_count():
		var box: ColorRect = life_boxes.get_child(i)
		box.color = Palette.UI_LIFE if i < n else Palette.UI_SLOT


func _on_score_changed(s: int) -> void:
	score_label.text = "Puntos: %d" % s


func _on_active_power_changed(power_id: int) -> void:
	_refresh_slots(power_id)
	if power_id == -1:
		power_label.text = "Sin poderes — derrota robots para conseguirlos"
		power_dot.color = Palette.UI_INACTIVE
		return
	var info: Dictionary = GameState.POWER_INFO.get(power_id, {"name": "?"})
	power_label.text = "Poder: %s (%d/3)   Q usar · TAB cambiar" % [
		info["name"], GameState.backpack.size()]
	power_dot.color = GameState.power_color(power_id)


func _on_power_collected(power_id: int) -> void:
	var info: Dictionary = GameState.POWER_INFO.get(power_id, {"name": "?"})
	_toast("¡Nuevo poder: %s! (%d/3)" % [info["name"], GameState.backpack.size()])
	_refresh_slots(power_id)


func _on_shield_charges_changed(n: int) -> void:
	shield_label.text = "x%d" % n
	_set_shield_visible(n > 0)
	if n > 0:
		_toast("¡Escudo activado! (x%d)" % n)


func _set_shield_visible(on: bool) -> void:
	shield_badge.visible = on


func _on_hits_before_life_changed(remaining: int) -> void:
	# Rellena los pips de golpes restantes hasta perder vida.
	for i in hit_pips.get_child_count():
		var pip: ColorRect = hit_pips.get_child(i)
		pip.color = Palette.UI_PIP if i < remaining else Palette.UI_INACTIVE


var _toast_tween: Tween


## Punto de entrada público para que otros nodos (servidores, meta) puedan
## avisar al jugador sin conocer las tripas del HUD.
func show_message(msg: String) -> void:
	_toast(msg)


## Con los controles táctiles en pantalla, la franja inferior izquierda la
## ocupan los botones de movimiento, así que el indicador de poder se sube
## debajo de las vidas.
func set_touch_mode(on: bool) -> void:
	var bottom_left: Control = $Root/BottomLeft
	if on:
		bottom_left.anchor_top = 0.0
		bottom_left.anchor_bottom = 0.0
		bottom_left.offset_top = 66.0
		bottom_left.offset_bottom = 86.0
		# Se recorta por la derecha para no meterse debajo del botón BOLSA.
		bottom_left.offset_right = 560.0
	else:
		bottom_left.anchor_top = 1.0
		bottom_left.anchor_bottom = 1.0
		bottom_left.offset_top = -28.0
		bottom_left.offset_bottom = -8.0


func _toast(msg: String) -> void:
	# Ahora los avisos son mucho más frecuentes, así que hay que cancelar el
	# anterior: si no, dos tweens sobre el mismo Label se pisan y el texto
	# nuevo se desvanece con el tiempo restante del viejo.
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)
