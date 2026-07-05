extends Node

const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _CardInstanceUtil = preload("res://game_logic/CardInstanceUtil.gd")

signal coins_changed(new_amount: int)

const LEGACY_SAVE_PATH := "user://save.json"
const NUM_SAVE_SLOTS: int = 3
const _HMAC_SECRET: String = "7e3f91c4b8d20a5e6f19c7b3d4e8f201"

var active_slot: int = 1

func _get_slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

func _get_slot_tmp_path(slot: int) -> String:
	return "user://save_slot_%d.json.tmp" % slot

func _get_slot_bak_path(slot: int) -> String:
	return "user://save_slot_%d.json.bak" % slot

# Currency
var coins: int = 0

# All cards ever acquired (the collection). Each entry is a Dictionary:
# { "uid": String, "template_id": String, "rarity": String, "attack": int, "health": int, "cost": int,
#   "kills": int, "battles_survived": int, "custom_name": String }
var owned_cards: Array[Dictionary] = []
var _uid_index: Dictionary = {}  # uid -> Dictionary reference for O(1) lookups

# Overflow queue for card rewards that couldn't fit in the bag when granted.
# Never counts against bag_size; not indexed in _uid_index until claimed.
var mailbox_cards: Array[Dictionary] = []

# Cards currently in the active battle deck — list of UIDs from owned_cards.
# This mirrors loadouts[active_loadout].cards and is kept in sync at all times.
var player_deck: Array[String] = []

# Named deck loadouts (up to MAX_LOADOUTS). Each entry: {name: String, cards: Array[String]}.
const MAX_LOADOUTS: int = 5
var loadouts: Array[Dictionary] = []
var active_loadout: int = 0

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

# Weapons the player has picked up.
# Each entry: {weapon_id: String, upgrade_level: int}
var owned_weapons: Array[Dictionary] = []

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

# Treasure map system
var treasure_fragments: int = 0          # 0–2 collected fragments; resets to 0 on assembly
var active_treasure: Dictionary = {}     # { "site_x": int, "site_z": int, "completed": bool } or {}
var treasures_completed: int = 0         # total maps excavated; used as salt for next dig site

# Waystone fast travel
var activated_waystones: Array[String] = []

# Bestiary: per-enemy-type encounter and defeat tracking
var bestiary: Dictionary = {}           # type_id -> {seen: int, defeated: int}
var bestiary_complete_rewarded: bool = false

# Player home
var home_owned: bool = false

# Respawn point (set when resting at the bed in player_home)
var respawn_map: String = ""
var respawn_x: float = 0.0
var respawn_z: float = 0.0

# Mount system
var owned_mounts: Array[String] = []
var active_mount: String = ""
var is_mounted: bool = false

# Card pack pity counter: increments each pack purchase, resets when a legendary is obtained.
var packs_since_legendary: int = 0

# Bag capacity: max card slots (common cards share one slot per template; rare+ each take one slot).
var bag_size: int = IsoConst.BAG_SIZE_DEFAULT

# Currently equipped companion id ("" = none)
var active_companion: String = ""

# Player-placed waypoint: {map: String, tx: int, tz: int} or {} when cleared
var waypoint: Dictionary = {}

# Bounty system
var bounty_day: int = 0
var offered_bounties: Array[Dictionary] = []
var active_bounties: Array[Dictionary] = []

# Siege system
# Active siege: {town: String, stage: int, hero_hp: int, day_started: int} or {} when none.
var siege: Dictionary = {}
var last_siege_day: int = 0
# Town gratitude discounts: {town_name: expiry_day} — discount active when expiry_day >= days_elapsed.
var town_discounts: Dictionary = {}

# Rival (Isfig) encounter progression
var rival_encounters_won: int = 0   # 0, 1, or 2 before the final showdown
var rival_defeated: bool = false    # true after the final showdown; guards the unique card reward

# Soulbind capture tracking (GID-061)
var captured_signatures: Array[String] = []

# Cantrip cooldowns (GID-065): cantrip_id -> Unix expiry timestamp (float)
var cantrip_cooldowns: Dictionary = {}

# Burial mounds that have been dug (GID-065 Skeleton Dig)
var dug_mounds: Array[String] = []

# Blight system (GID-066): IDs of Blight Hearts the player has cleansed.
var blight_cleansed_hearts: Array[String] = []

# Landmark discovery system (GID-067): IDs of landmarks the player has discovered.
var discovered_landmarks: Array[String] = []

# Ley line system (GID-068): IDs of Mana Wells the player has collected.
var collected_mana_wells: Array[String] = []

# Garden system (GID-056)
# Each plot dict: {seed_id: String, planted_day: int} or {} when empty.
var garden_plots: Array[Dictionary] = []
var seeds: Dictionary = {}    # seed_id -> count
var plants: Dictionary = {}   # plant_id -> count
var potions: Dictionary = {}  # potion_id -> count

var last_saved: String = ""

var _loaded: bool = false
var _dirty: bool = false
var _uid_counter: int = 0
const SAVE_INTERVAL: float = 2.0  # batch disk writes at most every 2 seconds

# Slot that provided the live achievement data (set by load_save/new_game; never
# cleared by adopt_session_character so co-op sessions can still persist achievements).
var _achievement_slot: int = -1
var _achievement_dirty: bool = false

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = SAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_flush_if_dirty)
	add_child(timer)
	# Migrate legacy save.json → slot 1 if no slot files exist yet
	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		var any_exists: bool = false
		for s: int in range(1, NUM_SAVE_SLOTS + 1):
			if FileAccess.file_exists(_get_slot_path(s)):
				any_exists = true
				break
		if not any_exists:
			DirAccess.copy_absolute(LEGACY_SAVE_PATH, _get_slot_path(1))

# -------------------------------------------------------------------------
# Save slot API
# -------------------------------------------------------------------------

func set_active_slot(slot: int) -> void:
	active_slot = clamp(slot, 1, NUM_SAVE_SLOTS)

func has_save_slot(slot: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot))

func get_slot_metadata(slot: int) -> Dictionary:
	var parsed = _read_save_json(_get_slot_path(slot))
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	return {
		"current_map": str(data.get("current_map", "?")),
		"coins": int(data.get("coins", 0)),
		"level": max(1, _compute_level(int(data.get("xp", 0)))),
		"last_saved": str(data.get("last_saved", "")),
	}

func delete_save_slot(slot: int) -> void:
	var path: String = _get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var bak: String = _get_slot_bak_path(slot)
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)

func _flush_if_dirty() -> void:
	if _dirty and _loaded:
		_dirty = false
		save()
	if _achievement_dirty and _achievement_slot >= 0 and not _loaded:
		_achievement_dirty = false
		_flush_achievements(_achievement_slot)

