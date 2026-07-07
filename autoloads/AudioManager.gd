extends Node

const _SfxGen = preload("res://game_logic/SfxGen.gd")

# Ambient sound paths per biome (index matches IsoConst biome IDs / InfiniteWorldGen biomes).
# Placeholder paths: gracefully skipped if the file doesn't exist.
const AMBIENCE_PATHS: Array[String] = [
	"res://assets/audio/ambience/grasslands.ogg",  # 0 Grasslands
	"res://assets/audio/ambience/forest.ogg",      # 1 Forest
	"res://assets/audio/ambience/desert.ogg",      # 2 Desert
	"res://assets/audio/ambience/scorched.ogg",    # 3 Scorched
	"res://assets/audio/ambience/mountains.ogg",   # 4 Mountains
]
const AMBIENCE_CROSSFADE: float = 2.0

# Map from SFX name → file path
const SFX_PATHS: Dictionary = {
	"card_draw":    "res://assets/audio/sfx/card_draw.wav",
	"card_play":    "res://assets/audio/sfx/card_play.wav",
	"spell_resolve": "res://assets/audio/sfx/spell_resolve.wav",
	"attack":       "res://assets/audio/sfx/attack.wav",
	"battle_win":   "res://assets/audio/sfx/battle_win.wav",
	"battle_lose":  "res://assets/audio/sfx/battle_lose.wav",
	"enemy_engage": "res://assets/audio/sfx/enemy_engage.wav",
	"enemy_alert":  "res://assets/audio/sfx/enemy_alert.wav",
	"chest_open":   "res://assets/audio/sfx/chest_open.wav",
	"scroll_pickup": "res://assets/audio/sfx/scroll_pickup.wav",
	"door_enter":   "res://assets/audio/sfx/door_enter.wav",
	"footstep":       "res://assets/audio/sfx/footstep.wav",
	"nightfall_ambient": "res://assets/audio/sfx/nightfall.wav",
	"ui_click":     "res://assets/audio/sfx/ui_click.wav",
	"land":         "res://assets/audio/sfx/land.wav",
	"dig_success":  "res://assets/audio/sfx/dig_success.wav",
	"waystone_travel": "res://assets/audio/sfx/waystone_travel.wav",
}

var _players: Array[AudioStreamPlayer] = []
const _POOL_SIZE: int = 8
var _sfx_cache: Dictionary = {}

var _narration_player: AudioStreamPlayer
var _narration_suppressed: bool = false

var _music_player: AudioStreamPlayer
var _current_music_path: String = ""

# Ambience: two players crossfade between them
var _amb_players: Array[AudioStreamPlayer] = []
var _amb_active: int = 0   # which player is currently fading in
var _amb_biome: int = -1   # currently playing biome id (-1 = none)

func _ready() -> void:
	for key: String in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_sfx_cache[key] = stream
	# Any key without a real file asset falls back to a procedurally
	# synthesized sound (game_logic/SfxGen.gd) — see CLAUDE.md "Android:
	# Always preload()" and TID-425: no external audio assets required.
	for key: String in _SfxGen.all_keys():
		if not _sfx_cache.has(key):
			_sfx_cache[key] = _SfxGen.get_sfx(key)
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
	# Ambience crossfade pair
	for _i in 2:
		var ap := AudioStreamPlayer.new()
		ap.volume_db = linear_to_db(0.0001)  # effectively silent
		add_child(ap)
		_amb_players.append(ap)
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

func _process(_delta: float) -> void:
	# Loop the active ambience player when it finishes
	if _amb_biome >= 0 and _amb_biome < AMBIENCE_PATHS.size():
		var p: AudioStreamPlayer = _amb_players[_amb_active]
		if p.stream != null and not p.playing:
			p.play()

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

## Switch biome ambience with a crossfade. biome_id=-1 fades out without starting a new loop.
func set_ambience(biome_id: int) -> void:
	if biome_id == _amb_biome:
		return
	_amb_biome = biome_id
	var old_idx: int = _amb_active
	var new_idx: int = 1 - _amb_active
	_amb_active = new_idx
	# Fade out old player
	var old_p: AudioStreamPlayer = _amb_players[old_idx]
	var new_p: AudioStreamPlayer = _amb_players[new_idx]
	var sfx_vol: float = get_sfx_volume()
	if old_p.playing:
		var tw_out: Tween = create_tween()
		tw_out.tween_property(old_p, "volume_db", linear_to_db(0.0001), AMBIENCE_CROSSFADE)
		tw_out.finished.connect(func() -> void: old_p.stop())
	if biome_id < 0 or biome_id >= AMBIENCE_PATHS.size():
		return
	var path: String = AMBIENCE_PATHS[biome_id]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		stream = _SfxGen.get_ambience(biome_id)
	new_p.stream = stream
	new_p.volume_db = linear_to_db(0.0001)
	new_p.play()
	var tw_in: Tween = create_tween()
	tw_in.tween_property(new_p, "volume_db", linear_to_db(sfx_vol * 0.4), AMBIENCE_CROSSFADE)
