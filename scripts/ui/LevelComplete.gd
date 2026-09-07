extends CanvasLayer
## Pantalla de fin del Nivel 1. Muestra el código para compartir la mochila
## y permite copiarlo al portapapeles para mandarlo por WhatsApp.

@onready var code_label: Label = $Root/Panel/Box/Code
@onready var score_label: Label = $Root/Panel/Box/Score
@onready var copy_button: Button = $Root/Panel/Box/Buttons/Copy
@onready var again_button: Button = $Root/Panel/Box/Buttons/Again

var _code: String = ""


func _ready() -> void:
	layer = 50
	copy_button.pressed.connect(_on_copy)
	again_button.pressed.connect(_on_again)
	score_label.text = "Puntos: %d" % GameState.score
	copy_button.grab_focus()


func setup(code: String) -> void:
	_code = code
	if is_node_ready():
		code_label.text = code
	else:
		await ready
		code_label.text = code


func _on_copy() -> void:
	DisplayServer.clipboard_set(_code)
	copy_button.text = "¡Copiado!"


func _on_again() -> void:
	GameState.reset_run()
	GameState.save_game()
	LevelManager.go_to(1, "start")
	queue_free()
