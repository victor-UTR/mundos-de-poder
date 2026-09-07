extends Node
## Prueba de humo del Nivel 1. Se ejecuta en headless:
##
##   godot --headless --path . res://tests/SmokeTest.tscn
##
## Monta cada pantalla en el Ã¡rbol y comprueba lo que el editor no avisa:
## que el suelo se genera, que el Player aterriza en un marcador vÃ¡lido y,
## sobre todo, que cada puerta apunta a un marcador que existe de verdad en
## la pantalla destino (un typo ahÃ­ deja al jugador tirado en el vacÃ­o).

var failures: Array[String] = []
var checks: int = 0

## El test escribe en GameState (poderes, puntos, nivel completado) y eso
## persiste en user://savegame.json. Se guarda una copia al empezar y se
## restaura al terminar para no destruir la partida de quien lo ejecute.
var _save_backup: String = ""
var _had_save: bool = false


func _ready() -> void:
	await get_tree().process_frame
	_backup_save()

	# 1) Todas las pantallas cargan e informan de sus marcadores.
	var spawns_by_screen := {}
	for i in LevelManager.SCREENS.size():
		var idx := i + 1
		var spawn_names := await _check_screen(idx, LevelManager.SCREENS[i])
		spawns_by_screen[idx] = spawn_names

	# 2) Las puertas apuntan a destinos que existen.
	for i in LevelManager.SCREENS.size():
		var idx := i + 1
		await _check_doors(idx, LevelManager.SCREENS[i], spawns_by_screen)

	# 3) El puzzle final se puede resolver (y sÃ³lo usando los poderes).
	await _check_puzzle()

	# Deja que se procesen los queue_free() pendientes antes de salir; si no,
	# Godot avisa de instancias filtradas y de corrutinas del Player
	# reanudadas sobre objetos ya liberados.
	await get_tree().process_frame
	await get_tree().process_frame

	_restore_save()
	_report()


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	if _had_save:
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
		if f:
			_save_backup = f.get_as_text()
			f.close()


func _restore_save() -> void:
	if _had_save:
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(_save_backup)
			f.close()
	elif FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(GameState.SAVE_PATH)


## Monta el Empire State y comprueba que cada servidor exige de verdad que
## se use su poder: primero intenta apagarlo sin usarlo (debe negarse) y
## despuÃ©s cumpliendo la condiciÃ³n (debe apagarse).
func _check_puzzle() -> void:
	var packed: PackedScene = load("res://scenes/levels/Screen5.tscn")
	if packed == null:
		_fail("No se pudo cargar la pantalla 5")
		return
	LevelManager.pending_spawn = "from_left"
	var screen: Node = packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := screen.get_node_or_null("Player")
	var servers := get_tree().get_nodes_in_group("servers")
	_ok(servers.size() == 3, "El Empire State tiene %d servidores, esperaba 3" % servers.size())

	# Con la mochila completa, pero sin usar los poderes, nada debe ceder.
	GameState.backpack = [1, 2, 3]
	var now := Time.get_ticks_msec() / 1000.0
	for s in servers:
		s._player = player
		s._try_disable(now)
		_ok(not s.is_off,
			"%s se apagÃ³ sin usar el poder (deberÃ­a exigirlo)" % s.title)

	# Ahora cumpliendo la condiciÃ³n de cada uno.
	for s in servers:
		match s.required_power:
			GameState.Power.VISION:
				s.reveal(6.0)
			GameState.Power.EMP:
				s.stun(2.0)
			GameState.Power.SHIELD:
				player.shield_charges = 1
		s._try_disable(Time.get_ticks_msec() / 1000.0)
		_ok(s.is_off, "%s no se apagÃ³ pese a cumplir su condiciÃ³n" % s.title)

	await get_tree().process_frame
	_ok(GameState.levels_completed.has(1),
		"Apagados los 3 servidores, el Nivel 1 no quedÃ³ marcado como completado")

	# Ida y vuelta del cÃ³digo, con acentos en el nombre para asegurar que el
	# UTF-8 sobrevive al base64.
	var code := ShareCode.encode("MartÃ­n", GameState.backpack)
	var decoded := ShareCode.decode(code)
	_ok(decoded.get("ok", false),
		"El cÃ³digo de compartir no se pudo decodificar: %s" % code)
	_ok(String(decoded.get("from", "")) == "MartÃ­n",
		"El cÃ³digo no conserva el nombre: '%s'" % decoded.get("from", ""))
	_ok(decoded.get("powers", []).size() == 3,
		"El cÃ³digo no conserva los 3 poderes")
	var gift: int = ShareCode.pick_gift(decoded)
	_ok(gift in GameState.backpack,
		"El regalo sorteado (%d) no estÃ¡ en la mochila del emisor" % gift)

	remove_child(screen)
	screen.queue_free()


