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

var _narration_player: AudioStreamPlayer
var _narration_suppressed: bool = false

func _ready() -> void:
	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_narration_player = AudioStreamPlayer.new()
	_narration_player.volume_db = -3.0
	add_child(_narration_player)
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

func play_sfx(sfx_name: String) -> void:
	if not SFX_PATHS.has(sfx_name):
		return
	var path: String = SFX_PATHS[sfx_name]
	if not ResourceLoader.exists(path):
		return  # graceful no-op — file not yet added
	var stream := load(path) as AudioStream
	if stream == null:
		return
	# Find a free player
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	# All busy — use player 0 (oldest sound cut off)
	_players[0].stream = stream
	_players[0].play()
