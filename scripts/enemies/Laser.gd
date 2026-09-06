extends Area2D
## Proyectil láser disparado por la Torreta. Viaja recto, daña al jugador
## al impactar. Se destruye al chocar con el jugador o con paredes/suelo
## después de recorrer un máximo de life_distance.

@export var speed: float = 260.0
@export var damage: int = 1
@export var life_distance: float = 900.0

var direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	position += step
	_traveled += step.length()
	if _traveled >= life_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		queue_free()
	elif body.is_in_group("world"):
		queue_free()
