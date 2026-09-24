## Save-file schema migrations. `apply()` walks one table that upgrades a parsed
## save dictionary from any older version to CURRENT_VERSION in a single pass.
## Pure: no Node or filesystem access, so the tests run it on plain dicts.
##
## Adding a version means bumping CURRENT_VERSION and appending one table row:
## a `{field: default}` Dictionary backfill (it never overwrites an existing key),
## or a Callable for a real format change (that must set `d["version"]` itself).
## `test_save_migrations` fails if the last row and CURRENT_VERSION disagree.
extends RefCounted

const CardRegistry = preload("res://autoloads/CardRegistry.gd")

const CURRENT_VERSION: int = 41


## Upgrades `data` in place. `up_to` stops after that version's row. The game
## always migrates to the current version; tests use `up_to` to check one step
## of the real table in isolation.
static func apply(data: Dictionary, up_to: int = CURRENT_VERSION) -> void:
	var ver: int = int(data.get("version", 0))
	for entry: Array in table():
		var target: int = entry[0]
		if target > up_to:
			break
		if ver >= target:
			continue
		var payload: Variant = entry[1]
		if payload is Dictionary:
			for k: String in (payload as Dictionary).keys():
				if not data.has(k):
					data[k] = (payload as Dictionary)[k]
			data["version"] = target
		elif payload is Callable:
			(payload as Callable).call(data)


## `[target_version, payload]` rows in ascending version order.
static func table() -> Array:
	var _m1: Callable = func(d: Dictionary) -> void:
		if not d.has("owned_cards"):
			d["owned_cards"] = d.get("player_deck", [])
		d["version"] = 1

	var _m10: Callable = func(d: Dictionary) -> void:
		var old_owned: Array = d.get("owned_cards", [])
		var old_deck: Array = d.get("player_deck", [])
		var new_instances: Array = []
		var counter: int = 0
		for item in old_owned:
			var tid: String = str(item)
			var tmpl: Dictionary = CardRegistry.get_template(tid)
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

	var rows: Array = [
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
	return rows
