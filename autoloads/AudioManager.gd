extends Node

# Map from SFX name → file path
const SFX_PATHS: Dictionary = {
	"card_play":    "res://assets/audio/sfx/card_play.wav",
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

func _ready() -> void:
	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

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
