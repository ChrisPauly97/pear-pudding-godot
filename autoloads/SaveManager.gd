extends Node

const SAVE_PATH := "user://save.json"

# Player's persistent card collection (list of card template IDs)
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
	player_deck = [
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
	]
	current_map = "main"
	player_x = 0.0
	player_z = 0.0
	map_stack = []
	door_stack = []
	defeated_enemies = []
	opened_chests = []
	_loaded = true
	save()

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
	player_deck.assign(data.get("player_deck", []))
	current_map = str(data.get("current_map", "main"))
	player_x = float(data.get("player_x", 0.0))
	player_z = float(data.get("player_z", 0.0))
	map_stack.assign(data.get("map_stack", []))
	door_stack.assign(data.get("door_stack", []))
	defeated_enemies.assign(data.get("defeated_enemies", []))
	opened_chests.assign(data.get("opened_chests", []))
	_loaded = true
	return true

func save() -> void:
	if not _loaded:
		return
	var data := {
		"version": 1,
		"player_deck": player_deck,
		"current_map": current_map,
		"player_x": player_x,
		"player_z": player_z,
		"map_stack": map_stack,
		"door_stack": door_stack,
		"defeated_enemies": defeated_enemies,
		"opened_chests": opened_chests,
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
	# Position is saved on map transitions, not here (avoids per-frame writes)

func sync_stacks(m_stack: Array[String], d_stack: Array[String]) -> void:
	map_stack.assign(m_stack)
	door_stack.assign(d_stack)

func add_cards_to_deck(card_ids: Array) -> void:
	for cid in card_ids:
		player_deck.append(str(cid))
	_dirty = true

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
