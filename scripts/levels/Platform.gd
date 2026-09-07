extends StaticBody2D
## Plataforma de tamaño configurable.
##
## Si `is_hidden` está activo, la plataforma nace invisible y sin colisión, y
## sólo aparece unos segundos cuando el jugador usa el poder de Visión.
## Player._reveal_hidden() recorre el grupo "hidden" y llama a reveal().

@export var size: Vector2 = Vector2(96, 12)
@export var color: Color = Color(0.3, 0.32, 0.38)
## Plataforma que sólo se revela con el poder de Visión.
@export var is_hidden: bool = false
## Color del contorno tenue que insinúa una plataforma oculta.
@export var ghost_color: Color = Color(0.55, 0.85, 1.0, 0.10)

var _revealed_until: float = 0.0

@onready var _shape: CollisionShape2D = CollisionShape2D.new()
@onready var _rect: ColorRect = ColorRect.new()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	_shape.shape = rect_shape
	add_child(_shape)

	_rect.position = -size * 0.5
	_rect.size = size
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	if is_hidden:
		add_to_group("hidden")
		_set_solid(false)
	else:
		_rect.color = color


func _process(_delta: float) -> void:
	if not is_hidden or _revealed_until == 0.0:
		return
	if Time.get_ticks_msec() / 1000.0 >= _revealed_until:
		_revealed_until = 0.0
		_set_solid(false)


## Llamado por el poder de Visión. La plataforma se vuelve sólida y visible
## durante `duration` segundos.
func reveal(duration: float = 3.0) -> void:
	if not is_hidden:
		return
	_revealed_until = Time.get_ticks_msec() / 1000.0 + duration
	_set_solid(true)


func _set_solid(on: bool) -> void:
	_shape.disabled = not on
	# Aunque esté "oculta" se deja un fantasma muy tenue: el niño intuye que
	# ahí hay algo y aprende a usar la Visión sin que se lo digan.
	_rect.color = color if on else ghost_color