## Write only achievement fields into the on-disk save for the given slot.
## Used during co-op sessions where _loaded = false blocks the normal save() path.
func _flush_achievements(slot: int) -> void:
	var path: String = _get_slot_path(slot)
	var parsed = _read_save_json(path)
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	data["achievement_progress"] = achievement_progress
	data["unlocked_achievements"] = unlocked_achievements
	var tmp_path: String = _get_slot_tmp_path(slot)
	var bak_path: String = _get_slot_bak_path(slot)
	var inner_json: String = JSON.stringify(data, "\t")
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not tmp_file:
		return
	tmp_file.store_string(JSON.stringify({"hmac": _sign(inner_json), "payload": inner_json}))
	tmp_file = null
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, bak_path)
	DirAccess.rename_absolute(tmp_path, path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_EXIT_TREE \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_flush_if_dirty()

# -------------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------------

func has_save() -> bool:
	for slot: int in range(1, NUM_SAVE_SLOTS + 1):
		if has_save_slot(slot):
			return true
	return false

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
	mailbox_cards.clear()
	_uid_index.clear()
	player_deck.clear()
	for tid: String in deck_ids:
		var uid: String = add_card_instance(tid, "common")
		player_deck.append(uid)
	for tid: String in extra_ids:
		add_card_instance(tid, "common")
	essence = 0
	coins = 3000
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
	xp = 11250
	level = 15
	skill_points = 14
	unlocked_skills = []
	magic_type = ""
	corruption_points = 0
	redemption_points = 0
	spire_run = {"active": false}
	solved_puzzles = []
	world_events = {}
	weather = {}
	treasure_fragments = 0
	active_treasure = {}
	treasures_completed = 0
	activated_waystones = []
	bestiary = {}
	bestiary_complete_rewarded = false
	home_owned = false
	respawn_map = ""
	respawn_x = 0.0
	respawn_z = 0.0
	owned_mounts = []
	active_mount = ""
	is_mounted = false
	packs_since_legendary = 0
	active_companion = ""
	waypoint = {}
	bounty_day = 0
	offered_bounties = []
	active_bounties = []
	siege = {}
	last_siege_day = 0
	town_discounts = {}
	bag_size = IsoConst.BAG_SIZE_DEFAULT
	rival_encounters_won = 0
	rival_defeated = false
	garden_plots.assign([{}, {}, {}])
	seeds = {}
	plants = {}
	potions = {}
	captured_signatures = []
	cantrip_cooldowns = {}
	dug_mounds = []
	blight_cleansed_hearts = []
	discovered_landmarks = []
	collected_mana_wells = []
	var starting_deck_copy: Array[String] = []
	starting_deck_copy.assign(player_deck)
	loadouts = [{"name": "Deck 1", "cards": starting_deck_copy}]
	active_loadout = 0
	# settings intentionally preserved across new games so volume prefs persist
	# world_seed and starting_biome are set by SceneManager.start_new_game_with_biome
	# before new_game() is called, so do not reset them here.
	_achievement_slot = active_slot
	_loaded = true
	save()

## Seeds a transient starter deck for a cold co-op session that was launched straight
## from the menu without ever starting or loading a game (GID-092 / TID-335). Without
## this, `player_deck` is empty, so the PvP challenge flow's DECK_MIN gate blocks the
## battle from ever starting.
##
## No-op when a real game is loaded (`_loaded` true) — that game's deck is used as-is —
## or when the current deck already meets DECK_MIN. Because `_loaded` stays false for a
## cold co-op session, `save()`/`_flush_if_dirty()` remain no-ops, so the single on-disk
## save is never overwritten by a throwaway co-op session.
func ensure_coop_deck() -> void:
	if _loaded:
		return
	if get_deck_instances().size() >= IsoConst.DECK_MIN:
		return
	var deck_ids: Array[String] = [
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
	]
	owned_cards.clear()
	_uid_index.clear()
	player_deck.clear()
	for tid: String in deck_ids:
		var uid: String = add_card_instance(tid, "common")
		if uid != "":
			player_deck.append(uid)

## Load a multiplayer **session character** (GID-095 / TID-346) into the in-memory
## state that co-op and PvP already read (deck, collection, coins, level, skills,
## magic). The record comes from the authority's `SessionState` member roster — its
## own save, scoped to the session and entirely separate from single-player.
##
## **Isolation invariant:** this deliberately forces `_loaded = false`, so `save()`
## and the 2 s `_flush_if_dirty` stay no-ops for the whole session — the session
## character can NEVER be written into `save_slot_*.json`. The single-player save on
## disk is untouched; `continue_game`/`load_save` re-reads it fresh afterwards.
func adopt_session_character(record: Dictionary) -> void:
	owned_cards.clear()
	_uid_index.clear()
	var raw_owned: Array = record.get("owned_cards", [])
	for c: Variant in raw_owned:
		if not c is Dictionary:
			continue
		var inst: Dictionary = c
		owned_cards.append(inst)
		var u: String = str(inst.get("uid", ""))
		if u != "":
			_uid_index[u] = inst
	mailbox_cards.clear()
	var raw_mailbox: Array = record.get("mailbox_cards", [])
	for c: Variant in raw_mailbox:
		if c is Dictionary:
			mailbox_cards.append(c)
	player_deck.assign(record.get("player_deck", []))
	var deck_copy: Array[String] = []
	deck_copy.assign(player_deck)
	loadouts = [{"name": "Session", "cards": deck_copy}]
	active_loadout = 0
	coins = int(record.get("coins", 0))
	essence = int(record.get("essence", 0))
	xp = int(record.get("xp", 0))
	level = max(1, int(record.get("level", 1)))
	skill_points = int(record.get("skill_points", 0))
	unlocked_skills.assign(record.get("unlocked_skills", []))
	magic_type = str(record.get("magic_type", ""))
	corruption_points = int(record.get("corruption_points", 0))
	redemption_points = int(record.get("redemption_points", 0))
	# Hard isolation: a session character must never persist to the single-player save.
	_loaded = false
	_dirty = false
	coins_changed.emit(coins)
	GameBus.essence_changed.emit(essence)

## Snapshot the current in-memory character slice back into a session record dict
## (GID-095 / TID-346). The caller attaches token / display_name / position before
## sending it to the authority for persist-back. Shape matches
## `SessionState.make_starter_character` (minus the caller-owned fields).
func export_session_character() -> Dictionary:
	return {
		"owned_cards": owned_cards.duplicate(true),
		"mailbox_cards": mailbox_cards.duplicate(true),
		"player_deck": player_deck.duplicate(),
		"coins": coins,
		"essence": essence,
		"xp": xp,
		"level": level,
		"skill_points": skill_points,
		"unlocked_skills": unlocked_skills.duplicate(),
		"magic_type": magic_type,
		"corruption_points": corruption_points,
		"redemption_points": redemption_points,
	}

const CURRENT_SAVE_VERSION: int = 41

# Each entry is [target_version, payload] where payload is either:
#   Dictionary — {field: default} backfill applied when ver < target
#   Callable   — func(data: Dictionary) for non-trivial format changes (must bump data["version"])
# Entries are in ascending version order; ver is read once so all needed migrations
# run in a single pass even when multiple versions are skipped.
static func _apply_migrations(data: Dictionary) -> void:
	var ver: int = int(data.get("version", 0))

	var _m1: Callable = func(d: Dictionary) -> void:
		if not d.has("owned_cards"):
			d["owned_cards"] = d.get("player_deck", [])
		d["version"] = 1

	var _m10: Callable = func(d: Dictionary) -> void:
		const CardReg = preload("res://autoloads/CardRegistry.gd")
		var old_owned: Array = d.get("owned_cards", [])
		var old_deck: Array = d.get("player_deck", [])
		var new_instances: Array = []
		var counter: int = 0
		for item in old_owned:
			var tid: String = str(item)
			var tmpl: Dictionary = CardReg.get_template(tid)
			var uid: String = "%s_v10_%d" % [tid, counter]
			counter += 1
			new_instances.append({"uid": uid, "template_id": tid, "rarity": "common",
				"attack": int(tmpl.get("attack", 1)), "health": int(tmpl.get("health", 1)),
				"cost": int(tmpl.get("cost", 1))})
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
		d["owned_cards"] = new_instances
		d["player_deck"] = new_deck
		d["essence"] = 0
		d["version"] = 10

	var _m30: Callable = func(d: Dictionary) -> void:
		if d.has("owned_weapons"):
			var old_weapons: Array = d["owned_weapons"]
			var new_weapons: Array = []
			for item in old_weapons:
				if item is Dictionary:
					new_weapons.append(item)
				else:
					new_weapons.append({"weapon_id": str(item), "upgrade_level": 0})
			d["owned_weapons"] = new_weapons
		d["version"] = 30

	var _m34: Callable = func(d: Dictionary) -> void:
		if not d.has("loadouts"):
			var existing_deck: Array = d.get("player_deck", [])
			d["loadouts"] = [{"name": "Deck 1", "cards": existing_deck.duplicate()}]
			d["active_loadout"] = 0
		d["version"] = 34

	var _m35: Callable = func(d: Dictionary) -> void:
		var cards: Array = d.get("owned_cards", [])
		for i: int in range(cards.size()):
			if not cards[i] is Dictionary:
				continue
			var card: Dictionary = cards[i]
			if not card.has("kills"):            card["kills"] = 0
			if not card.has("battles_survived"): card["battles_survived"] = 0
			if not card.has("custom_name"):      card["custom_name"] = ""
		if not d.has("captured_signatures"):
			d["captured_signatures"] = []
		d["version"] = 35

	var table: Array = [
		[1,  _m1],
		[2,  {"world_seed": 42, "starting_biome": 0}],
		[3,  {"story_flags": {}}],
		[4,  {"days_elapsed": 0, "last_respawn_day": 0}],
		[5,  {"equipped_weapon": ""}],
		[6,  {"collected_scrolls": []}],
		[7,  {"owned_weapons": []}],
		[8,  {"settings": {}, "achievement_progress": {}, "unlocked_achievements": [], "visited_biomes": []}],
		[9,  {"visited_dungeon_rooms": []}],
		[10, _m10],
		[11, {"equipped_armor": "", "equipped_ring": "", "equipped_trinket": "",
			  "owned_armor": [], "owned_rings": [], "owned_trinkets": []}],
		[12, {"xp": 0, "level": 1, "skill_points": 0, "unlocked_skills": []}],
		[13, {"magic_type": "", "corruption_points": 0, "redemption_points": 0}],
		[14, {"pending_battle_state": {}}],
		[15, {"defeated_duelists": []}],
		[16, {"spire_run": {"active": false}}],
		[17, {"spire_best_floor": 0}],
		[18, {"solved_puzzles": [], "world_events": {}}],
		[19, {"weather": {"id": "", "duration": 0.0, "biome_id": 0}}],
		[20, {"treasure_fragments": 0, "active_treasure": {}, "treasures_completed": 0}],
		[21, {"activated_waystones": []}],
		[22, {"bestiary": {}, "bestiary_complete_rewarded": false, "home_owned": false}],
		[23, {"respawn_map": "", "respawn_x": 0.0, "respawn_z": 0.0}],
		[24, {"owned_mounts": [], "active_mount": "", "is_mounted": false}],
		[25, {"packs_since_legendary": 0}],
		[26, {"active_companion": ""}],
		[27, {"waypoint": {}}],
		[28, {"bounty_day": 0, "offered_bounties": [], "active_bounties": []}],
		[29, {"bag_size": IsoConst.BAG_SIZE_DEFAULT}],
		[30, _m30],
		[31, {"siege": {}, "last_siege_day": 0, "town_discounts": {}}],
		[32, {"rival_encounters_won": 0, "rival_defeated": false}],
		[33, {"garden_plots": [{}, {}, {}], "seeds": {}, "plants": {}, "potions": {}}],
		[34, _m34],
		[35, _m35],
		[36, {"cantrip_cooldowns": {}}],
		[37, {"dug_mounds": []}],
		[38, {"blight_cleansed_hearts": []}],
		[39, {"discovered_landmarks": []}],
		[40, {"collected_mana_wells": []}],
		[41, {"mailbox_cards": []}],
	]
	for entry: Array in table:
		var target: int = entry[0]
		var payload: Variant = entry[1]
		if ver < target:
			if payload is Dictionary:
				for k: String in (payload as Dictionary).keys():
					if not data.has(k):
						data[k] = (payload as Dictionary)[k]
				data["version"] = target
			elif payload is Callable:
				(payload as Callable).call(data)

static func _migrate_v15_to_v16(data: Dictionary) -> void:
	if not data.has("spire_run"):
		data["spire_run"] = {"active": false}
	data["version"] = 16

static func _migrate_v16_to_v17(data: Dictionary) -> void:
	if not data.has("spire_best_floor"):
		data["spire_best_floor"] = 0
	data["version"] = 17

static func _migrate_v19_to_v20(data: Dictionary) -> void:
	if not data.has("treasure_fragments"):
		data["treasure_fragments"] = 0
	if not data.has("active_treasure"):
		data["active_treasure"] = {}
	if not data.has("treasures_completed"):
		data["treasures_completed"] = 0
	data["version"] = 20

static func _migrate_v21_to_v22(data: Dictionary) -> void:
	if not data.has("bestiary"):
		data["bestiary"] = {}
	if not data.has("bestiary_complete_rewarded"):
		data["bestiary_complete_rewarded"] = false
	if not data.has("home_owned"):
		data["home_owned"] = false
	data["version"] = 22

static func _migrate_v22_to_v23(data: Dictionary) -> void:
	if not data.has("respawn_map"):
		data["respawn_map"] = ""
	if not data.has("respawn_x"):
		data["respawn_x"] = 0.0
	if not data.has("respawn_z"):
		data["respawn_z"] = 0.0
	data["version"] = 23

static func _migrate_v23_to_v24(data: Dictionary) -> void:
	if not data.has("owned_mounts"):
		data["owned_mounts"] = []
	if not data.has("active_mount"):
		data["active_mount"] = ""
	if not data.has("is_mounted"):
		data["is_mounted"] = false
	data["version"] = 24

static func _migrate_v24_to_v25(data: Dictionary) -> void:
	if not data.has("packs_since_legendary"):
		data["packs_since_legendary"] = 0
	data["version"] = 25

static func _migrate_v27_to_v28(data: Dictionary) -> void:
	if not data.has("bounty_day"):
		data["bounty_day"] = 0
	if not data.has("offered_bounties"):
		data["offered_bounties"] = []
	if not data.has("active_bounties"):
		data["active_bounties"] = []
	data["version"] = 28

static func _migrate_v29_to_v30(data: Dictionary) -> void:
	if data.has("owned_weapons"):
		var old_weapons: Array = data["owned_weapons"]
		var new_weapons: Array = []
		for item: Variant in old_weapons:
			if item is Dictionary:
				new_weapons.append(item)
			else:
				new_weapons.append({"weapon_id": str(item), "upgrade_level": 0})
		data["owned_weapons"] = new_weapons
	data["version"] = 30

static func _migrate_v30_to_v31(data: Dictionary) -> void:
	if not data.has("siege"):
		data["siege"] = {}
	if not data.has("last_siege_day"):
		data["last_siege_day"] = 0
	if not data.has("town_discounts"):
		data["town_discounts"] = {}
	data["version"] = 31

static func _migrate_v32_to_v33(data: Dictionary) -> void:
	if not data.has("garden_plots"):
		data["garden_plots"] = [{}, {}, {}]
	if not data.has("seeds"):
		data["seeds"] = {}
	if not data.has("plants"):
		data["plants"] = {}
	if not data.has("potions"):
		data["potions"] = {}
	data["version"] = 33

static func _migrate_v33_to_v34(data: Dictionary) -> void:
	if not data.has("loadouts"):
		var existing_deck: Array = data.get("player_deck", [])
		data["loadouts"] = [{"name": "Deck 1", "cards": existing_deck.duplicate()}]
		data["active_loadout"] = 0
	data["version"] = 34

static func _sign(payload: String) -> String:
	var crypto := Crypto.new()
	return crypto.hmac_digest(HashingContext.HASH_SHA256, _HMAC_SECRET.to_utf8_buffer(), payload.to_utf8_buffer()).hex_encode()

func _read_save_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var outer = JSON.parse_string(file.get_as_text())
	if not outer is Dictionary:
		return null
	if outer.has("payload"):
		var stored_hmac: String = str(outer.get("hmac", ""))
		var payload: String = str(outer.get("payload", ""))
		if stored_hmac != _sign(payload):
			push_warning("SaveManager: integrity check failed for %s" % path)
			return null
		var inner = JSON.parse_string(payload)
		if not inner is Dictionary:
			return null
		return inner
	return outer

func load_save() -> bool:
	var parsed = _read_save_json(_get_slot_path(active_slot))
	if parsed == null:
		parsed = _read_save_json(_get_slot_bak_path(active_slot))
	if parsed == null:
		return false
	var data: Dictionary = parsed
	_apply_migrations(data)
	owned_cards.assign(data.get("owned_cards", []))
	_uid_index.clear()
	for _card: Dictionary in owned_cards:
		var _uid: String = str(_card.get("uid", ""))
		if _uid != "":
			_uid_index[_uid] = _card
	mailbox_cards.assign(data.get("mailbox_cards", []))
	player_deck.assign(data.get("player_deck", []))
	# Load loadouts; fall back to wrapping player_deck if absent.
	var raw_loadouts: Array = data.get("loadouts", [])
	loadouts = []
	for _lo: Variant in raw_loadouts:
		if not _lo is Dictionary:
			continue
		var lo: Dictionary = _lo as Dictionary
		var lo_cards: Array[String] = []
		lo_cards.assign(lo.get("cards", []))
		loadouts.append({"name": str(lo.get("name", "Deck")), "cards": lo_cards})
	if loadouts.is_empty():
		var fallback: Array[String] = []
		fallback.assign(player_deck)
		loadouts = [{"name": "Deck 1", "cards": fallback}]
	active_loadout = int(data.get("active_loadout", 0))
	active_loadout = clampi(active_loadout, 0, loadouts.size() - 1)
	# Keep player_deck in sync with the active loadout.
	player_deck.assign(loadouts[active_loadout].get("cards", []))
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
	level = max(1, _compute_level(xp))
	skill_points = min(int(data.get("skill_points", 0)), max(0, level - 1))
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
	treasure_fragments = int(data.get("treasure_fragments", 0))
	var at = data.get("active_treasure", {})
	active_treasure = at if at is Dictionary else {}
	treasures_completed = int(data.get("treasures_completed", 0))
	activated_waystones.assign(data.get("activated_waystones", []))
	var bst = data.get("bestiary", {})
	bestiary = bst if bst is Dictionary else {}
	bestiary_complete_rewarded = bool(data.get("bestiary_complete_rewarded", false))
	home_owned = bool(data.get("home_owned", false))
	respawn_map = str(data.get("respawn_map", ""))
	respawn_x = float(data.get("respawn_x", 0.0))
	respawn_z = float(data.get("respawn_z", 0.0))
	owned_mounts.assign(data.get("owned_mounts", []))
	active_mount = str(data.get("active_mount", ""))
	is_mounted = bool(data.get("is_mounted", false))
	packs_since_legendary = int(data.get("packs_since_legendary", 0))
	active_companion = str(data.get("active_companion", ""))
	var wp = data.get("waypoint", {})
	waypoint = wp if wp is Dictionary else {}
	bounty_day = int(data.get("bounty_day", 0))
	offered_bounties.assign(data.get("offered_bounties", []))
	active_bounties.assign(data.get("active_bounties", []))
	bag_size = int(data.get("bag_size", IsoConst.BAG_SIZE_DEFAULT))
	var sg = data.get("siege", {})
	siege = sg if sg is Dictionary else {}
	last_siege_day = int(data.get("last_siege_day", 0))
	var td = data.get("town_discounts", {})
	town_discounts = td if td is Dictionary else {}
	rival_encounters_won = int(data.get("rival_encounters_won", 0))
	rival_defeated = bool(data.get("rival_defeated", false))
	garden_plots.assign(data.get("garden_plots", [{}, {}, {}]))
	var gsd = data.get("seeds", {}); seeds = gsd if gsd is Dictionary else {}
	var gpd = data.get("plants", {}); plants = gpd if gpd is Dictionary else {}
	var gpotd = data.get("potions", {}); potions = gpotd if gpotd is Dictionary else {}
	captured_signatures.assign(data.get("captured_signatures", []))
	var cc = data.get("cantrip_cooldowns", {}); cantrip_cooldowns = cc if cc is Dictionary else {}
	dug_mounds.assign(data.get("dug_mounds", []))
	blight_cleansed_hearts.assign(data.get("blight_cleansed_hearts", []))
	discovered_landmarks.assign(data.get("discovered_landmarks", []))
	collected_mana_wells.assign(data.get("collected_mana_wells", []))
	last_saved = str(data.get("last_saved", ""))
	_achievement_slot = active_slot
	_loaded = true
	return true

func save() -> void:
	if not _loaded:
		return
	# Sync active loadout from player_deck before serialising.
	if active_loadout >= 0 and active_loadout < loadouts.size():
		var synced: Array[String] = []
		synced.assign(player_deck)
		loadouts[active_loadout]["cards"] = synced
	var data := {
		"version": CURRENT_SAVE_VERSION,
		"owned_cards": owned_cards,
		"mailbox_cards": mailbox_cards,
		"player_deck": player_deck,
		"loadouts": loadouts,
		"active_loadout": active_loadout,
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
		"treasure_fragments": treasure_fragments,
		"active_treasure": active_treasure,
		"treasures_completed": treasures_completed,
		"activated_waystones": activated_waystones,
		"bestiary": bestiary,
		"bestiary_complete_rewarded": bestiary_complete_rewarded,
		"home_owned": home_owned,
		"respawn_map": respawn_map,
		"respawn_x": respawn_x,
		"respawn_z": respawn_z,
		"owned_mounts": owned_mounts,
		"active_mount": active_mount,
		"is_mounted": is_mounted,
		"packs_since_legendary": packs_since_legendary,
		"active_companion": active_companion,
		"waypoint": waypoint,
		"bounty_day": bounty_day,
		"offered_bounties": offered_bounties,
		"active_bounties": active_bounties,
		"bag_size": bag_size,
		"siege": siege,
		"last_siege_day": last_siege_day,
		"town_discounts": town_discounts,
		"rival_encounters_won": rival_encounters_won,
		"rival_defeated": rival_defeated,
		"garden_plots": garden_plots,
		"seeds": seeds,
		"plants": plants,
		"potions": potions,
		"captured_signatures": captured_signatures,
		"cantrip_cooldowns": cantrip_cooldowns,
		"dug_mounds": dug_mounds,
		"blight_cleansed_hearts": blight_cleansed_hearts,
		"discovered_landmarks": discovered_landmarks,
		"collected_mana_wells": collected_mana_wells,
		"last_saved": Time.get_datetime_string_from_system(false, true),
	}
	var save_path: String = _get_slot_path(active_slot)
	var tmp_path: String = _get_slot_tmp_path(active_slot)
	var bak_path: String = _get_slot_bak_path(active_slot)
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not tmp:
		return
	var inner_json: String = JSON.stringify(data, "\t")
	tmp.store_string(JSON.stringify({"hmac": _sign(inner_json), "payload": inner_json}))
	tmp = null  # flush + close before rename
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, bak_path)
	DirAccess.rename_absolute(tmp_path, save_path)
	last_saved = str(data.get("last_saved", ""))

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
	_dirty = true

