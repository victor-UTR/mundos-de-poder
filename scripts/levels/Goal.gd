extends Area2D
## Meta temporal del Nivel 1 (pantalla 5), a la espera del puzzle completo
## de los 3 servidores del Empire State.
##
## Comprueba que el jugador lleve los 3 poderes en la mochila. Si le falta
## alguno, se lo dice por nombre y le deja volver atrás a buscarlo.

const REQUIRED := [
	GameState.Power.VISION,
	GameState.Power.SHIELD,
	GameState.Power.EMP,
]

var _notified_at: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var missing := _missing_powers()
	if missing.is_empty():
		_complete()
	else:
		_warn(missing)


func _missing_powers() -> Array:
	var missing := []
	for p in REQUIRED:
		if not GameState.has_power(p):
			missing.append(GameState.POWER_INFO[p]["name"])
	return missing


func _complete() -> void:
	if GameState.levels_completed.has(1):
		_toast("Nivel 1 ya completado.")
		return
	GameState.levels_completed.append(1)
	GameState.add_score(100)
	GameState.save_game()
	_toast("¡Datacenter apagado! Nivel 1 completado.")


func _warn(missing: Array) -> void:
	# Evita repetir el aviso si el jugador se queda encima del área.
	var now := Time.get_ticks_msec() / 1000.0
	if now - _notified_at < 2.0:
		return
	_notified_at = now
	_toast("Te falta: %s" % ", ".join(missing))


func _toast(msg: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		var root := get_tree().current_scene
		if root:
			hud = root.get_node_or_null("HUD")
	if hud and hud.has_method("_toast"):
		hud._toast(msg)
