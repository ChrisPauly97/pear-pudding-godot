extends Node

signal coins_changed(new_amount: int)

const SAVE_PATH := "user://save.json"

# Currency
var coins: int = 0

# All cards ever acquired (the collection)
var owned_cards: Array[String] = []

# Cards currently in the active battle deck (curated subset of owned_cards)
var player_deck: Array[String] = []

# Current world position
var current_map: String = ""
var player_x: float = 0.0
var player_z: float = 0.0

# Map navigation stack (mirrors SceneManager stacks)
var map_stack: Array[String] = []
var door_stack: Array[String] = []

# Defeated / opened state
var defeated_enemies: Array[String] = []
var opened_chests: Array[String] = []

# Battle state: set when a fight starts, cleared on win/lose
var pending_battle_enemy_data: Dictionary = {}
var in_battle_enemy_id: String = ""

# Day/night cycle position (0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset)
var time_of_day: float = 0.4

# Enemy respawn day tracking
var days_elapsed: int = 0
var last_respawn_day: int = 0

# Story progression flags
var story_flags: Dictionary = {}

# World generation — set when starting a new game from the biome selection screen
var world_seed: int = 42
var starting_biome: int = 0   # BiomeDef.GRASSLANDS

var _loaded: bool = false
var _dirty: bool = false
const SAVE_INTERVAL: float = 2.0  # batch disk writes at most every 2 seconds

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = SAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_flush_if_dirty)
	add_child(timer)

func _flush_if_dirty() -> void:
	if _dirty and _loaded:
		_dirty = false
		save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_flush_if_dirty()

# -------------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	var starter: Array[String] = [
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
	]
	owned_cards.assign(starter)
	player_deck.assign(starter)
	coins = 0
	current_map = "main"
	player_x = 0.0
	player_z = 0.0
	map_stack = []
	door_stack = []
	defeated_enemies = []
	opened_chests = []
	pending_battle_enemy_data = {}
	in_battle_enemy_id = ""
	time_of_day = 0.4
	story_flags = {}
	days_elapsed = 0
	last_respawn_day = 0
	# world_seed and starting_biome are set by SceneManager.start_new_game_with_biome
	# before new_game() is called, so do not reset them here.
	_loaded = true
	save()

const CURRENT_SAVE_VERSION: int = 4

# Migration table: each entry is called in order when the save version is older.
# _migrate_v0_to_v1: old saves had only "player_deck"; backfill "owned_cards".
static func _migrate_v0_to_v1(data: Dictionary) -> void:
	if not data.has("owned_cards"):
		data["owned_cards"] = data.get("player_deck", [])
	data["version"] = 1

# _migrate_v1_to_v2: backfill world_seed and starting_biome for old saves.
static func _migrate_v1_to_v2(data: Dictionary) -> void:
	if not data.has("world_seed"):
		data["world_seed"] = 42
	if not data.has("starting_biome"):
		data["starting_biome"] = 0
	data["version"] = 2

# _migrate_v2_to_v3: backfill story_flags for old saves.
static func _migrate_v2_to_v3(data: Dictionary) -> void:
	if not data.has("story_flags"):
		data["story_flags"] = {}
	data["version"] = 3

# _migrate_v3_to_v4: backfill enemy respawn day counters for old saves.
static func _migrate_v3_to_v4(data: Dictionary) -> void:
	if not data.has("days_elapsed"):
		data["days_elapsed"] = 0
	if not data.has("last_respawn_day"):
		data["last_respawn_day"] = 0
	data["version"] = 4

