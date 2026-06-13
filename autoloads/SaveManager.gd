extends Node

const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

signal coins_changed(new_amount: int)

const SAVE_PATH := "user://save.json"

# Currency
var coins: int = 0

# All cards ever acquired (the collection). Each entry is a Dictionary:
# { "uid": String, "template_id": String, "rarity": String, "attack": int, "health": int, "cost": int }
var owned_cards: Array[Dictionary] = []

# Cards currently in the active battle deck — list of UIDs from owned_cards.
var player_deck: Array[String] = []

# Crafting resource earned by scrapping cards.
var essence: int = 0

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
var defeated_duelists: Array[String] = []

# Battle state: set when a fight starts, cleared on win/lose
var pending_battle_enemy_data: Dictionary = {}
var in_battle_enemy_id: String = ""
var pending_battle_state: Dictionary = {}

# Day/night cycle position (0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset)
var time_of_day: float = 0.4

# Enemy respawn day tracking
var days_elapsed: int = 0
var last_respawn_day: int = 0

# Story progression flags
var story_flags: Dictionary = {}

# Collected lore scrolls
var collected_scrolls: Array[String] = []

# Currently equipped weapon id ("" = none)
var equipped_weapon: String = ""

# Weapons the player has picked up
var owned_weapons: Array[String] = []

# Non-weapon equipment slots
var equipped_armor: String = ""
var equipped_ring: String = ""
var equipped_trinket: String = ""
var owned_armor: Array[String] = []
var owned_rings: Array[String] = []
var owned_trinkets: Array[String] = []

# World generation — set when starting a new game from the biome selection screen
var world_seed: int = 42
var starting_biome: int = 0   # BiomeDef.GRASSLANDS

# User-controlled settings (music_volume, sfx_volume — floats 0-1)
var settings: Dictionary = {}

# Achievement tracking (persisted)
var achievement_progress: Dictionary = {}   # achievement_id -> int count
var unlocked_achievements: Array[String] = []
# Which biome IDs (int) have been visited — used by biomes_visited achievement
var visited_biomes: Array[int] = []

# Dungeon room keys that have been used (rest sites and event rooms)
var visited_dungeon_rooms: Array[String] = []

# XP & levelling
var xp: int = 0
var level: int = 1
var skill_points: int = 0
var unlocked_skills: Array[String] = []

# Magic progression
## "light", "dark", or "" (not yet chosen)
var magic_type: String = ""
var corruption_points: int = 0
var redemption_points: int = 0

# Active Endless Spire run (persisted so runs survive app restarts).
# Fields: active, floor, draft_deck, hero_hp, seed, enemies_defeated, cards_drafted.
# Default {"active": false} means no run in progress.
var spire_run: Dictionary = {"active": false}

# Best floor reached across all Spire runs (meta-progression, never resets).
var spire_best_floor: int = 0

# Puzzle shrine IDs the player has solved (rewards awarded once per id).
var solved_puzzles: Array[String] = []

# Living world event cooldown state: event_id -> { elapsed: float, active: bool }
var world_events: Dictionary = {}

# Current weather state: { "id": String, "duration": float, "biome_id": int }
var weather: Dictionary = {}

var _loaded: bool = false
var _dirty: bool = false
var _uid_counter: int = 0
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

func _gen_uid(template_id: String) -> String:
	_uid_counter += 1
	return "%s_%d_%d" % [template_id, Time.get_ticks_msec(), _uid_counter]

func new_game() -> void:
	var deck_ids: Array[String] = [
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
	]
	var extra_ids: Array[String] = ["dawn_acolyte", "dusk_wraith"]
	owned_cards.clear()
	player_deck.clear()
	for tid: String in deck_ids:
		var uid: String = add_card_instance(tid, "common")
		player_deck.append(uid)
	for tid: String in extra_ids:
		add_card_instance(tid, "common")
	essence = 0
	coins = 0
	current_map = "main"
	player_x = 0.0
	player_z = 0.0
	map_stack = []
	door_stack = []
	defeated_enemies = []
	opened_chests = []
	defeated_duelists = []
	pending_battle_enemy_data = {}
	in_battle_enemy_id = ""
	pending_battle_state = {}
	time_of_day = 0.4
	story_flags = {}
	days_elapsed = 0
	last_respawn_day = 0
	equipped_weapon = ""
	owned_weapons = []
	equipped_armor = ""
	equipped_ring = ""
	equipped_trinket = ""
	owned_armor = []
	owned_rings = []
	owned_trinkets = []
	collected_scrolls = []
	achievement_progress = {}
	unlocked_achievements = []
	visited_biomes = []
	visited_dungeon_rooms = []
	xp = 0
	level = 1
	skill_points = 0
	unlocked_skills = []
	magic_type = ""
	corruption_points = 0
	redemption_points = 0
	spire_run = {"active": false}
	solved_puzzles = []
	world_events = {}
	weather = {}
	# settings intentionally preserved across new games so volume prefs persist
	# world_seed and starting_biome are set by SceneManager.start_new_game_with_biome
	# before new_game() is called, so do not reset them here.
	_loaded = true
	save()

