extends Enemy
## Robot-Escáner: patrulla horizontalmente entre dos puntos.
## HP 2, lento. Suelta el poder Visión la primera vez que muere uno.

@export var patrol_range: float = 100.0

var _origin_x: float = 0.0
var _dir: int = 1


func _ready() -> void:
	super._ready()
	_origin_x = global_position.x
	if power_drop == -1:
		power_drop = GameState.Power.VISION
	max_hp = 2
	hp = max_hp


func _apply_palette() -> void:
	_tint("Sprite", Palette.ENEMY_SCANNER)
	_tint("Eye", Palette.ENEMY_SCANNER_EYE)
	_tint("Antenna", Palette.ENEMY_SCANNER)


func _ai_tick(_delta: float) -> void:
	var dx := global_position.x - _origin_x
	if dx > patrol_range and _dir > 0:
		_dir = -1
	elif dx < -patrol_range and _dir < 0:
		_dir = 1
	if is_on_wall() and is_on_floor():
		_dir = -_dir
	velocity.x = _dir * speed
