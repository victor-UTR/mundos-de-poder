extends StaticBody2D
## Plataforma de tamaño configurable.
##
## Si `is_hidden` está activo, la plataforma nace invisible y sin colisión, y
## sólo aparece unos segundos cuando el jugador usa el poder de Visión.
## Player._reveal_hidden() recorre el grupo "hidden" y llama a reveal().

@export var size: Vector2 = Vector2(96, 12)
## Déjalo transparente para usar el color de Palette. Sólo se rellena si una
## plataforma concreta necesita salirse de la paleta.
@export var color: Color = Color(0, 0, 0, 0)
## Plataforma que sólo se revela con el poder de Visión.
@export var is_hidden: bool = false
## Igual que `color`: transparente = usa Palette.
@export var ghost_color: Color = Color(0, 0, 0, 0)

## Grosor del filo superior. Da volumen y deja claro dónde se aterriza.
const EDGE_H := 2.0

var _revealed_until: float = 0.0

@onready var _shape: CollisionShape2D = CollisionShape2D.new()
@onready var _rect: ColorRect = ColorRect.new()
@onready var _edge: ColorRect = ColorRect.new()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	if color.a == 0.0:
		color = Palette.PLATFORM
	if ghost_color.a == 0.0:
		ghost_color = Palette.PLATFORM_GHOST

	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	_shape.shape = rect_shape
	add_child(_shape)

	_rect.position = -size * 0.5
	_rect.size = size
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	_edge.position = -size * 0.5
	_edge.size = Vector2(size.x, EDGE_H)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edge)

	if is_hidden:
		add_to_group("hidden")
		_set_solid(false)
	else:
		_rect.color = color
		_edge.color = Palette.PLATFORM_EDGE


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
	# Al revelarse se pinta con el cian de la Visión, no con el gris normal:
	# así queda claro que está ahí GRACIAS al poder, y no por casualidad.
	_rect.color = Palette.PLATFORM_REVEALED if on else ghost_color
	_edge.color = Palette.alpha(Palette.POWER_VISION, 0.75 if on else 0.0)