func add_coins(amount: int) -> void:
	if coins == 0 and amount > 0:
		GameBus.tutorial_popup_requested.emit("coins")
	coins += amount
	_dirty = true
	coins_changed.emit(coins)

func set_waypoint(wp: Dictionary) -> void:
	waypoint = wp
	_dirty = true
	GameBus.waypoint_changed.emit(wp)

func increment_pity() -> void:
	packs_since_legendary += 1
	_dirty = true

func reset_pity() -> void:
	packs_since_legendary = 0
	_dirty = true

## Compatibility shim: creates a common-rarity instance from each template ID and
## adds it to the collection. Callers that already do a rarity roll should use
## add_card_instance() directly instead.
func add_cards_to_deck(card_ids: Array[String]) -> void:
	for tid: String in card_ids:
		grant_card_reward(tid, "common")
	if card_ids.size() > 0:
		increment_progress("cards_earned", card_ids.size())

func grant_achievement_card(card_id: String) -> void:
	# Only grant if the player doesn't own any copy yet.
	for inst: Dictionary in owned_cards:
		if str(inst.get("template_id", "")) == card_id:
			return
	grant_card_reward(card_id, "common")

func set_active_deck(new_deck: Array[String]) -> void:
	player_deck.assign(new_deck)
	if active_loadout >= 0 and active_loadout < loadouts.size():
		var synced: Array[String] = []
		synced.assign(player_deck)
		loadouts[active_loadout]["cards"] = synced
	_dirty = true