static func _apply_migrations(data: Dictionary) -> void:
	var ver: int = int(data.get("version", 0))
	if ver < 1:
		_migrate_v0_to_v1(data)
	if ver < 2:
		_migrate_v1_to_v2(data)
	if ver < 3:
		_migrate_v2_to_v3(data)
	if ver < 4:
		_migrate_v3_to_v4(data)

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed
	_apply_migrations(data)
	owned_cards.assign(data.get("owned_cards", []))
	player_deck.assign(data.get("player_deck", []))
	coins = int(data.get("coins", 0))
	current_map = str(data.get("current_map", "main"))
	player_x = float(data.get("player_x", 0.0))
	player_z = float(data.get("player_z", 0.0))
	map_stack.assign(data.get("map_stack", []))
	door_stack.assign(data.get("door_stack", []))
	defeated_enemies.assign(data.get("defeated_enemies", []))
	opened_chests.assign(data.get("opened_chests", []))
	var pbed = data.get("pending_battle_enemy_data", {})
	pending_battle_enemy_data = pbed if pbed is Dictionary else {}
	in_battle_enemy_id = str(data.get("in_battle_enemy_id", ""))
	time_of_day = float(data.get("time_of_day", 0.4))
	world_seed = int(data.get("world_seed", 42))
	starting_biome = int(data.get("starting_biome", 0))
	var sf = data.get("story_flags", {})
	story_flags = sf if sf is Dictionary else {}
	days_elapsed = int(data.get("days_elapsed", 0))
	last_respawn_day = int(data.get("last_respawn_day", 0))
	_loaded = true
	return true

func save() -> void:
	if not _loaded:
		return
	var data := {
		"version": CURRENT_SAVE_VERSION,
		"owned_cards": owned_cards,
		"player_deck": player_deck,
		"coins": coins,
		"current_map": current_map,
		"player_x": player_x,
		"player_z": player_z,
		"map_stack": map_stack,
		"door_stack": door_stack,
		"defeated_enemies": defeated_enemies,
		"opened_chests": opened_chests,
		"pending_battle_enemy_data": pending_battle_enemy_data,
		"in_battle_enemy_id": in_battle_enemy_id,
		"time_of_day": time_of_day,
		"world_seed": world_seed,
		"starting_biome": starting_biome,
		"story_flags": story_flags,
		"days_elapsed": days_elapsed,
		"last_respawn_day": last_respawn_day,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

# -------------------------------------------------------------------------
# State mutators (each auto-saves)
# -------------------------------------------------------------------------

func update_position(map_name: String, x: float, z: float) -> void:
	current_map = map_name
	player_x = x
	player_z = z
	_dirty = true  # batched by the 2-second timer, not written per-frame

func sync_stacks(m_stack: Array[String], d_stack: Array[String]) -> void:
	map_stack.assign(m_stack)
	door_stack.assign(d_stack)

func add_coins(amount: int) -> void:
	coins += amount
	_dirty = true
	coins_changed.emit(coins)

func add_cards_to_deck(card_ids: Array[String]) -> void:
	for cid in card_ids:
		owned_cards.append(str(cid))
	_dirty = true

func set_active_deck(new_deck: Array[String]) -> void:
	player_deck.assign(new_deck)
	_dirty = true

func get_owned_counts() -> Dictionary:
	var counts: Dictionary = {}
	for cid in owned_cards:
		var id: String = str(cid)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts

func mark_enemy_defeated(enemy_id: String) -> void:
	if not defeated_enemies.has(enemy_id):
		defeated_enemies.append(enemy_id)
	_dirty = true

func mark_chest_opened(chest_id: String) -> void:
	if not opened_chests.has(chest_id):
		opened_chests.append(chest_id)
	_dirty = true

func is_enemy_defeated(enemy_id: String) -> bool:
	return defeated_enemies.has(enemy_id)

func is_chest_opened(chest_id: String) -> bool:
	return opened_chests.has(chest_id)

func set_pending_battle(enemy_data: Dictionary) -> void:
	pending_battle_enemy_data = enemy_data.duplicate()
	in_battle_enemy_id = str(enemy_data.get("id", ""))
	_dirty = true

func clear_pending_battle() -> void:
	pending_battle_enemy_data = {}
	in_battle_enemy_id = ""
	_dirty = true

func set_story_flag(key: String, value: bool = true) -> void:
	story_flags[key] = value
	_dirty = true
	GameBus.story_flag_set.emit(key)

func get_story_flag(key: String) -> bool:
	return story_flags.get(key, false)

func increment_day() -> void:
	days_elapsed += 1
	if days_elapsed - last_respawn_day >= IsoConst.ENEMY_RESPAWN_DAYS:
		var kept: Array[String] = []
		for eid: String in defeated_enemies:
			if eid.begins_with("map_"):
				kept.append(eid)
		defeated_enemies.assign(kept)
		last_respawn_day = days_elapsed
	_dirty = true
