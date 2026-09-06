extends CanvasLayer
## HUD del Nivel 1: vidas (3 casillas), puntos y poder activo.
## Se conecta a las señales de GameState y del Player.

@onready var life_boxes: HBoxContainer = $Root/TopLeft/Lives
@onready var hit_pips: HBoxContainer = $Root/TopLeft/HitPips
@onready var score_label: Label = $Root/TopRight/Score
@onready var power_label: Label = $Root/BottomLeft/PowerName
@onready var power_dot: ColorRect = $Root/BottomLeft/PowerDot
@onready var shield_badge: Panel = $Root/BottomLeft/ShieldBadge
@onready var shield_label: Label = $Root/BottomLeft/ShieldBadge/Count
@onready var toast_label: Label = $Root/Toast

const POWER_COLORS := {
	1: Color(0.55, 0.85, 1.0),   # Visión (azul claro)
	2: Color(0.4, 0.9, 0.5),     # Escudo (verde)
	3: Color(1.0, 0.85, 0.3),    # EMP (amarillo)
}


func _ready() -> void:
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


func _refresh_all() -> void:
	_on_lives_changed(GameState.lives)
	_on_score_changed(GameState.score)


func _on_lives_changed(n: int) -> void:
	for i in life_boxes.get_child_count():
		var box: ColorRect = life_boxes.get_child(i)
		box.color = Color(0.95, 0.3, 0.3) if i < n else Color(0.25, 0.25, 0.28)


func _on_score_changed(s: int) -> void:
	score_label.text = "Puntos: %d" % s


func _on_active_power_changed(power_id: int) -> void:
	if power_id == -1:
		power_label.text = "Poder: —"
		power_dot.color = Color(0.3, 0.3, 0.35)
		return
	var info: Dictionary = GameState.POWER_INFO.get(power_id, {"name": "?"})
	power_label.text = "Poder: %s   (Q usar · TAB cambiar)" % info["name"]
	power_dot.color = POWER_COLORS.get(power_id, Color.WHITE)


func _on_power_collected(power_id: int) -> void:
	var info: Dictionary = GameState.POWER_INFO.get(power_id, {"name": "?"})
	_toast("¡Nuevo poder: %s!" % info["name"])


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
		pip.color = Color(1, 0.9, 0.3) if i < remaining else Color(0.3, 0.3, 0.35)


func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)