## Counts backpack slots used: every owned instance takes 1 slot, except cards
## currently in the active deck (or `deck_uids`, if given) — those live in the
## deck, not the backpack. Each instance has its own rolled stats even at the
## same rarity, so commons no longer stack into a single slot.
func get_slot_count(deck_uids: Array = []) -> int:
	var excluded: Array = deck_uids if not deck_uids.is_empty() else player_deck
	var count: int = 0
	for inst: Dictionary in owned_cards:
		if not excluded.has(str(inst.get("uid", ""))):
			count += 1
	return count

func is_bag_full() -> bool:
	return get_slot_count() >= bag_size

## Creates a new card instance with the given stats and appends it to owned_cards.
## Returns the generated UID, or "" if the bag is full (emits GameBus.bag_full).
## attack/health/cost default to the card template's base stats.
func add_card_instance(template_id: String, rarity: String, attack: int = -1, health: int = -1, cost: int = -1) -> String:
	if is_bag_full():
		GameBus.bag_full.emit()
		return ""
	var tmpl: Dictionary = CardRegistry.get_template(template_id)
	var atk: int = attack if attack >= 0 else int(tmpl.get("attack", 0))
	var hp: int  = health if health >= 0 else int(tmpl.get("health", 0))
	var c: int   = cost   if cost   >= 0 else int(tmpl.get("cost", 1))
	var uid: String = _gen_uid(template_id)
	# Canonical instance shape shared with SessionState (GID-095) via CardInstanceUtil
	# so save.json and the multiplayer session files never diverge.
	var inst_dict: Dictionary = _CardInstanceUtil.make(uid, template_id, rarity, atk, hp, c)
	owned_cards.append(inst_dict)
	_uid_index[uid] = inst_dict
	if rarity != "common":
		GameBus.tutorial_popup_requested.emit("card_rarity")
	_dirty = true
	return uid

