extends Enemy
## Robot-Sirena: patrulla lento, pero al detectar al jugador embiste a
## alta velocidad. HP 2, suelta Pulso EMP. El EMP lo aturde 2s
## (tratamiento estándar de Enemy.stun).

@export var patrol_speed: float = 30.0
@export var charge_speed: float = 140.0
@export var detection_range: float = 180.0
@export var patrol_range: float = 100.0

var _origin_x: float = 0.0
var _dir: int = 1


func _ready() -> void:
	super._ready()
	_origin_x = global_position.x
	if power_drop == -1:
		power_drop = GameState.Power.EMP
	max_hp = 2
	hp = max_hp


func _ai_tick(_delta: float) -> void:
	var player := _get_player()
	if player and global_position.distance_to(player.global_position) <= detection_range:
		# Embestida: hacia el jugador a full velocidad.
		_dir = 1 if player.global_position.x >= global_position.x else -1
		velocity.x = _dir * charge_speed
	else:
		# Patrulla: dentro del rango, invierte al llegar al límite.
		var dx := global_position.x - _origin_x
		if dx > patrol_range and _dir > 0:
			_dir = -1
		elif dx < -patrol_range and _dir < 0:
			_dir = 1
		if is_on_wall() and is_on_floor():
			_dir = -_dir
		velocity.x = _dir * patrol_speed


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