const CURRENT_SAVE_VERSION: int = 19

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

# _migrate_v4_to_v5: backfill equipped_weapon for old saves.
static func _migrate_v4_to_v5(data: Dictionary) -> void:
	if not data.has("equipped_weapon"):
		data["equipped_weapon"] = ""
	data["version"] = 5

# _migrate_v5_to_v6: backfill collected_scrolls for old saves.
static func _migrate_v5_to_v6(data: Dictionary) -> void:
	if not data.has("collected_scrolls"):
		data["collected_scrolls"] = []
	data["version"] = 6

# _migrate_v6_to_v7: backfill owned_weapons for old saves.
static func _migrate_v6_to_v7(data: Dictionary) -> void:
	if not data.has("owned_weapons"):
		data["owned_weapons"] = []
	data["version"] = 7

# _migrate_v7_to_v8: backfill settings and achievement tracking fields for old saves.
static func _migrate_v7_to_v8(data: Dictionary) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	if not data.has("achievement_progress"):
		data["achievement_progress"] = {}
	if not data.has("unlocked_achievements"):
		data["unlocked_achievements"] = []
	if not data.has("visited_biomes"):
		data["visited_biomes"] = []
	data["version"] = 8

# _migrate_v8_to_v9: backfill visited_dungeon_rooms for old saves.
static func _migrate_v8_to_v9(data: Dictionary) -> void:
	if not data.has("visited_dungeon_rooms"):
		data["visited_dungeon_rooms"] = []
	data["version"] = 9

# _migrate_v9_to_v10: convert owned_cards from Array[String] to Array[Dictionary] instances.
# player_deck is remapped from template IDs to instance UIDs.
# Adds essence field.
static func _migrate_v9_to_v10(data: Dictionary) -> void:
	const CardReg = preload("res://autoloads/CardRegistry.gd")
	var old_owned: Array = data.get("owned_cards", [])
	var old_deck: Array = data.get("player_deck", [])
	var new_instances: Array = []
	var counter: int = 0
	for item in old_owned:
		var tid: String = str(item)
		var tmpl: Dictionary = CardReg.get_template(tid)
		var uid: String = "%s_v10_%d" % [tid, counter]
		counter += 1
		new_instances.append({
			"uid": uid,
			"template_id": tid,
			"rarity": "common",
			"attack": int(tmpl.get("attack", 1)),
			"health": int(tmpl.get("health", 1)),
			"cost": int(tmpl.get("cost", 1)),
		})
	# Remap deck: match each template ID to the first unused instance UID.
	var used_uids: Dictionary = {}
	var new_deck: Array = []
	for deck_item in old_deck:
		var deck_tid: String = str(deck_item)
		for inst: Dictionary in new_instances:
			var iuid: String = str(inst.get("uid", ""))
			if str(inst.get("template_id", "")) == deck_tid and not used_uids.has(iuid):
				new_deck.append(iuid)
				used_uids[iuid] = true
				break
	data["owned_cards"] = new_instances
	data["player_deck"] = new_deck
	data["essence"] = 0
	data["version"] = 10

# _migrate_v10_to_v11: backfill non-weapon equipment slots.
static func _migrate_v10_to_v11(data: Dictionary) -> void:
	if not data.has("equipped_armor"):   data["equipped_armor"] = ""
	if not data.has("equipped_ring"):    data["equipped_ring"] = ""
	if not data.has("equipped_trinket"): data["equipped_trinket"] = ""
	if not data.has("owned_armor"):      data["owned_armor"] = []
	if not data.has("owned_rings"):      data["owned_rings"] = []
	if not data.has("owned_trinkets"):   data["owned_trinkets"] = []
	data["version"] = 11