## Routes an automatic reward (battle win, chest, dig, achievement, story/quest, pack) into
## owned_cards, or into the mailbox overflow queue when the bag is full, instead of dropping
## it. Same call signature as add_card_instance so callers are a mechanical rename. Always
## returns the generated uid — the card exists either way, just not always in the bag yet.
## Player-initiated spends (shop, craft, combine) should keep calling add_card_instance,
## which still blocks on a full bag.
func grant_card_reward(template_id: String, rarity: String, attack: int = -1, health: int = -1, cost: int = -1) -> String:
	var tmpl: Dictionary = CardRegistry.get_template(template_id)
	var atk: int = attack if attack >= 0 else int(tmpl.get("attack", 0))
	var hp: int  = health if health >= 0 else int(tmpl.get("health", 0))
	var c: int   = cost   if cost   >= 0 else int(tmpl.get("cost", 1))
	var uid: String = _gen_uid(template_id)
	var inst_dict: Dictionary = _CardInstanceUtil.make(uid, template_id, rarity, atk, hp, c)
	if is_bag_full():
		mailbox_cards.append(inst_dict)
		GameBus.card_routed_to_mailbox.emit(template_id)
		_dirty = true
		return uid
	owned_cards.append(inst_dict)
	_uid_index[uid] = inst_dict
	if rarity != "common":
		GameBus.tutorial_popup_requested.emit("card_rarity")
	_dirty = true
	return uid

## Returns all card instances currently held in the mailbox overflow queue.
func get_mailbox_instances() -> Array[Dictionary]:
	return mailbox_cards

## Moves a mailbox card into the bag. Returns false (no-op) if the uid isn't in the
## mailbox or the bag is still full.
func claim_mailbox_card(uid: String) -> bool:
	if is_bag_full():
		return false
	var idx: int = -1
	for i in range(mailbox_cards.size()):
		if str(mailbox_cards[i].get("uid", "")) == uid:
			idx = i
			break
	if idx < 0:
		return false
	var inst: Dictionary = mailbox_cards[idx]
	mailbox_cards.remove_at(idx)
	owned_cards.append(inst)
	_uid_index[uid] = inst
	_dirty = true
	return true

## Claims as many mailbox cards as fit in the bag. Returns the number claimed.
func claim_all_mailbox_cards() -> int:
	var claimed: int = 0
	while not mailbox_cards.is_empty():
		var uid: String = str(mailbox_cards[0].get("uid", ""))
		if not claim_mailbox_card(uid):
			break
		claimed += 1
	return claimed

## Sells a mailbox card for gold. No-op if uid not found.
func sell_mailbox_card(uid: String) -> void:
	var idx: int = -1
	for i in range(mailbox_cards.size()):
		if str(mailbox_cards[i].get("uid", "")) == uid:
			idx = i
			break
	if idx < 0:
		return
	var rarity: String = str(mailbox_cards[idx].get("rarity", "common"))
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	add_coins(int(cfg.get("sell_gold", 0)))
	mailbox_cards.remove_at(idx)
	_dirty = true

## Scraps a mailbox card for essence. No-op if uid not found.
func scrap_mailbox_card(uid: String) -> void:
	var idx: int = -1
	for i in range(mailbox_cards.size()):
		if str(mailbox_cards[i].get("uid", "")) == uid:
			idx = i
			break
	if idx < 0:
		return
	var rarity: String = str(mailbox_cards[idx].get("rarity", "common"))
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	if essence == 0:
		GameBus.tutorial_popup_requested.emit("essence")
	essence += int(cfg.get("scrap_essence", 0))
	GameBus.essence_changed.emit(essence)
	mailbox_cards.remove_at(idx)
	_dirty = true

