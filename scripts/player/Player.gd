extends CharacterBody2D
## Personaje jugable del Nivel 1.
## Controles: A/D o flechas = mover, Espacio/Arriba = saltar, J = atacar,
## Q = usar poder, TAB = cambiar poder activo, E = interactuar.

signal active_power_changed(power_id: int)
signal shield_charges_changed(n: int)
signal hits_before_life_changed(remaining: int)

@export var speed: float = 140.0
@export var jump_velocity: float = -360.0
@export var double_jump_velocity: float = -300.0
@export var max_jumps: int = 2
@export var gravity: float = 1100.0
@export var max_fall_speed: float = 520.0
@export var attack_damage: int = 1
@export var attack_duration: float = 0.15
@export var attack_cooldown: float = 0.35
## Golpes que hay que recibir para perder 1 vida. Cada vida = hits_per_life.
@export var hits_per_life: int = 2
## Impulso al recibir daño.
@export var knockback_x: float = 180.0
@export var knockback_y: float = -220.0
## Duración total tras recibir daño en la que no controlas al jugador.
@export var stagger_duration: float = 0.22

var active_power: int = -1        # id del poder activo (o -1)
var shield_charges: int = 0        # cargas de escudo pendientes
var invulnerable_until: float = 0.0
var jumps_left: int = 0            # saltos restantes en el aire
var facing: int = 1                # 1 = derecha, -1 = izquierda
var _attack_end: float = 0.0       # tiempo hasta que se apaga la hitbox
var _attack_ready_at: float = 0.0  # cooldown
var _hits_left_this_life: int = 2  # contador de golpes hasta perder vida
var _stagger_until: float = 0.0    # hasta cuando el input está bloqueado

@onready var sprite: ColorRect = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_sprite: ColorRect = $Hitbox/Sprite


@onready var shield_aura: Node2D = $ShieldAura


func _ready() -> void:
	add_to_group("player")
	if not GameState.backpack.is_empty():
		active_power = GameState.backpack[0]
	GameState.power_collected.connect(_on_power_collected)
	_set_hitbox_active(false)
	_hits_left_this_life = hits_per_life
	_update_shield_aura()
	# Emitir estado inicial al final del frame para que el HUD (que se
	# suscribe tras await process_frame) reciba el poder ya cargado desde
	# el save. Sin esto, si arrancas con mochila precargada el HUD dice
	# "Poder: —" hasta que pulses TAB.
	call_deferred("_emit_initial_state")


func _emit_initial_state() -> void:
	# Doble deferred: garantiza que el HUD ya ha hecho su await.
	await get_tree().process_frame
	active_power_changed.emit(active_power)
	shield_charges_changed.emit(shield_charges)
	hits_before_life_changed.emit(_hits_left_this_life)


func _unhandled_input(event: InputEvent) -> void:
	# Atajos de depuración (siempre activos, no dependen del stagger).
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F10:
				# Reset de la run actual (mochila + puntos + vidas).
				GameState.reset_run()
				GameState.save_game()
				get_tree().reload_current_scene()
			KEY_F11:
				# Reset total del save (incluye regalos y niveles).
				GameState.hard_reset()
				get_tree().reload_current_scene()
			KEY_F12:
				# Dump por consola del estado actual.
				print("[DEBUG] backpack=", GameState.backpack,
					" active_power=", active_power,
					" shield=", shield_charges,
					" lives=", GameState.lives,
					" score=", GameState.score)


func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var can_control := now >= _stagger_until

	# Gravedad
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
	else:
		jumps_left = max_jumps

	if can_control:
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
		# Selección directa por slot 1/2/3
		if Input.is_action_just_pressed("power_1"):
			_select_power_by_slot(0)
		if Input.is_action_just_pressed("power_2"):
			_select_power_by_slot(1)
		if Input.is_action_just_pressed("power_3"):
			_select_power_by_slot(2)

		# Usar poder
		if Input.is_action_just_pressed("use_power"):
			_use_active_power()

		# Atacar
		if Input.is_action_just_pressed("attack") and now >= _attack_ready_at:
			_start_attack(now)
	else:
		# En stagger: deja actuar el knockback horizontal, con roce leve.
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

	# Apagar hitbox si toca
	if _attack_end > 0.0 and now >= _attack_end:
		_set_hitbox_active(false)
		_attack_end = 0.0

	move_and_slide()


## Recibe daño desde enemigos/proyectiles. from_pos permite calcular la
## dirección del knockback (empuja al jugador alejándolo del atacante).
func take_damage(amount: int = 1, from_pos: Vector2 = Vector2.ZERO) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < invulnerable_until:
		return

	# Dirección del empujón: por defecto, en contra del facing.
	var push_dir: int = -facing
	if from_pos != Vector2.ZERO:
		push_dir = 1 if global_position.x >= from_pos.x else -1

	# Escudo: consume 1 carga y aplica knockback + inv breve.
	if shield_charges > 0:
		shield_charges -= 1
		shield_charges_changed.emit(shield_charges)
		_update_shield_aura()
		_apply_knockback(push_dir, 0.6)
		_flash(Color(0.4, 0.8, 1.0))
		invulnerable_until = now + 0.7
		return

	# Sin escudo: descuenta 1 hit del "colchón" antes de perder vida.
	_hits_left_this_life -= 1
	_apply_knockback(push_dir, 1.0)
	Audio.play("hurt")
	if _hits_left_this_life <= 0:
		GameState.lose_life()
		_hits_left_this_life = hits_per_life
		_flash(Color(1.0, 0.25, 0.25))
		invulnerable_until = now + 1.1
	else:
		_flash(Color(1.0, 0.6, 0.3))
		invulnerable_until = now + 0.8
	hits_before_life_changed.emit(_hits_left_this_life)

	if GameState.lives <= 0:
		_die()


func _apply_knockback(dir_x: int, strength: float) -> void:
	velocity.x = dir_x * knockback_x * strength
	velocity.y = knockback_y * strength
	_stagger_until = Time.get_ticks_msec() / 1000.0 + stagger_duration


func _die() -> void:
	GameState.lives = 3
	GameState.lives_changed.emit(GameState.lives)
	_hits_left_this_life = hits_per_life
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
	var connected := false
	for h in hits:
		var body = h.get("collider")
		if body and body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			connected = true
	if connected:
		Audio.play("hit")


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
	Audio.play_ui_switch()


func _select_power_by_slot(slot: int) -> void:
	if slot < 0 or slot >= GameState.backpack.size():
		return
	var new_power: int = GameState.backpack[slot]
	if new_power == active_power:
		return
	active_power = new_power
	active_power_changed.emit(active_power)
	Audio.play_ui_switch()


func _use_active_power() -> void:
	if active_power == -1:
		return
	match active_power:
		GameState.Power.SHIELD:
			shield_charges += 1
			shield_charges_changed.emit(shield_charges)
			_update_shield_aura()
			_flash(Color(0.4, 0.8, 1.0))
			Audio.play_ui_switch()
		GameState.Power.EMP:
			_emit_emp()
			Audio.play_ui_switch()
		GameState.Power.VISION:
			_reveal_hidden()
			Audio.play_ui_switch()


func _update_shield_aura() -> void:
	if shield_aura:
		shield_aura.visible = shield_charges > 0


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
	Audio.play_pickup()
	if active_power == -1:
		active_power = power_id
		active_power_changed.emit(active_power)