# _migrate_v11_to_v12: backfill XP, level, skill_points for old saves.
static func _migrate_v11_to_v12(data: Dictionary) -> void:
	if not data.has("xp"):              data["xp"] = 0
	if not data.has("level"):           data["level"] = 1
	if not data.has("skill_points"):    data["skill_points"] = 0
	if not data.has("unlocked_skills"): data["unlocked_skills"] = []
	data["version"] = 12

# _migrate_v12_to_v13: backfill magic type and cross-magic currency for old saves.
static func _migrate_v12_to_v13(data: Dictionary) -> void:
	if not data.has("magic_type"):          data["magic_type"] = ""
	if not data.has("corruption_points"):   data["corruption_points"] = 0
	if not data.has("redemption_points"):   data["redemption_points"] = 0
	data["version"] = 13

# _migrate_v13_to_v14: backfill mid-battle state snapshot for old saves.
static func _migrate_v13_to_v14(data: Dictionary) -> void:
	if not data.has("pending_battle_state"):
		data["pending_battle_state"] = {}
	data["version"] = 14

# _migrate_v14_to_v15: backfill defeated_duelists for old saves.
static func _migrate_v14_to_v15(data: Dictionary) -> void:
	if not data.has("defeated_duelists"):
		data["defeated_duelists"] = []
	data["version"] = 15

# _migrate_v15_to_v16: backfill spire_run for old saves.
static func _migrate_v15_to_v16(data: Dictionary) -> void:
	if not data.has("spire_run"):
		data["spire_run"] = {"active": false}
	data["version"] = 16

# _migrate_v16_to_v17: backfill spire_best_floor for old saves.
static func _migrate_v16_to_v17(data: Dictionary) -> void:
	if not data.has("spire_best_floor"):
		data["spire_best_floor"] = 0
	data["version"] = 17

# _migrate_v17_to_v18: backfill solved_puzzles and world_events for old saves.
static func _migrate_v17_to_v18(data: Dictionary) -> void:
	if not data.has("solved_puzzles"):
		data["solved_puzzles"] = []
	if not data.has("world_events"):
		data["world_events"] = {}
	data["version"] = 18