## Removes a card instance by UID from owned_cards, player_deck, and all loadouts.
func remove_card_instance(uid: String) -> void:
	_uid_index.erase(uid)
	for i in range(owned_cards.size() - 1, -1, -1):
		if str(owned_cards[i].get("uid", "")) == uid:
			owned_cards.remove_at(i)
			break
	var deck_idx: int = player_deck.find(uid)
	if deck_idx >= 0:
		player_deck.remove_at(deck_idx)
	for i in range(loadouts.size()):
		var lo_cards: Array = loadouts[i].get("cards", [])
		var lo_idx: int = lo_cards.find(uid)
		if lo_idx >= 0:
			lo_cards.remove_at(lo_idx)
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
	var src_idx: int = IsoConst.RARITY_ORDER.find(rarity)
	if src_idx < 0 or src_idx >= IsoConst.RARITY_ORDER.size() - 1:
		return {}
	var next_rarity: String = IsoConst.RARITY_ORDER[src_idx + 1]
	var stats: Dictionary = CardDropUtil.roll_stats(template_id, next_rarity)
	var new_uid: String = add_card_instance(template_id, next_rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
	return get_instance_by_uid(new_uid)

## Returns all owned card instances (the full collection array).
func get_owned_instances() -> Array[Dictionary]:
	return owned_cards

## Returns the instance dict for a UID, or {} if not found.
func get_instance_by_uid(uid: String) -> Dictionary:
	var hit: Variant = _uid_index.get(uid, null)
	if hit is Dictionary:
		return hit as Dictionary
	return {}

## Returns instance dicts for each UID in player_deck (skips missing UIDs).
func get_deck_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for uid: String in player_deck:
		var inst: Dictionary = get_instance_by_uid(uid)
		if not inst.is_empty():
			result.append(inst)
	return result

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

const REDEMPTION_FLAG_AWARDS: Dictionary = {
	"chapter1_left_madrian": 5,
	"chapter1_reached_blancogov": 10,
	"chapter1_received_letter": 10,
	"chapter1_temple_council": 10,
	"champion_blancogov_defeated": 15,
	"bestiary_complete": 10,
}

func set_story_flag(key: String, value: bool = true) -> void:
	var was_unset: bool = not story_flags.get(key, false)
	story_flags[key] = value
	_dirty = true
	GameBus.story_flag_set.emit(key)
	if value:
		check_flag_achievement(key)
		if was_unset and REDEMPTION_FLAG_AWARDS.has(key):
			add_redemption_points(int(REDEMPTION_FLAG_AWARDS[key]))

func get_story_flag(key: String) -> bool:
	return story_flags.get(key, false)

func mark_scroll_collected(scroll_id: String) -> void:
	if not collected_scrolls.has(scroll_id):
		collected_scrolls.append(scroll_id)
	_dirty = true

func is_scroll_collected(scroll_id: String) -> bool:
	return collected_scrolls.has(scroll_id)

func mark_signature_captured(card_id: String) -> void:
	if card_id != "" and not captured_signatures.has(card_id):
		captured_signatures.append(card_id)
	_dirty = true

func is_signature_captured(card_id: String) -> bool:
	return card_id != "" and captured_signatures.has(card_id)

func add_weapon(weapon_id: String) -> void:
	if not _has_weapon_id(weapon_id):
		owned_weapons.append({"weapon_id": weapon_id, "upgrade_level": 0})
	_dirty = true

func _has_weapon_id(weapon_id: String) -> bool:
	for inst: Dictionary in owned_weapons:
		if str(inst.get("weapon_id", "")) == weapon_id:
			return true
	return false

func equip_weapon(weapon_id: String) -> void:
	equipped_weapon = weapon_id
	_dirty = true

## Adds an equipment item to the appropriate owned array based on its slot.
## slot must be "weapon", "armor", "ring", or "trinket".
func add_equipment(item_id: String, slot: String) -> void:
	match slot:
		"weapon":
			if not _has_weapon_id(item_id):
				owned_weapons.append({"weapon_id": item_id, "upgrade_level": 0})
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
## For "weapon", extracts weapon_id strings from the dict instances.
func get_owned_by_slot(slot: String) -> Array[String]:
	match slot:
		"weapon":
			var ids: Array[String] = []
			for inst: Dictionary in owned_weapons:
				ids.append(str(inst.get("weapon_id", "")))
			return ids
		"armor":   return owned_armor
		"ring":    return owned_rings
		"trinket": return owned_trinkets
	return []

## Returns the owned_weapons instance dict for weapon_id, or a default level-0 dict if absent.
func get_owned_weapon_by_id(weapon_id: String) -> Dictionary:
	for inst: Dictionary in owned_weapons:
		if str(inst.get("weapon_id", "")) == weapon_id:
			return inst
	return {"weapon_id": weapon_id, "upgrade_level": 0}

## Upgrades the first matching weapon instance by one level.
## Deducts coins and essence; returns false if already at max or insufficient funds.
func upgrade_weapon(weapon_id: String) -> bool:
	const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
	for i: int in range(owned_weapons.size()):
		if str(owned_weapons[i].get("weapon_id", "")) != weapon_id:
			continue
		var current_level: int = int(owned_weapons[i].get("upgrade_level", 0))
		if current_level >= UpgradeDefs.MAX_LEVEL:
			return false
		if not UpgradeDefs.can_afford_upgrade(current_level, coins, essence):
			return false
		add_coins(-UpgradeDefs.cost_coins(current_level))
		essence -= UpgradeDefs.cost_essence(current_level)
		GameBus.essence_changed.emit(essence)
		owned_weapons[i]["upgrade_level"] = current_level + 1
		_dirty = true
		GameBus.weapon_upgraded.emit(weapon_id, current_level + 1)
		return true
	return false

## Salvages the first unequipped instance of weapon_id.
## Returns {coins, essence} earned, or {} if refused (equipped or not found).
func salvage_weapon(weapon_id: String) -> Dictionary:
	const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
	if equipped_weapon == weapon_id or equipped_armor == weapon_id \
			or equipped_ring == weapon_id or equipped_trinket == weapon_id:
		return {}
	for i: int in range(owned_weapons.size()):
		if str(owned_weapons[i].get("weapon_id", "")) != weapon_id:
			continue
		owned_weapons.remove_at(i)
		var coins_earned: int = UpgradeDefs.SALVAGE_COINS
		var essence_earned: int = UpgradeDefs.SALVAGE_ESSENCE
		add_coins(coins_earned)
		essence += essence_earned
		GameBus.essence_changed.emit(essence)
		GameBus.weapon_salvaged.emit(weapon_id, coins_earned, essence_earned)
		_dirty = true
		return {"coins": coins_earned, "essence": essence_earned}
	return {}

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
	if skill_points <= 0:
		return
	unlocked_skills.append(id)
	skill_points -= 1
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

func summon_mount(mount_id: String) -> void:
	if not owned_mounts.has(mount_id):
		return
	active_mount = mount_id
	is_mounted = true
	_dirty = true
	GameBus.mount_state_changed.emit(true, mount_id)

func dismiss_mount() -> void:
	var prev_id: String = active_mount
	active_mount = ""
	is_mounted = false
	_dirty = true
	GameBus.mount_state_changed.emit(false, prev_id)

func auto_dismiss_mount() -> void:
	# Used for battle/map-entry auto-dismount. Preserves active_mount so remount
	# can happen automatically when returning to the overworld.
	is_mounted = false
	_dirty = true
	GameBus.mount_state_changed.emit(false, active_mount)

## Records kills and (optionally) a battles_survived increment for a collection instance.
## No-op if the uid is not found in owned_cards.
func record_veterancy(uid: String, kills: int, survived: bool) -> void:
	var inst: Dictionary = get_instance_by_uid(uid)
	if inst.is_empty():
		return
	inst["kills"] = int(inst.get("kills", 0)) + kills
	if survived:
		inst["battles_survived"] = int(inst.get("battles_survived", 0)) + 1
	_dirty = true

## Sets a custom display name on a collection instance. Empty string clears the custom name.
## No-op if the uid is not found.
func set_card_custom_name(uid: String, custom_name: String) -> void:
	var inst: Dictionary = get_instance_by_uid(uid)
	if inst.is_empty():
		return
	inst["custom_name"] = custom_name.strip_edges().left(24)
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
	_achievement_dirty = true

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
	_achievement_dirty = true

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

func collect_treasure_fragment() -> void:
	treasure_fragments += 1
	_dirty = true
	GameBus.fragment_collected.emit()
	if treasure_fragments >= 3:
		_assemble_treasure_map()

func _assemble_treasure_map() -> void:
	const TreasureGen = preload("res://game_logic/world/TreasureGen.gd")
	treasure_fragments = 0
	var site: Vector2i = TreasureGen.get_dig_site(world_seed, treasures_completed)
	active_treasure = {"site_x": site.x, "site_z": site.y, "completed": false}
	_dirty = true
	GameBus.treasure_map_assembled.emit()

func complete_treasure(coins: int, card_id: String) -> void:
	if active_treasure.is_empty():
		return
	active_treasure["completed"] = true
	treasures_completed += 1
	_dirty = true
	GameBus.treasure_excavated.emit(coins, card_id)

func activate_waystone(waystone_id: String) -> void:
	if not activated_waystones.has(waystone_id):
		activated_waystones.append(waystone_id)
	_dirty = true

func is_waystone_activated(waystone_id: String) -> bool:
	return activated_waystones.has(waystone_id)

func record_enemy_seen(type_id: String) -> void:
	if not bestiary.has(type_id):
		bestiary[type_id] = {"seen": 0, "defeated": 0}
	bestiary[type_id]["seen"] = int(bestiary[type_id]["seen"]) + 1
	mark_dirty()

func record_enemy_defeated(type_id: String) -> void:
	if not bestiary.has(type_id):
		bestiary[type_id] = {"seen": 0, "defeated": 0}
	bestiary[type_id]["defeated"] = int(bestiary[type_id]["defeated"]) + 1
	mark_dirty()
	_check_bestiary_complete()

func get_bestiary_entry(type_id: String) -> Dictionary:
	return bestiary.get(type_id, {"seen": 0, "defeated": 0})

func is_bestiary_complete() -> bool:
	var eligible: Array[String] = _EnemyRegistry.get_bestiary_enemy_ids()
	if eligible.is_empty():
		return false
	for type_id: String in eligible:
		var entry: Dictionary = bestiary.get(type_id, {"seen": 0, "defeated": 0})
		if int(entry.get("defeated", 0)) < 1:
			return false
	return true

func _check_bestiary_complete() -> void:
	if bestiary_complete_rewarded:
		return
	if not is_bestiary_complete():
		return
	bestiary_complete_rewarded = true
	add_coins(500)
	grant_card_reward("soul_harvest", "legendary")
	set_story_flag("bestiary_complete")

func set_respawn_point(map: String, x: float, z: float) -> void:
	respawn_map = map
	respawn_x = x
	respawn_z = z
	_dirty = true

func has_respawn_point() -> bool:
	return respawn_map != "" and home_owned

func equip_companion(companion_id: String) -> void:
	active_companion = companion_id
	_dirty = true

func unequip_companion() -> void:
	active_companion = ""
	_dirty = true

## Starts a new siege for the given town. Initialises stage 0, hero_hp 30.
func start_siege(town: String) -> void:
	siege = {"town": town, "stage": 0, "hero_hp": 30, "day_started": days_elapsed}
	_dirty = true

## Returns the active siege dict, or {} when no siege is in progress.
func get_active_siege() -> Dictionary:
	return siege

## Advances the siege stage by 1 (0 → 1 → 2). No-op if siege is empty.
func advance_siege_stage() -> void:
	if siege.is_empty():
		return
	siege["stage"] = int(siege.get("stage", 0)) + 1
	_dirty = true

## Stores the player's hero HP so it carries over to the next gauntlet stage.
func set_siege_hero_hp(hp: int) -> void:
	if siege.is_empty():
		return
	siege["hero_hp"] = hp
	_dirty = true

## Records a siege win: updates last_siege_day, applies town discount, clears active siege.
func end_siege_victory() -> void:
	var town: String = str(siege.get("town", ""))
	last_siege_day = days_elapsed
	if town != "":
		apply_town_discount(town)
	siege = {}
	_dirty = true

## Records a siege loss: updates last_siege_day, clears active siege (no discount).
func end_siege_defeat() -> void:
	last_siege_day = days_elapsed
	siege = {}
	_dirty = true

## Applies a 3-day gratitude discount to the named town.
func apply_town_discount(town: String) -> void:
	town_discounts[town] = days_elapsed + 3
	_dirty = true

## Returns true if the named town currently has an active gratitude discount.
func is_town_discounted(town: String) -> bool:
	return int(town_discounts.get(town, -1)) >= days_elapsed

func record_rival_win() -> void:
	rival_encounters_won = mini(rival_encounters_won + 1, 2)
	_dirty = true

func set_rival_defeated() -> void:
	rival_defeated = true
	_dirty = true

# -------------------------------------------------------------------------
# Garden helpers (GID-056)
# -------------------------------------------------------------------------

func set_plot(plot_idx: int, seed_id: String, planted_day: int) -> void:
	if plot_idx < 0 or plot_idx >= garden_plots.size():
		return
	garden_plots[plot_idx] = {"seed_id": seed_id, "planted_day": planted_day}
	_dirty = true

func clear_plot(plot_idx: int) -> void:
	if plot_idx < 0 or plot_idx >= garden_plots.size():
		return
	garden_plots[plot_idx] = {}
	_dirty = true

func add_seeds(seed_id: String, count: int) -> void:
	seeds[seed_id] = int(seeds.get(seed_id, 0)) + count
	_dirty = true
	GameBus.inventory_changed.emit()

func remove_seeds(seed_id: String, count: int) -> bool:
	var current: int = int(seeds.get(seed_id, 0))
	if current < count:
		return false
	seeds[seed_id] = current - count
	_dirty = true
	return true

func add_plants(plant_id: String, count: int) -> void:
	plants[plant_id] = int(plants.get(plant_id, 0)) + count
	_dirty = true

func remove_plants(plant_id: String, count: int) -> bool:
	var current: int = int(plants.get(plant_id, 0))
	if current < count:
		return false
	plants[plant_id] = current - count
	_dirty = true
	return true

func add_potions(potion_id: String, count: int) -> void:
	potions[potion_id] = int(potions.get(potion_id, 0)) + count
	_dirty = true

func remove_potions(potion_id: String, count: int) -> bool:
	var current: int = int(potions.get(potion_id, 0))
	if current < count:
		return false
	potions[potion_id] = current - count
	_dirty = true
	return true

func get_plot_growth_stage(plot_idx: int) -> int:
	if plot_idx < 0 or plot_idx >= garden_plots.size():
		return 0
	var plot: Dictionary = garden_plots[plot_idx]
	if plot.is_empty() or not plot.has("seed_id"):
		return 0
	const GardenDefs = preload("res://game_logic/GardenDefs.gd")
	var seed_id: String = str(plot.get("seed_id", ""))
	var seed_def: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
	if seed_def.is_empty():
		return 0
	var growth_days: int = int(seed_def.get("growth_days", 1))
	var planted_day: int = int(plot.get("planted_day", 0))
	return GardenDefs.growth_stage(planted_day, growth_days, days_elapsed)

func increment_day() -> void:
	days_elapsed += 1
	if days_elapsed - last_respawn_day >= IsoConst.ENEMY_RESPAWN_DAYS:
		var kept: Array[String] = []
		for eid: String in defeated_enemies:
			if eid.begins_with("map_"):
				kept.append(eid)
		defeated_enemies.assign(kept)
		last_respawn_day = days_elapsed
	# Siege timeout: clear any siege that has not been engaged for 1 full day.
	if not siege.is_empty():
		var age: int = days_elapsed - int(siege.get("day_started", 0))
		if age >= 1:
			end_siege_defeat()   # town held out; no coin penalty
	# Clean up expired town discounts.
	var expired_towns: Array[String] = []
	for town_key: String in town_discounts.keys():
		if int(town_discounts[town_key]) < days_elapsed:
			expired_towns.append(town_key)
	for town_key: String in expired_towns:
		town_discounts.erase(town_key)
	_refresh_bounties()
	_dirty = true

func _refresh_bounties() -> void:
	if days_elapsed == bounty_day and not offered_bounties.is_empty():
		return
	if days_elapsed < bounty_day:
		return
	const BountyGen = preload("res://game_logic/BountyGen.gd")
	offered_bounties.clear()
	var daily: Array[Dictionary] = BountyGen.generate_daily(world_seed, days_elapsed)
	for b: Dictionary in daily:
		var entry: Dictionary = b.duplicate()
		entry["offered_at_day"] = days_elapsed
		offered_bounties.append(entry)
	bounty_day = days_elapsed
	_dirty = true

## Returns today's offered bounties, refreshing if the day has rolled over.
func get_offered_bounties() -> Array[Dictionary]:
	_refresh_bounties()
	return offered_bounties

## Returns active (accepted, in-progress) bounties.
func get_active_bounties() -> Array[Dictionary]:
	return active_bounties

## Accepts a bounty by id. Moves it from offered_bounties to active_bounties.
## Returns false if bounty not found in offered or 3 bounties are already active.
func accept_bounty(bounty_id: String) -> bool:
	if active_bounties.size() >= 3:
		return false
	var found_idx: int = -1
	for i: int in range(offered_bounties.size()):
		if str(offered_bounties[i].get("id", "")) == bounty_id:
			found_idx = i
			break
	if found_idx < 0:
		return false
	var entry: Dictionary = offered_bounties[found_idx].duplicate()
	entry["accepted_at_day"] = days_elapsed
	entry["progress"] = 0
	entry["claimed"] = false
	active_bounties.append(entry)
	offered_bounties.remove_at(found_idx)
	_dirty = true
	return true

## Claims a completed bounty by id. Pays out coins and marks it as claimed.
## Returns the coin reward if successful, or 0 if not found / not yet complete / already claimed.
## Increments progress for all active bounties that match the given type and data.
## bounty_type: "defeat_enemy_type" | "defeat_in_biome" | "open_chests"
## match_data: {"enemy_type": String} | {"biome_name": String} | {}
func increment_bounty_progress(bounty_type: String, match_data: Dictionary) -> void:
	var changed: bool = false
	for i: int in range(active_bounties.size()):
		var b: Dictionary = active_bounties[i]
		if bool(b.get("claimed", false)) or bool(b.get("completed", false)):
			continue
		if str(b.get("type", "")) != bounty_type:
			continue
		var matches: bool = false
		match bounty_type:
			"defeat_enemy_type":
				matches = str(b.get("target", "")) == str(match_data.get("enemy_type", ""))
			"defeat_in_biome":
				matches = str(b.get("target", "")) == str(match_data.get("biome_name", ""))
			"open_chests":
				matches = true
		if not matches:
			continue
		active_bounties[i]["progress"] = int(b.get("progress", 0)) + 1
		var new_progress: int = int(active_bounties[i]["progress"])
		var needed: int = int(b.get("count", 1))
		var bid: String = str(b.get("id", ""))
		if new_progress >= needed:
			active_bounties[i]["completed"] = true
			GameBus.bounty_completed.emit(bid)
		GameBus.bounty_progress_changed.emit(bid, new_progress, needed)
		changed = true
	if changed:
		_dirty = true

func claim_bounty(bounty_id: String) -> int:
	for i: int in range(active_bounties.size()):
		var b: Dictionary = active_bounties[i]
		if str(b.get("id", "")) != bounty_id:
			continue
		if bool(b.get("claimed", false)):
			return 0
		var needed: int = int(b.get("count", 0))
		var done: int = int(b.get("progress", 0))
		if done < needed:
			return 0
		active_bounties[i]["claimed"] = true
		var reward: int = int(b.get("reward", 0))
		add_coins(reward)
		_dirty = true
		return reward
	return 0

# -------------------------------------------------------------------------
# Loadout helpers (GID-058)
# -------------------------------------------------------------------------

## Returns true if the loadout at index has a card count within [DECK_MIN, DECK_MAX].
func is_loadout_valid(index: int) -> bool:
	if index < 0 or index >= loadouts.size():
		return false
	var cards: Array = loadouts[index].get("cards", [])
	return cards.size() >= IsoConst.DECK_MIN and cards.size() <= IsoConst.DECK_MAX

## Returns the list of loadout names in order.
func get_loadout_names() -> Array[String]:
	var names: Array[String] = []
	for lo: Dictionary in loadouts:
		names.append(str(lo.get("name", "Deck")))
	return names

## Switches the active loadout; syncs player_deck to the new loadout's cards.
## Returns false if the index is out of range.
func set_active_loadout(index: int) -> bool:
	if index < 0 or index >= loadouts.size():
		return false
	active_loadout = index
	player_deck.assign(loadouts[active_loadout].get("cards", []))
	_dirty = true
	return true

## Creates a new empty loadout with the given name (max MAX_LOADOUTS).
## Returns the new index, or -1 if the limit is reached.
func add_loadout(name: String) -> int:
	if loadouts.size() >= MAX_LOADOUTS:
		return -1
	loadouts.append({"name": name, "cards": []})
	_dirty = true
	return loadouts.size() - 1

## Renames the loadout at index. No-op if out of range.
func rename_loadout(index: int, new_name: String) -> void:
	if index < 0 or index >= loadouts.size():
		return
	loadouts[index]["name"] = new_name
	_dirty = true

## Duplicates the loadout at index and appends it (max MAX_LOADOUTS).
## Returns the new index, or -1 if the limit is reached.
func duplicate_loadout(index: int) -> int:
	if index < 0 or index >= loadouts.size():
		return -1
	if loadouts.size() >= MAX_LOADOUTS:
		return -1
	var src: Dictionary = loadouts[index]
	var copy_cards: Array[String] = []
	copy_cards.assign(src.get("cards", []))
	var copy_name: String = str(src.get("name", "Deck")) + " (Copy)"
	loadouts.append({"name": copy_name, "cards": copy_cards})
	_dirty = true
	return loadouts.size() - 1

## Deletes the loadout at index. The last remaining loadout cannot be deleted.
## If deleting the active loadout, switches to the nearest valid index.
## Returns false if refused (last loadout or out of range).
func delete_loadout(index: int) -> bool:
	if loadouts.size() <= 1:
		return false
	if index < 0 or index >= loadouts.size():
		return false
	loadouts.remove_at(index)
	if active_loadout >= loadouts.size():
		active_loadout = loadouts.size() - 1
	player_deck.assign(loadouts[active_loadout].get("cards", []))
	_dirty = true
	return true

# -------------------------------------------------------------------------
# Blight system (GID-066)
# -------------------------------------------------------------------------

func mark_heart_cleansed(heart_id: String) -> void:
	if not blight_cleansed_hearts.has(heart_id):
		blight_cleansed_hearts.append(heart_id)
	_dirty = true

func is_heart_cleansed(heart_id: String) -> bool:
	return blight_cleansed_hearts.has(heart_id)

# -------------------------------------------------------------------------
# Landmark discovery (GID-067)
# -------------------------------------------------------------------------

func mark_landmark_discovered(landmark_id: String) -> void:
	if not discovered_landmarks.has(landmark_id):
		discovered_landmarks.append(landmark_id)
	_dirty = true

func is_landmark_discovered(landmark_id: String) -> bool:
	return discovered_landmarks.has(landmark_id)

func mark_mana_well_collected(well_id: String) -> void:
	if not collected_mana_wells.has(well_id):
		collected_mana_wells.append(well_id)
	_dirty = true

func is_mana_well_collected(well_id: String) -> bool:
	return collected_mana_wells.has(well_id)
