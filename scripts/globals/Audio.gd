extends Node
## Sistema de audio global del juego.
## - beeps procedurales para UI (cambio de poder, recoger)
## - pool de AudioStreamPlayer para efectos con assets .ogg
##
## Volúmenes por sonido definidos en SFX_VOLUMES (dB).
## Master del juego -6 dB via AudioServer bus.

const MASTER_DB := -6.0
const SFX_VOLUMES := {
	"hit": -8.0,
	"hurt": -6.0,
	"laser": -10.0,
	"enemy_death": -8.0,
}
const SFX_PATHS := {
	"hit": "res://assets/audio/hit.ogg",
	"hurt": "res://assets/audio/hurt.ogg",
	"laser": "res://assets/audio/laser.ogg",
	"enemy_death": "res://assets/audio/enemy_death.ogg",
}

# --- Pool de players para SFX ---------------------------------------------
const POOL_SIZE := 6
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var _streams: Dictionary = {}   # name -> AudioStream

# --- Generador procedural para bips UI ------------------------------------
var _beep_player: AudioStreamPlayer
var _beep_gen: AudioStreamGenerator
var _beep_playback: AudioStreamGeneratorPlayback
const BEEP_SAMPLE_RATE := 22050.0
const BEEP_UI_DB := -14.0


func _ready() -> void:
	# Master bus a -6 dB.
	AudioServer.set_bus_volume_db(0, MASTER_DB)

	# Cargar streams de assets (si existen).
	for name in SFX_PATHS.keys():
		var path: String = SFX_PATHS[name]
		if ResourceLoader.exists(path):
			_streams[name] = load(path)
		else:
			push_warning("Audio: falta asset '%s' en %s" % [name, path])

	# Crear pool de players para SFX.
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	# Setup del generador procedural para bips.
	_beep_player = AudioStreamPlayer.new()
	_beep_gen = AudioStreamGenerator.new()
	_beep_gen.mix_rate = BEEP_SAMPLE_RATE
	_beep_gen.buffer_length = 0.25
	_beep_player.stream = _beep_gen
	_beep_player.volume_db = BEEP_UI_DB
	add_child(_beep_player)


# --- API pública ----------------------------------------------------------
func play(name: String, extra_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = _streams[name]
	p.volume_db = SFX_VOLUMES.get(name, 0.0) + extra_db
	p.play()


func play_ui_switch() -> void:
	beep(880.0, 0.06)


func play_pickup() -> void:
	beep(523.0, 0.08)
	# Segundo tono ligeramente después.
	await get_tree().create_timer(0.08).timeout
	beep(784.0, 0.10)


## Genera y reproduce un tono cuadrado con envelope attack/release corto.
func beep(freq: float, duration_s: float, volume_db: float = BEEP_UI_DB) -> void:
	if not _beep_player.playing:
		_beep_player.play()
	_beep_playback = _beep_player.get_stream_playback()
	if _beep_playback == null:
		return
	_beep_player.volume_db = volume_db
	var sr: float = BEEP_SAMPLE_RATE
	var total_frames: int = int(duration_s * sr)
	var attack_frames: int = int(0.005 * sr)
	var release_frames: int = int(0.030 * sr)
	var sustain_frames: int = int(max(0, total_frames - attack_frames - release_frames))
	var period_frames: float = max(1.0, sr / freq)
	var half_period: float = period_frames * 0.5

	var frames_to_push: int = int(min(_beep_playback.get_frames_available(), total_frames))
	var i: int = 0
	var t: int = 0
	while i < frames_to_push:
		# Onda cuadrada.
		var phase: float = fposmod(float(t), period_frames)
		var v: float = 0.5 if phase < half_period else -0.5
		# Envelope.
		var env: float = 1.0
		if t < attack_frames:
			env = float(t) / float(max(1, attack_frames))
		elif t >= attack_frames + sustain_frames:
			var rel_t: int = t - attack_frames - sustain_frames
			env = 1.0 - float(rel_t) / float(max(1, release_frames))
			env = clamp(env, 0.0, 1.0)
		var sample: float = v * env
		_beep_playback.push_frame(Vector2(sample, sample))
		i += 1
		t += 1
