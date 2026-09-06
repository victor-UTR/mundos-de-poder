extends Enemy
## Robot-Torreta: estático, dispara láser horizontal cada fire_interval
## segundos hacia el lado donde esté el jugador. HP 3, suelta Escudo.

@export var fire_interval: float = 1.8
@export var detection_range: float = 320.0
@export var laser_scene: PackedScene

var _fire_at: float = 0.0


func _ready() -> void:
	super._ready()
	if power_drop == -1:
		power_drop = GameState.Power.SHIELD
	max_hp = 3
	hp = max_hp
	_fire_at = Time.get_ticks_msec() / 1000.0 + fire_interval


func _ai_tick(_delta: float) -> void:
	# Estática: nunca se mueve horizontalmente.
	velocity.x = 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if now < _fire_at:
		return
	var player := _get_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > detection_range:
		return
	_shoot_at(player.global_position)
	_fire_at = now + fire_interval


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]


func _shoot_at(target: Vector2) -> void:
	if laser_scene == null:
		return
	var laser = laser_scene.instantiate()
	var dir := 1 if target.x >= global_position.x else -1
	laser.direction = Vector2(dir, 0)
	laser.global_position = global_position + Vector2(dir * 16, -2)
	get_parent().add_child(laser)
	Audio.play("laser")
	# Fogonazo del cañón: parpadeo blanco corto.
	_flash(Color(1, 1, 0.8))
