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

	# 3) Cada robot suelta el poder que le toca y se le puede pegar.
	await _check_enemy_drops()

	# 4) La vista de mochila lista los 3 poderes y pausa el juego.
	await _check_inventory()

	# 5) El puzzle final se puede resolver (y sólo usando los poderes).
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


## Cada robot debe soltar su poder al morir y debe ser alcanzable con el
## ataque cuerpo a cuerpo. Si un solo robot falla aquí, su poder se vuelve
## inconseguible y el puzzle final queda bloqueado.
func _check_enemy_drops() -> void:
	var cases := [
		{"path": "res://scenes/enemies/RobotEscaner.tscn", "power": GameState.Power.VISION},
		{"path": "res://scenes/enemies/RobotTorreta.tscn", "power": GameState.Power.SHIELD},
		{"path": "res://scenes/enemies/RobotSirena.tscn", "power": GameState.Power.EMP},
	]

	var packed: PackedScene = load("res://scenes/levels/Screen1.tscn")
	LevelManager.pending_spawn = "start"
	var screen: Node = packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var player := screen.get_node_or_null("Player")

	for c in cases:
		var scene: PackedScene = load(c["path"])
		if scene == null:
			_fail("No se pudo cargar %s" % c["path"])
			continue
		var expected: int = c["power"]
		var power_label: String = GameState.power_name(expected)

		# a) ¿Está configurado para soltar el poder correcto?
		var probe = scene.instantiate()
		screen.add_child(probe)
		await get_tree().process_frame
		# El nombre hay que guardarlo ya: al morir el robot se libera y
		# leerlo después revienta con "previously freed".
		var robot_name: String = probe.name
		_ok(probe.power_drop == expected,
			"%s: power_drop es %d, deberia ser %d (%s)" % [
				robot_name, probe.power_drop, expected, power_label])

		# b) ¿El ataque del jugador le alcanza? El cuerpo tarda un número
		# indeterminado de frames en registrarse en el espacio de físicas
		# (en el runner de CI no es el mismo que en local), así que se
		# reintenta en vez de fijar una espera concreta.
		var hp_before: int = probe.hp
		var connected := false
		for _attempt in 5:
			probe.global_position = player.global_position + Vector2(12, 0)
			probe.velocity = Vector2.ZERO
			await get_tree().physics_frame
			player._start_attack(Time.get_ticks_msec() / 1000.0)
			await get_tree().physics_frame
			if probe.hp < hp_before:
				connected = true
				break
		_ok(connected,
			"%s: el ataque cuerpo a cuerpo no le hace daño (hp %d)" % [
				robot_name, probe.hp])

		# c) ¿Al morir entrega el poder?
		GameState.backpack.clear()
		probe.take_damage(99)
		await get_tree().process_frame
		_ok(GameState.has_power(expected),
			"%s: al morir no entregó %s (mochila: %s)" % [
				robot_name, power_label, str(GameState.backpack)])

	remove_child(screen)
	screen.queue_free()


## La mochila debe listar los 3 poderes (tengas o no cada uno) y congelar
## el juego mientras está abierta.
func _check_inventory() -> void:
	var packed: PackedScene = load("res://scenes/levels/Screen1.tscn")
	LevelManager.pending_spawn = "start"
	var screen: Node = packed.instantiate()
	add_child(screen)
	await get_tree().process_frame

	var inv := screen.get_node_or_null("HUD/Root/Inventory")
	if inv == null:
		_fail("El HUD no incluye la vista de mochila")
		remove_child(screen)
		screen.queue_free()
		return

	GameState.backpack.clear()
	GameState.add_power(GameState.Power.VISION)
	inv.open()
	await get_tree().process_frame
	_ok(inv.list.get_child_count() == 3,
		"La mochila muestra %d poderes, deberia mostrar los 3 del catálogo"
			% inv.list.get_child_count())
	_ok(get_tree().paused, "Abrir la mochila no pausó el juego")
	inv.close()
	_ok(not get_tree().paused, "Cerrar la mochila no reanudó el juego")

	remove_child(screen)
	screen.queue_free()


## Monta el Empire State y comprueba que cada servidor exige de verdad que
## se use su poder: primero intenta apagarlo sin usarlo (debe negarse) y
## después cumpliendo la condición (debe apagarse).
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
			"%s se apagó sin usar el poder (debería exigirlo)" % s.title)

	# Ahora cumpliendo la condición de cada uno.
	for s in servers:
		match s.required_power:
			GameState.Power.VISION:
				s.reveal(6.0)
			GameState.Power.EMP:
				s.stun(2.0)
			GameState.Power.SHIELD:
				player.shield_charges = 1
		s._try_disable(Time.get_ticks_msec() / 1000.0)
		_ok(s.is_off, "%s no se apagó pese a cumplir su condición" % s.title)

	await get_tree().process_frame
	_ok(GameState.levels_completed.has(1),
		"Apagados los 3 servidores, el Nivel 1 no quedó marcado como completado")

	# Ida y vuelta del código, con acentos en el nombre para asegurar que el
	# UTF-8 sobrevive al base64.
	var code := ShareCode.encode("Martín", GameState.backpack)
	var decoded := ShareCode.decode(code)
	_ok(decoded.get("ok", false),
		"El código de compartir no se pudo decodificar: %s" % code)
	_ok(String(decoded.get("from", "")) == "Martín",
		"El código no conserva el nombre: '%s'" % decoded.get("from", ""))
	_ok(decoded.get("powers", []).size() == 3,
		"El código no conserva los 3 poderes")
	var gift: int = ShareCode.pick_gift(decoded)
	_ok(gift in GameState.backpack,
		"El regalo sorteado (%d) no está en la mochila del emisor" % gift)

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
