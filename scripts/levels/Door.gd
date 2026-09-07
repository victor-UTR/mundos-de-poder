extends Area2D
## Paso entre pantallas. Al tocarla, el jugador viaja a `target_screen` y
## aparece en el marcador `target_spawn` de esa pantalla.
##
## Convenio de marcadores: si la puerta lleva a la pantalla siguiente el
## destino es "from_left"; si retrocede, "from_right".

@export var target_screen: int = 2
@export var target_spawn: String = "from_left"
## Margen tras cargar la pantalla durante el que la puerta no responde.
## Evita rebotes cuando el jugador aparece cerca de una puerta.
@export var arm_delay: float = 0.45

var _armed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(arm_delay).timeout
	_armed = true


func _on_body_entered(body: Node) -> void:
	if not _armed:
		return
	if body.is_in_group("player"):
		LevelManager.go_to(target_screen, target_spawn)