func _check_screen(idx: int, path: String) -> Array:
	var packed: PackedScene = load(path)
	if packed == null:
		_fail("Pantalla %d: no se pudo cargar %s" % [idx, path])
		return []

	LevelManager.pending_spawn = "start" if idx == 1 else "from_left"
	var screen: Node = packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var spawn_names: Array = []
	var spawns := screen.get_node_or_null("Spawns")
	if spawns == null:
		_fail("Pantalla %d: falta el nodo Spawns" % idx)
	else:
		for c in spawns.get_children():
			if c is Marker2D:
				spawn_names.append(c.name)
		_ok(not spawn_names.is_empty(), "Pantalla %d: Spawns vacÃ­o" % idx)

	# El suelo lo genera LevelScreen.gd en tiempo de ejecuciÃ³n.
	var ground := screen.get_node_or_null("Ground")
	if ground == null:
		_fail("Pantalla %d: no se generÃ³ el suelo" % idx)
	else:
		var shapes := 0
		for c in ground.get_children():
			if c is CollisionShape2D:
				shapes += 1
		_ok(shapes > 0, "Pantalla %d: el suelo no tiene colisiÃ³n" % idx)
		# N huecos interiores parten el suelo en N+1 tramos. Si esto falla,
		# los pozos se han rellenado y el puzzle de VisiÃ³n serÃ­a trivial.
		var expected: int = screen.gaps.size() + 1
		_ok(shapes == expected,
			"Pantalla %d: el suelo tiene %d tramos, se esperaban %d (%d hueco/s)"
				% [idx, shapes, expected, screen.gaps.size()])

	# El jugador debe haber sido colocado sobre un marcador, no en (0,0).
	var player := screen.get_node_or_null("Player")
	if player == null:
		_fail("Pantalla %d: falta el Player" % idx)
	else:
		_ok(player.global_position != Vector2.ZERO,
			"Pantalla %d: el Player se quedÃ³ en (0,0)" % idx)
		_ok(player.global_position.y < screen.FALL_LIMIT,
			"Pantalla %d: el Player aparece por debajo del lÃ­mite de caÃ­da" % idx)

	remove_child(screen)
	screen.queue_free()
	return spawn_names


func _check_doors(idx: int, path: String, spawns_by_screen: Dictionary) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		return
	LevelManager.pending_spawn = "from_left"
	var screen: Node = packed.instantiate()
	add_child(screen)
	await get_tree().process_frame

	for child in screen.get_children():
		if not (child is Area2D and "target_screen" in child):
			continue
		var target: int = child.target_screen
		var spawn: String = child.target_spawn
		if not _ok(target >= 1 and target <= LevelManager.SCREENS.size(),
				"Pantalla %d, puerta %s: destino %d fuera de rango" % [idx, child.name, target]):
			continue
		var valid: Array = spawns_by_screen.get(target, [])
		_ok(spawn in valid,
			"Pantalla %d, puerta %s: el marcador '%s' no existe en la pantalla %d (tiene: %s)"
				% [idx, child.name, spawn, target, ", ".join(valid)])

	remove_child(screen)
	screen.queue_free()


func _ok(condition: bool, msg: String) -> bool:
	checks += 1
	if not condition:
		failures.append(msg)
	return condition


func _fail(msg: String) -> void:
	checks += 1
	failures.append(msg)


func _report() -> void:
	print("--- SmokeTest Nivel 1 ---")
	print("Comprobaciones: %d" % checks)
	if failures.is_empty():
		print("RESULTADO: OK")
		get_tree().quit(0)
	else:
		for f in failures:
			print("FALLO: %s" % f)
		print("RESULTADO: %d fallo(s)" % failures.size())
		get_tree().quit(1)
