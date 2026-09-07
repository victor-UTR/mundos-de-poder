extends Node
## Cerebro del puzzle final: escucha a los 3 servidores y, cuando los tres
## están apagados, da el Nivel 1 por completado y saca el código para
## compartir la mochila con un amigo.

const LEVEL := 1

@export var complete_scene: PackedScene

var _total: int = 0


func _ready() -> void:
	# Un frame para que todos los servidores hayan hecho su _ready y estén
	# ya en el grupo.
	await get_tree().process_frame
	var servers := get_tree().get_nodes_in_group("servers")
	_total = servers.size()
	for s in servers:
		if s.has_signal("disabled"):
			s.disabled.connect(_on_server_disabled)
	_report_progress()


func _on_server_disabled(_server: Node) -> void:
	if _remaining() > 0:
		_report_progress()
	else:
		_complete()


func _remaining() -> int:
	var left := 0
	for s in get_tree().get_nodes_in_group("servers"):
		if not s.is_off:
			left += 1
	return left


func _report_progress() -> void:
	var done := _total - _remaining()
	_say("Servidores apagados: %d/%d" % [done, _total])


func _complete() -> void:
	if not GameState.levels_completed.has(LEVEL):
		GameState.levels_completed.append(LEVEL)
		GameState.add_score(100)
	GameState.save_game()

	var who := GameState.player_name
	if who.strip_edges().is_empty():
		who = "Amigo"
	var code := ShareCode.encode(who, GameState.backpack)

	if complete_scene:
		var panel := complete_scene.instantiate()
		get_tree().current_scene.add_child(panel)
		if panel.has_method("setup"):
			panel.setup(code)
	else:
		_say("¡Datacenter apagado! Código: %s" % code)


func _say(msg: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message(msg)
