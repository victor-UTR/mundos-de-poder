extends Node
## Prueba de humo del Nivel 1. Se ejecuta en headless:
##
##   godot --headless --path . res://tests/SmokeTest.tscn
##
## Monta cada pantalla en el árbol y comprueba lo que el editor no avisa:
## que el suelo se genera, que el Player aterriza en un marcador válido y,
## sobre todo, que cada puerta apunta a un marcador que existe de verdad en
## la pantalla destino (un typo ahí deja al jugador tirado en el vacío).

var failures: Array[String] = []
var checks: int = 0


func _ready() -> void:
	await get_tree().process_frame

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

	_report()


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
		_ok(not spawn_names.is_empty(), "Pantalla %d: Spawns vacío" % idx)

	# El suelo lo genera LevelScreen.gd en tiempo de ejecución.
	var ground := screen.get_node_or_null("Ground")
	if ground == null:
		_fail("Pantalla %d: no se generó el suelo" % idx)
	else:
		var shapes := 0
		for c in ground.get_children():
			if c is CollisionShape2D:
				shapes += 1
		_ok(shapes > 0, "Pantalla %d: el suelo no tiene colisión" % idx)
		# N huecos interiores parten el suelo en N+1 tramos. Si esto falla,
		# los pozos se han rellenado y el puzzle de Visión sería trivial.
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
			"Pantalla %d: el Player se quedó en (0,0)" % idx)
		_ok(player.global_position.y < screen.FALL_LIMIT,
			"Pantalla %d: el Player aparece por debajo del límite de caída" % idx)

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