# _migrate_v18_to_v19: backfill weather state for old saves.
static func _migrate_v18_to_v19(data: Dictionary) -> void:
	if not data.has("weather"):
		data["weather"] = {"id": "", "duration": 0.0, "biome_id": 0}
	data["version"] = 19

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
	if ver < 5:
		_migrate_v4_to_v5(data)
	if ver < 6:
		_migrate_v5_to_v6(data)
	if ver < 7:
		_migrate_v6_to_v7(data)
	if ver < 8:
		_migrate_v7_to_v8(data)
	if ver < 9:
		_migrate_v8_to_v9(data)
	if ver < 10:
		_migrate_v9_to_v10(data)
	if ver < 11:
		_migrate_v10_to_v11(data)
	if ver < 12:
		_migrate_v11_to_v12(data)
	if ver < 13:
		_migrate_v12_to_v13(data)
	if ver < 14:
		_migrate_v13_to_v14(data)
	if ver < 15:
		_migrate_v14_to_v15(data)
	if ver < 16:
		_migrate_v15_to_v16(data)
	if ver < 17:
		_migrate_v16_to_v17(data)
	if ver < 18:
		_migrate_v17_to_v18(data)
	if ver < 19:
		_migrate_v18_to_v19(data)

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
	essence = int(data.get("essence", 0))
	coins = int(data.get("coins", 0))
	current_map = str(data.get("current_map", "main"))
	player_x = float(data.get("player_x", 0.0))
	player_z = float(data.get("player_z", 0.0))
	map_stack.assign(data.get("map_stack", []))
	door_stack.assign(data.get("door_stack", []))
	defeated_enemies.assign(data.get("defeated_enemies", []))
	opened_chests.assign(data.get("opened_chests", []))
	defeated_duelists.assign(data.get("defeated_duelists", []))
	var pbed = data.get("pending_battle_enemy_data", {})
	pending_battle_enemy_data = pbed if pbed is Dictionary else {}
	in_battle_enemy_id = str(data.get("in_battle_enemy_id", ""))
	var pbs = data.get("pending_battle_state", {})
	pending_battle_state = pbs if pbs is Dictionary else {}
	time_of_day = float(data.get("time_of_day", 0.4))
	world_seed = int(data.get("world_seed", 42))
	starting_biome = int(data.get("starting_biome", 0))
	var sf = data.get("story_flags", {})
	story_flags = sf if sf is Dictionary else {}
	days_elapsed = int(data.get("days_elapsed", 0))
	last_respawn_day = int(data.get("last_respawn_day", 0))
	equipped_weapon = str(data.get("equipped_weapon", ""))
	owned_weapons.assign(data.get("owned_weapons", []))
	equipped_armor = str(data.get("equipped_armor", ""))
	equipped_ring = str(data.get("equipped_ring", ""))
	equipped_trinket = str(data.get("equipped_trinket", ""))
	owned_armor.assign(data.get("owned_armor", []))
	owned_rings.assign(data.get("owned_rings", []))
	owned_trinkets.assign(data.get("owned_trinkets", []))
	collected_scrolls.assign(data.get("collected_scrolls", []))
	var sv = data.get("settings", {})
	settings = sv if sv is Dictionary else {}
	var ap = data.get("achievement_progress", {})
	achievement_progress = ap if ap is Dictionary else {}
	unlocked_achievements.assign(data.get("unlocked_achievements", []))
	visited_biomes.assign(data.get("visited_biomes", []))
	visited_dungeon_rooms.assign(data.get("visited_dungeon_rooms", []))
	xp = int(data.get("xp", 0))
	level = int(data.get("level", 1))
	skill_points = int(data.get("skill_points", 0))
	unlocked_skills.assign(data.get("unlocked_skills", []))
	magic_type = str(data.get("magic_type", ""))
	corruption_points = int(data.get("corruption_points", 0))
	redemption_points = int(data.get("redemption_points", 0))
	var sr = data.get("spire_run", {"active": false})
	spire_run = sr if sr is Dictionary else {"active": false}
	spire_best_floor = int(data.get("spire_best_floor", 0))
	solved_puzzles.assign(data.get("solved_puzzles", []))
	var we = data.get("world_events", {})
	world_events = we if we is Dictionary else {}
	var wd = data.get("weather", {"id": "", "duration": 0.0, "biome_id": 0})
	weather = wd if wd is Dictionary else {"id": "", "duration": 0.0, "biome_id": 0}
	_loaded = true
	return true

