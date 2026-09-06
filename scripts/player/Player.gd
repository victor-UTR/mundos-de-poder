extends CharacterBody2D
## Personaje jugable del Nivel 1.
## Controles: A/D o flechas = mover, Espacio/Arriba = saltar, J = atacar,
## Q = usar poder, TAB = cambiar poder activo, E = interactuar.

signal active_power_changed(power_id: int)

@export var speed: float = 140.0
@export var jump_velocity: float = -360.0
@export var double_jump_velocity: float = -300.0
@export var max_jumps: int = 2
@export var gravity: float = 1100.0
@export var max_fall_speed: float = 520.0
@export var attack_damage: int = 1
@export var attack_duration: float = 0.15
@export var attack_cooldown: float = 0.35

var active_power: int = -1        # id del poder activo (o -1)
var shield_charges: int = 0        # cargas de escudo pendientes
var invulnerable_until: float = 0.0
var jumps_left: int = 0            # saltos restantes en el aire
var facing: int = 1                # 1 = derecha, -1 = izquierda
var _attack_end: float = 0.0       # tiempo hasta que se apaga la hitbox
var _attack_ready_at: float = 0.0  # cooldown

@onready var sprite: ColorRect = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_sprite: ColorRect = $Hitbox/Sprite


func _ready() -> void:
	add_to_group("player")
	if not GameState.backpack.is_empty():
		active_power = GameState.backpack[0]
	GameState.power_collected.connect(_on_power_collected)
	_set_hitbox_active(false)


func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	# Gravedad
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
	else:
		jumps_left = max_jumps

	# Movimiento horizontal
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * speed
	if dir != 0.0:
		facing = int(sign(dir))
		_flip_hitbox()

	# Salto con doble salto
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		if is_on_floor():
			velocity.y = jump_velocity
		else:
			velocity.y = double_jump_velocity
		jumps_left -= 1

	# Cambio de poder activo
	if Input.is_action_just_pressed("cycle_power"):
		_cycle_power()

	# Usar poder
	if Input.is_action_just_pressed("use_power"):
		_use_active_power()

	# Atacar
	if Input.is_action_just_pressed("attack") and now >= _attack_ready_at:
		_start_attack(now)

	# Apagar hitbox si toca
	if _attack_end > 0.0 and now >= _attack_end:
		_set_hitbox_active(false)
		_attack_end = 0.0

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
	GameState.lives = 3
	GameState.lives_changed.emit(GameState.lives)
	get_tree().reload_current_scene()


# --- Ataque ---------------------------------------------------------------
func _start_attack(now: float) -> void:
	_set_hitbox_active(true)
	_attack_end = now + attack_duration
	_attack_ready_at = now + attack_cooldown
	# Hit check instantáneo: pregunto al espacio de físicas qué cuerpos
	# hay dentro del shape de la hitbox AHORA. Evita el retardo de un
	# frame que tiene Area2D.get_overlapping_bodies() al recién activarse.
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = hitbox_shape.shape
	params.transform = hitbox.global_transform
	params.collision_mask = 4          # capa 3 = enemy
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	var hits := space.intersect_shape(params, 8)
	for h in hits:
		var body = h.get("collider")
		if body and body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(attack_damage)


func _set_hitbox_active(on: bool) -> void:
	hitbox_shape.disabled = not on
	hitbox_sprite.visible = on


func _flip_hitbox() -> void:
	hitbox.position.x = 14.0 * facing


# --- Poderes --------------------------------------------------------------
func _cycle_power() -> void:
	if GameState.backpack.is_empty():
		return
	var idx := GameState.backpack.find(active_power)
	idx = (idx + 1) % GameState.backpack.size()
	active_power = GameState.backpack[idx]
	active_power_changed.emit(active_power)


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
		if is_instance_valid(sprite):
			sprite.color = original


func _on_power_collected(power_id: int) -> void:
	if active_power == -1:
		active_power = power_id
		active_power_changed.emit(active_power)
