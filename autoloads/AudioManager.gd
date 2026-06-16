extends Node

# Map from SFX name → file path
const SFX_PATHS: Dictionary = {
	"card_draw":    "res://assets/audio/sfx/card_draw.wav",
	"card_play":    "res://assets/audio/sfx/card_play.wav",
	"spell_resolve": "res://assets/audio/sfx/spell_resolve.wav",
	"attack":       "res://assets/audio/sfx/attack.wav",
	"battle_win":   "res://assets/audio/sfx/battle_win.wav",
	"battle_lose":  "res://assets/audio/sfx/battle_lose.wav",
	"enemy_engage": "res://assets/audio/sfx/enemy_engage.wav",
	"chest_open":   "res://assets/audio/sfx/chest_open.wav",
	"scroll_pickup": "res://assets/audio/sfx/scroll_pickup.wav",
	"door_enter":   "res://assets/audio/sfx/door_enter.wav",
	"footstep":     "res://assets/audio/sfx/footstep.wav",
}

var _players: Array[AudioStreamPlayer] = []
const _POOL_SIZE: int = 8
var _sfx_cache: Dictionary = {}

var _narration_player: AudioStreamPlayer
var _narration_suppressed: bool = false

var _music_player: AudioStreamPlayer
var _current_music_path: String = ""

func _ready() -> void:
	for key: String in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_sfx_cache[key] = stream
	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_narration_player = AudioStreamPlayer.new()
	_narration_player.volume_db = -3.0
	add_child(_narration_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = linear_to_db(0.5)
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)
	GameBus.dialogue_state_changed.connect(_on_dialogue_state_changed)

func play_narration(scroll_id: String) -> void:
	if _narration_suppressed:
		return
	var scroll: Dictionary = ScrollRegistry.get_scroll(scroll_id)
	if scroll.is_empty():
		return
	var path: String = scroll.get("audio_path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_narration_player.stop()
	_narration_player.stream = stream
	_narration_player.play()

func stop_narration() -> void:
	_narration_player.stop()

func is_narration_playing() -> bool:
	return _narration_player.playing

func set_narration_suppressed(suppressed: bool) -> void:
	_narration_suppressed = suppressed
	if suppressed:
		_narration_player.stop()

func _on_dialogue_state_changed(active: bool) -> void:
	set_narration_suppressed(active)

func play_music(path: String) -> void:
	if path == _current_music_path and _music_player.playing:
		return
	_current_music_path = path
	if path.is_empty():
		_music_player.stop()
		return
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_current_music_path = ""
	_music_player.stop()

func _on_music_finished() -> void:
	if not _current_music_path.is_empty() and _music_player.stream != null:
		_music_player.play()

func set_music_volume(linear: float) -> void:
	_music_player.volume_db = linear_to_db(maxf(linear, 0.0001))

func get_music_volume() -> float:
	return db_to_linear(_music_player.volume_db)

func set_sfx_volume(linear: float) -> void:
	var db: float = linear_to_db(maxf(linear, 0.0001))
	for p: AudioStreamPlayer in _players:
		p.volume_db = db

func get_sfx_volume() -> float:
	if _players.is_empty():
		return 1.0
	return db_to_linear(_players[0].volume_db)

func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name, null) as AudioStream
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()
