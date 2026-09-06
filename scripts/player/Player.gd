extends CharacterBody2D
## Personaje jugable del Nivel 1.
## Controles: A/D o flechas = mover, Espacio/Arriba = saltar, J = atacar,
## Q = usar poder, TAB = cambiar poder activo, E = interactuar.

@export var speed: float = 140.0
@export var jump_velocity: float = -300.0
@export var gravity: float = 900.0
@export var max_fall_speed: float = 500.0

var active_power: int = -1        # id del poder activo (o -1)
var shield_charges: int = 0        # cargas de escudo pendientes
var invulnerable_until: float = 0.0

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	# Selecciona el primer poder disponible como activo por defecto.
	if not GameState.backpack.is_empty():
		active_power = GameState.backpack[0]
	GameState.power_collected.connect(_on_power_collected)


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	# Movimiento horizontal
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * speed

	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Cambio de poder activo
	if Input.is_action_just_pressed("cycle_power"):
		_cycle_power()

	# Usar poder
	if Input.is_action_just_pressed("use_power"):
		_use_active_power()

	move_and_slide()


func take_damage(amount: int = 1) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < invulnerable_until:
		return
	if shield_charges > 0:
		shield_charges -= 1
		_flash(Color(0.4, 0.8, 1.0))
		invulnerable_until = now + 0.8
		return
	GameState.lose_life()
	_flash(Color(1.0, 0.3, 0.3))
	invulnerable_until = now + 1.0
	if GameState.lives <= 0:
		_die()


func _die() -> void:
	# Placeholder: reinicia la escena actual.
	GameState.lives = 3
	GameState.lives_changed.emit(GameState.lives)
	get_tree().reload_current_scene()


func _cycle_power() -> void:
	if GameState.backpack.is_empty():
		return
	var idx := GameState.backpack.find(active_power)
	idx = (idx + 1) % GameState.backpack.size()
	active_power = GameState.backpack[idx]
	print("Poder activo: ", GameState.POWER_INFO[active_power]["name"])


func _use_active_power() -> void:
	if active_power == -1:
		return
	match active_power:
		GameState.Power.SHIELD:
			shield_charges += 1
			_flash(Color(0.4, 0.8, 1.0))
		GameState.Power.EMP:
			_emit_emp()
		GameState.Power.VISION:
			_reveal_hidden()


func _emit_emp() -> void:
	# Aturde enemigos en radio.
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.global_position.distance_to(global_position) <= 120.0:
			if e.has_method("stun"):
				e.stun(2.0)
	_flash(Color(1.0, 1.0, 0.4))


func _reveal_hidden() -> void:
	for h in get_tree().get_nodes_in_group("hidden"):
		if h.has_method("reveal"):
			h.reveal(3.0)


func _flash(c: Color) -> void:
	if sprite:
		var original := sprite.color
		sprite.color = c
		await get_tree().create_timer(0.15).timeout
		sprite.color = original


func _on_power_collected(power_id: int) -> void:
	if active_power == -1:
		active_power = power_id
