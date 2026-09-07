extends Area2D
## Uno de los 3 servidores del Empire State (pantalla 5).
##
## Cada servidor exige un poder distinto, y no basta con tenerlo en la
## mochila: hay que usarlo (Q) en el momento adecuado y luego interactuar
## con E. Así el puzzle final repasa las tres mecánicas del nivel.
##
##   Visión → el botón está oculto; hay que revelarlo antes de pulsarlo.
##   Escudo → el servidor quema al acercarse; hay que llevar carga de escudo.
##   EMP    → tiene corriente; hay que aturdirla antes de tirar de la palanca.

signal disabled(server: Node)

@export var required_power: int = 1
@export var title: String = "Servidor A"
## Cada cuánto daña el servidor de Escudo a quien se acerca sin protección.
@export var burn_interval: float = 1.2

var is_off: bool = false

var _player: Node = null
var _revealed_until: float = 0.0
var _stunned_until: float = 0.0
var _next_burn: float = 0.0

@onready var body_rect: ColorRect = $Body
@onready var light: ColorRect = $Light
@onready var label: Label = $Title


func _ready() -> void:
	add_to_group("servers")
	# El poder que hace falta determina de qué "escucha" el servidor.
	match required_power:
		GameState.Power.VISION:
			# Player._reveal_hidden() recorre este grupo y llama a reveal().
			add_to_group("hidden")
		GameState.Power.EMP:
			# Player._emit_emp() recorre este grupo y llama a stun().
			add_to_group("emp_targets")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.text = "%s\n%s" % [title, _requirement_hint()]
	_refresh_visuals()


func _process(_delta: float) -> void:
	if is_off:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_refresh_visuals()

	if _player == null:
		return

	# El servidor del Escudo castiga acercarse desprotegido.
	if required_power == GameState.Power.SHIELD and _player.shield_charges <= 0:
		if now >= _next_burn:
			_next_burn = now + burn_interval
			if _player.has_method("take_damage"):
				_player.take_damage(1, global_position)
			_say("¡Quema! Activa el Escudo con Q")

	if Input.is_action_just_pressed("interact"):
		_try_disable(now)


# --- Interacción -----------------------------------------------------------
func _try_disable(now: float) -> void:
	if not GameState.has_power(required_power):
		_say("Te falta el poder: %s" % _power_name())
		return

	match required_power:
		GameState.Power.VISION:
			if now >= _revealed_until:
				_say("Botón oculto. Usa la Visión (Q) y pulsa E")
				return
		GameState.Power.SHIELD:
			if not _player.has_method("consume_shield") or not _player.consume_shield():
				_say("Necesitas una carga de Escudo. Pulsa Q")
				return
		GameState.Power.EMP:
			if now >= _stunned_until:
				_say("Tiene corriente. Lánzale el EMP (Q) y pulsa E")
				return

	_disable()


func _disable() -> void:
	is_off = true
	_refresh_visuals()
	Audio.play("enemy_death")
	GameState.add_score(30)
	_say("%s apagado" % title)
	disabled.emit(self)


# --- Reacciones a los poderes ---------------------------------------------
## Llamado por el poder de Visión (grupo "hidden").
func reveal(duration: float = 6.0) -> void:
	_revealed_until = Time.get_ticks_msec() / 1000.0 + duration


## Llamado por el poder EMP (grupo "emp_targets").
func stun(duration: float = 2.0) -> void:
	_stunned_until = Time.get_ticks_msec() / 1000.0 + duration


# --- Presentación ----------------------------------------------------------
func _refresh_visuals() -> void:
	if is_off:
		body_rect.color = Color(0.25, 0.4, 0.3)
		light.color = Color(0.4, 0.95, 0.5)
		return
	body_rect.color = Color(0.35, 0.2, 0.24)
	# La luz avisa de si ahora mismo se puede actuar: verde = adelante.
	var now := Time.get_ticks_msec() / 1000.0
	var ready_now := false
	match required_power:
		GameState.Power.VISION:
			ready_now = now < _revealed_until
		GameState.Power.EMP:
			ready_now = now < _stunned_until
		GameState.Power.SHIELD:
			ready_now = _player != null and _player.shield_charges > 0
	light.color = Color(0.4, 0.95, 0.5) if ready_now else Color(0.95, 0.3, 0.3)


func _requirement_hint() -> String:
	return "Necesita: %s" % _power_name()


func _power_name() -> String:
	var info: Dictionary = GameState.POWER_INFO.get(required_power, {"name": "?"})
	return info["name"]


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body
		if not is_off:
			_say("%s — %s. Pulsa E" % [title, _requirement_hint()])


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null


var _last_say: String = ""
var _last_say_at: float = 0.0


func _say(msg: String) -> void:
	# Estos avisos salen desde _process, así que hay que evitar repetirlos
	# 60 veces por segundo.
	var now := Time.get_ticks_msec() / 1000.0
	if msg == _last_say and now - _last_say_at < 2.0:
		return
	_last_say = msg
	_last_say_at = now
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message(msg)
