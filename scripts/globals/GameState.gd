extends Node
## Estado global del juego: mochila de poderes, puntos y progreso.
## Se guarda en user:// para persistencia entre sesiones.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

# --- Catálogo de poderes ---------------------------------------------------
# id: entero corto (para códigos compactos)
# name / desc: mostrar al jugador
# level: nivel donde se obtiene
enum Power { VISION = 1, SHIELD = 2, EMP = 3 }

const POWER_INFO := {
	Power.VISION: {"name": "Visión", "desc": "Revela plataformas y botones ocultos.", "level": 1},
	Power.SHIELD: {"name": "Escudo", "desc": "Bloquea el próximo golpe recibido.", "level": 1},
	Power.EMP:    {"name": "Pulso EMP", "desc": "Aturde a los enemigos cercanos 2 segundos.", "level": 1},
}

# --- Estado en memoria -----------------------------------------------------
var player_name: String = ""
var score: int = 0
var lives: int = 3
var backpack: Array[int] = []            # poderes recolectados por mí
var gifts: Array[Dictionary] = []        # [{from: "A", power: 1}, ...]
var levels_completed: Array[int] = []

signal power_collected(power_id: int)
signal gift_received(from_name: String, power_id: int)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)


func _ready() -> void:
	load_game()


# --- API mochila -----------------------------------------------------------
func add_power(power_id: int) -> void:
	if power_id not in backpack:
		backpack.append(power_id)
	power_collected.emit(power_id)
	save_game()


func has_power(power_id: int) -> bool:
	return power_id in backpack


func add_gift(from_name: String, power_id: int) -> void:
	gifts.append({"from": from_name, "power": power_id})
	gift_received.emit(from_name, power_id)
	save_game()


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func lose_life() -> void:
	lives = max(0, lives - 1)
	lives_changed.emit(lives)


func reset_run() -> void:
	score = 0
	lives = 3
	backpack.clear()


# --- Persistencia ----------------------------------------------------------
func save_game() -> void:
	var data := {
		"v": SAVE_VERSION,
		"player_name": player_name,
		"score": score,
		"backpack": backpack,
		"gifts": gifts,
		"levels_completed": levels_completed,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	player_name = parsed.get("player_name", "")
	score = int(parsed.get("score", 0))
	var bp: Array = parsed.get("backpack", [])
	backpack.clear()
	for p in bp:
		backpack.append(int(p))
	var raw_gifts: Array = parsed.get("gifts", [])
	gifts.clear()
	for g in raw_gifts:
		if typeof(g) == TYPE_DICTIONARY:
			gifts.append(g)
	var raw_lvls: Array = parsed.get("levels_completed", [])
	levels_completed.clear()
	for l in raw_lvls:
		levels_completed.append(int(l))