func save() -> void:
	if not _loaded:
		return
	var data := {
		"version": CURRENT_SAVE_VERSION,
		"owned_cards": owned_cards,
		"player_deck": player_deck,
		"essence": essence,
		"coins": coins,
		"current_map": current_map,
		"player_x": player_x,
		"player_z": player_z,
		"map_stack": map_stack,
		"door_stack": door_stack,
		"defeated_enemies": defeated_enemies,
		"opened_chests": opened_chests,
		"defeated_duelists": defeated_duelists,
		"pending_battle_enemy_data": pending_battle_enemy_data,
		"in_battle_enemy_id": in_battle_enemy_id,
		"pending_battle_state": pending_battle_state,
		"time_of_day": time_of_day,
		"world_seed": world_seed,
		"starting_biome": starting_biome,
		"story_flags": story_flags,
		"days_elapsed": days_elapsed,
		"last_respawn_day": last_respawn_day,
		"equipped_weapon": equipped_weapon,
		"owned_weapons": owned_weapons,
		"equipped_armor": equipped_armor,
		"equipped_ring": equipped_ring,
		"equipped_trinket": equipped_trinket,
		"owned_armor": owned_armor,
		"owned_rings": owned_rings,
		"owned_trinkets": owned_trinkets,
		"collected_scrolls": collected_scrolls,
		"settings": settings,
		"achievement_progress": achievement_progress,
		"unlocked_achievements": unlocked_achievements,
		"visited_biomes": visited_biomes,
		"visited_dungeon_rooms": visited_dungeon_rooms,
		"xp": xp,
		"level": level,
		"skill_points": skill_points,
		"unlocked_skills": unlocked_skills,
		"magic_type": magic_type,
		"corruption_points": corruption_points,
		"redemption_points": redemption_points,
		"spire_run": spire_run,
		"spire_best_floor": spire_best_floor,
		"solved_puzzles": solved_puzzles,
		"world_events": world_events,
		"weather": weather,
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
	if coins == 0 and amount > 0:
		GameBus.tutorial_popup_requested.emit("coins")
	coins += amount
	_dirty = true
	coins_changed.emit(coins)

## Compatibility shim: creates a common-rarity instance from each template ID and
## adds it to the collection. Callers that already do a rarity roll should use
## add_card_instance() directly instead.
func add_cards_to_deck(card_ids: Array[String]) -> void:
	for tid: String in card_ids:
		add_card_instance(tid, "common")
	if card_ids.size() > 0:
		increment_progress("cards_earned", card_ids.size())

func grant_achievement_card(card_id: String) -> void:
	# Only grant if the player doesn't own any copy yet.
	for inst: Dictionary in owned_cards:
		if str(inst.get("template_id", "")) == card_id:
			return
	add_card_instance(card_id, "common")

func set_active_deck(new_deck: Array[String]) -> void:
	player_deck.assign(new_deck)
	_dirty = true

func get_owned_counts() -> Dictionary:
	var counts: Dictionary = {}
	for inst: Dictionary in owned_cards:
		var tid: String = str(inst.get("template_id", ""))
		if tid != "":
			counts[tid] = int(counts.get(tid, 0)) + 1
	return counts

## Creates a new card instance with the given stats and appends it to owned_cards.
## Returns the generated UID. attack/health/cost default to the card template's base stats.
func add_card_instance(template_id: String, rarity: String, attack: int = -1, health: int = -1, cost: int = -1) -> String:
	var tmpl: Dictionary = CardRegistry.get_template(template_id)
	var atk: int = attack if attack >= 0 else int(tmpl.get("attack", 0))
	var hp: int  = health if health >= 0 else int(tmpl.get("health", 0))
	var c: int   = cost   if cost   >= 0 else int(tmpl.get("cost", 1))
	var uid: String = _gen_uid(template_id)
	owned_cards.append({
		"uid": uid,
		"template_id": template_id,
		"rarity": rarity,
		"attack": atk,
		"health": hp,
		"cost": c,
	})
	if rarity != "common":
		GameBus.tutorial_popup_requested.emit("card_rarity")
	_dirty = true
	return uid

## Removes a card instance by UID from owned_cards and player_deck.
func remove_card_instance(uid: String) -> void:
	for i in range(owned_cards.size() - 1, -1, -1):
		if str(owned_cards[i].get("uid", "")) == uid:
			owned_cards.remove_at(i)
			break
	var deck_idx: int = player_deck.find(uid)
	if deck_idx >= 0:
		player_deck.remove_at(deck_idx)
	_dirty = true

## Sells a card instance for gold. No-op if uid not found or card is unique.
func sell_card_instance(uid: String) -> void:
	var inst: Dictionary = get_instance_by_uid(uid)
	if inst.is_empty():
		return
	var rarity: String = str(inst.get("rarity", "common"))
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	add_coins(int(cfg.get("sell_gold", 0)))
	remove_card_instance(uid)

## Scraps a card instance for essence. No-op if uid not found or card is unique.
func scrap_card_instance(uid: String) -> void:
	var inst: Dictionary = get_instance_by_uid(uid)
	if inst.is_empty():
		return
	var rarity: String = str(inst.get("rarity", "common"))
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	if essence == 0:
		GameBus.tutorial_popup_requested.emit("essence")
	essence += int(cfg.get("scrap_essence", 0))
	GameBus.essence_changed.emit(essence)
	remove_card_instance(uid)
	_dirty = true

## Spends essence for crafting. Returns false without modifying anything if insufficient.
func spend_essence(amount: int) -> bool:
	if essence < amount:
		return false
	essence -= amount
	GameBus.essence_changed.emit(essence)
	_dirty = true
	return true

## Combines 3 available (non-deck) instances of template_id+rarity into 1 of the next rarity tier.
## Returns the new instance dict, or {} if insufficient non-deck copies exist.
func combine_cards(template_id: String, rarity: String) -> Dictionary:
	const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
	var to_remove: Array[String] = []
	for inst: Dictionary in owned_cards:
		if to_remove.size() >= 3:
			break
		if str(inst.get("template_id", "")) == template_id and str(inst.get("rarity", "")) == rarity:
			var uid: String = str(inst.get("uid", ""))
			if not player_deck.has(uid):
				to_remove.append(uid)
	if to_remove.size() < 3:
		return {}
	for uid: String in to_remove:
		remove_card_instance(uid)
	var rarity_order: Array[String] = ["common", "rare", "epic", "legendary"]
	var src_idx: int = rarity_order.find(rarity)
	if src_idx < 0 or src_idx >= rarity_order.size() - 1:
		return {}
	var next_rarity: String = rarity_order[src_idx + 1]
	var stats: Dictionary = CardDropUtil.roll_stats(template_id, next_rarity)
	var new_uid: String = add_card_instance(template_id, next_rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
	return get_instance_by_uid(new_uid)

## Returns all owned card instances (the full collection array).
func get_owned_instances() -> Array[Dictionary]:
	return owned_cards

## Returns the instance dict for a UID, or {} if not found.
func get_instance_by_uid(uid: String) -> Dictionary:
	for inst: Dictionary in owned_cards:
		if str(inst.get("uid", "")) == uid:
			return inst
	return {}

## Returns instance dicts for each UID in player_deck (skips missing UIDs).
func get_deck_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for uid: String in player_deck:
		var inst: Dictionary = get_instance_by_uid(uid)
		if not inst.is_empty():
			result.append(inst)
	return result

## Returns the first owned instance UID for template_id not already in exclude_uids.
## Returns "" if none available.
func find_available_uid_for_template(template_id: String, exclude_uids: Array[String]) -> String:
	for inst: Dictionary in owned_cards:
		var uid: String = str(inst.get("uid", ""))
		if str(inst.get("template_id", "")) == template_id and not exclude_uids.has(uid):
			return uid
	return ""

## Resolves player_deck UIDs to template IDs for use by the battle system.
func get_deck_template_ids() -> Array[String]:
	var result: Array[String] = []
	for uid: String in player_deck:
		var inst: Dictionary = get_instance_by_uid(uid)
		if not inst.is_empty():
			result.append(str(inst.get("template_id", "")))
	return result

func mark_enemy_defeated(enemy_id: String) -> void:
	if not defeated_enemies.has(enemy_id):
		defeated_enemies.append(enemy_id)
	_dirty = true

func mark_duelist_defeated(npc_id: String) -> void:
	if not defeated_duelists.has(npc_id):
		defeated_duelists.append(npc_id)
	_dirty = true

func mark_chest_opened(chest_id: String) -> void:
	if not opened_chests.has(chest_id):
		opened_chests.append(chest_id)
		increment_progress("chests_opened", 1)
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

func set_pending_battle_state(state_dict: Dictionary) -> void:
	pending_battle_state = state_dict
	_dirty = true

func clear_pending_battle_state() -> void:
	pending_battle_state = {}
	_dirty = true

func set_story_flag(key: String, value: bool = true) -> void:
	story_flags[key] = value
	_dirty = true
	GameBus.story_flag_set.emit(key)
	if value:
		check_flag_achievement(key)

func get_story_flag(key: String) -> bool:
	return story_flags.get(key, false)

func mark_scroll_collected(scroll_id: String) -> void:
	if not collected_scrolls.has(scroll_id):
		collected_scrolls.append(scroll_id)
	_dirty = true

func is_scroll_collected(scroll_id: String) -> bool:
	return collected_scrolls.has(scroll_id)

func add_weapon(weapon_id: String) -> void:
	if not owned_weapons.has(weapon_id):
		owned_weapons.append(weapon_id)
	_dirty = true

func equip_weapon(weapon_id: String) -> void:
	equipped_weapon = weapon_id
	_dirty = true

## Adds an equipment item to the appropriate owned array based on its slot.
## slot must be "weapon", "armor", "ring", or "trinket".
func add_equipment(item_id: String, slot: String) -> void:
	match slot:
		"weapon":
			if not owned_weapons.has(item_id):
				owned_weapons.append(item_id)
		"armor":
			if not owned_armor.has(item_id):
				owned_armor.append(item_id)
		"ring":
			if not owned_rings.has(item_id):
				owned_rings.append(item_id)
		"trinket":
			if not owned_trinkets.has(item_id):
				owned_trinkets.append(item_id)
	_dirty = true

## Equips an item into its slot. Pass "" to unequip.
func equip_item(item_id: String, slot: String) -> void:
	match slot:
		"weapon":   equipped_weapon  = item_id
		"armor":    equipped_armor   = item_id
		"ring":     equipped_ring    = item_id
		"trinket":  equipped_trinket = item_id
	_dirty = true

## Returns the owned array for the given slot.
func get_owned_by_slot(slot: String) -> Array[String]:
	match slot:
		"weapon":  return owned_weapons
		"armor":   return owned_armor
		"ring":    return owned_rings
		"trinket": return owned_trinkets
	return []

## Returns the currently equipped item id for the given slot ("" if none).
func get_equipped_by_slot(slot: String) -> String:
	match slot:
		"weapon":  return equipped_weapon
		"armor":   return equipped_armor
		"ring":    return equipped_ring
		"trinket": return equipped_trinket
	return ""

static func xp_for_level(lvl: int) -> int:
	return lvl * lvl * 50  # 1→2: 50xp, 2→3: 200xp, 3→4: 450xp

static func _compute_level(current_xp: int) -> int:
	var lvl: int = 1
	while current_xp >= xp_for_level(lvl):
		lvl += 1
	return lvl - 1

func set_magic_type(t: String) -> void:
	magic_type = t
	_dirty = true

func has_skill(id: String) -> bool:
	return unlocked_skills.has(id)

func unlock_skill(id: String) -> void:
	if unlocked_skills.has(id):
		return
	unlocked_skills.append(id)
	skill_points = max(0, skill_points - 1)
	_dirty = true

func unlock_cross_skill(id: String, cost: int, currency: String) -> void:
	if unlocked_skills.has(id):
		return
	if currency == "corruption":
		if corruption_points < cost:
			return
		corruption_points -= cost
	else:
		if redemption_points < cost:
			return
		redemption_points -= cost
	unlocked_skills.append(id)
	_dirty = true

func add_corruption_points(amount: int) -> void:
	corruption_points += amount
	_dirty = true
	GameBus.corruption_points_changed.emit(corruption_points)

func add_redemption_points(amount: int) -> void:
	redemption_points += amount
	_dirty = true
	GameBus.redemption_points_changed.emit(redemption_points)

func add_xp(amount: int) -> void:
	xp += amount
	var new_level: int = _compute_level(xp)
	if new_level > level:
		skill_points += new_level - level
		level = new_level
		GameBus.level_up.emit(level)
	GameBus.xp_changed.emit(xp, level)
	_dirty = true

func get_setting(key: String, default_value: Variant) -> Variant:
	return settings.get(key, default_value)

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_dirty = true

func mark_dirty() -> void:
	_dirty = true

func visit_biome(biome_id: int) -> void:
	if visited_biomes.has(biome_id):
		return
	visited_biomes.append(biome_id)
	increment_progress("biomes_visited", 1)
	_dirty = true

func increment_progress(condition_type: String, amount: int) -> void:
	for a: Dictionary in AchievementRegistry.get_all():
		if a["condition_type"] != condition_type:
			continue
		var aid: String = str(a["id"])
		if unlocked_achievements.has(aid):
			continue
		var current: int = int(achievement_progress.get(aid, 0))
		achievement_progress[aid] = current + amount
		_check_unlock(aid, a)
	_dirty = true

func check_flag_achievement(flag: String) -> void:
	for a: Dictionary in AchievementRegistry.get_all():
		if a["condition_type"] != "specific_flag":
			continue
		if str(a.get("flag_key", "")) != flag:
			continue
		var aid: String = str(a["id"])
		if unlocked_achievements.has(aid):
			continue
		achievement_progress[aid] = 1
		_check_unlock(aid, a)
	_dirty = true

func check_deck_achievements(deck: Array[String]) -> void:
	var dawn_count: int = 0
	var dusk_count: int = 0
	for uid: String in deck:
		var inst: Dictionary = get_instance_by_uid(uid)
		var tid: String = str(inst.get("template_id", uid)) if not inst.is_empty() else uid
		var tmpl: Dictionary = CardRegistry.get_template(tid)
		var branch: String = str(tmpl.get("magic_branch", ""))
		if branch == "dawn":
			dawn_count += 1
		elif branch == "dusk":
			dusk_count += 1
	if dawn_count >= 5:
		increment_progress("dawn_battle_won", 1)
	if dusk_count >= 5:
		increment_progress("dusk_battle_won", 1)

func _check_unlock(achievement_id: String, achievement: Dictionary) -> void:
	var target: int = int(achievement.get("target_value", 1))
	var current: int = int(achievement_progress.get(achievement_id, 0))
	if current >= target and not unlocked_achievements.has(achievement_id):
		unlocked_achievements.append(achievement_id)
		GameBus.achievement_unlocked.emit(achievement_id)

func mark_dungeon_room_used(room_key: String) -> void:
	if not visited_dungeon_rooms.has(room_key):
		visited_dungeon_rooms.append(room_key)
	_dirty = true

func is_dungeon_room_used(room_key: String) -> bool:
	return visited_dungeon_rooms.has(room_key)

# -------------------------------------------------------------------------
# Endless Spire run helpers
# -------------------------------------------------------------------------

func is_spire_active() -> bool:
	return bool(spire_run.get("active", false))

func get_spire_run() -> Dictionary:
	return spire_run

func start_spire_run(seed: int) -> void:
	spire_run = {
		"active": true,
		"floor": 1,
		"draft_deck": [],
		"hero_hp": 30,
		"seed": seed,
		"enemies_defeated": 0,
		"cards_drafted": 0,
	}
	_dirty = true

func advance_spire_floor() -> void:
	if not is_spire_active():
		return
	spire_run["floor"] = int(spire_run.get("floor", 1)) + 1
	spire_run["enemies_defeated"] = int(spire_run.get("enemies_defeated", 0)) + 1
	_dirty = true

func add_drafted_card(card_id: String) -> void:
	if not is_spire_active():
		return
	var deck: Array = spire_run.get("draft_deck", [])
	deck.append(card_id)
	spire_run["draft_deck"] = deck
	spire_run["cards_drafted"] = int(spire_run.get("cards_drafted", 0)) + 1
	_dirty = true

## Ends the current spire run and returns the final stats dictionary.
## Awards floor*5 coins, updates spire_best_floor, sets achievement flags.
## Returned dict: floors_cleared, enemies_defeated, cards_drafted, seed,
##                coins_earned, is_new_record, best_floor, draft_deck_ids.
func end_spire_run() -> Dictionary:
	var floors_cleared: int = int(spire_run.get("floor", 1)) - 1
	var enemies_defeated: int = int(spire_run.get("enemies_defeated", 0))
	var cards_drafted: int = int(spire_run.get("cards_drafted", 0))
	var run_seed: int = int(spire_run.get("seed", 0))
	var draft_deck_ids: Array = spire_run.get("draft_deck", [])

	var coin_reward: int = floors_cleared * 5
	coins += coin_reward
	coins_changed.emit(coins)

	var is_record: bool = floors_cleared > spire_best_floor
	if is_record:
		spire_best_floor = floors_cleared

	var stats: Dictionary = {
		"floors_cleared": floors_cleared,
		"enemies_defeated": enemies_defeated,
		"cards_drafted": cards_drafted,
		"seed": run_seed,
		"coins_earned": coin_reward,
		"is_new_record": is_record,
		"best_floor": spire_best_floor,
		"draft_deck_ids": draft_deck_ids.duplicate(),
	}

	spire_run = {"active": false}
	_dirty = true

	if floors_cleared >= 5 and not story_flags.get("spire_reached_floor_5", false):
		set_story_flag("spire_reached_floor_5")
	if floors_cleared >= 10 and not story_flags.get("spire_reached_floor_10", false):
		set_story_flag("spire_reached_floor_10")

	return stats

func set_spire_hero_hp(hp: int) -> void:
	if not is_spire_active():
		return
	spire_run["hero_hp"] = hp
	_dirty = true

func mark_puzzle_solved(puzzle_id: String) -> void:
	if not solved_puzzles.has(puzzle_id):
		solved_puzzles.append(puzzle_id)
	_dirty = true

func is_puzzle_solved(puzzle_id: String) -> bool:
	return solved_puzzles.has(puzzle_id)

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
