extends Node2D
## Escena de arranque. No dibuja el juego: sólo pide al LevelManager que
## cargue la pantalla donde se quedó el jugador (o la 1 si empieza de cero).
## Existe para que el punto de entrada del proyecto no dependa de qué
## pantalla sea la primera.


func _ready() -> void:
	# Un frame de margen para que los autoloads terminen su _ready
	# (GameState carga la partida guardada ahí).
	await get_tree().process_frame
	LevelManager.start_or_resume()
