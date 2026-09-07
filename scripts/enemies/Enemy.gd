extends CharacterBody2D
class_name Enemy
## Base de todos los enemigos del Nivel 1. Maneja HP, aturdimiento (EMP),
## muerte y drop del poder asociado. Los hijos sobreescriben _ai_tick para
## su comportamiento específico.

@export var max_hp: int = 2
@export var speed: float = 40.0
@export var gravity: float = 1100.0
@export var contact_damage: int = 1
## ID del poder (GameState.Power) que suelta la PRIMERA vez que muere un
## enemigo de este tipo en la partida. -1 = no suelta poder.
@export var power_drop: int = -1
## Puntos que suelta cuando ya no toca poder.
@export var score_value: int = 10

var hp: int = 0
var stun_until: float = 0.0
var is_dead: bool = false

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_apply_palette()


## Sobreescribir en subclases para pintarse desde Palette. Los colores del
## .tscn son sólo vista previa del editor; los de verdad se aplican aquí.
func _apply_palette() -> void:
	pass


## Pinta un ColorRect hijo si existe. Evita repetir el get_node_or_null +
## comprobación en los tres robots.
func _tint(node_path: String, c: Color) -> void:
	var n := get_node_or_null(node_path)
	if n is ColorRect:
		n.color = c


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Gravedad siempre.
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, 520.0)
	# IA sólo si no está aturdido.
	var now := Time.get_ticks_msec() / 1000.0
	if now >= stun_until:
		_ai_tick(delta)
	else:
		velocity.x = 0.0
	move_and_slide()
	_check_contact_damage()


## Sobreescribir en subclases para mover el enemigo (setea velocity.x).
func _ai_tick(_delta: float) -> void:
	velocity.x = 0.0


func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	hp -= amount
	_flash(Palette.FLASH_HURT)
	if hp <= 0:
		_die()


func stun(duration: float) -> void:
	stun_until = Time.get_ticks_msec() / 1000.0 + duration
	_flash(Palette.FLASH_STUN)


func _die() -> void:
	is_dead = true
	Audio.play("enemy_death")
	# Drop de poder si toca, si no puntos.
	if power_drop != -1 and not GameState.has_power(power_drop):
		GameState.add_power(power_drop)
	else:
		GameState.add_score(score_value)
	queue_free()


func _check_contact_damage() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(contact_damage, global_position)


func _flash(c: Color) -> void:
	if sprite:
		var original := sprite.color
		sprite.color = c
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.color = original
