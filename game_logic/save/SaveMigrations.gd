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
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const XpCurve = preload("res://game_logic/progression/XpCurve.gd")

const CURRENT_VERSION: int = 50


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


## GID-141: systems are now learned from trainers. An existing save had every
## system already, so it keeps them all — every ladder *feature* plus Mend and
## Kick (always known before). Riding stays level-gated unless it already owns a
## mount; trainer skills it never bought stay unlearned. It also skips the new
## townsfolk opening (`town_quests_done`) so Maiteln is where it left him.
static func _m44_unlock_ladder(d: Dictionary) -> void:
	var learned: Array = d.get("learned_abilities", [])
	var grant: Array[String] = ["mend", "kick"]
	for id: String in UnlockLadder.all_ids():
		if str(UnlockLadder.def(id)["kind"]) == "feature" and id != UnlockLadder.FEAT_MOUNT:
			grant.append(id)
	if not (d.get("owned_mounts", []) as Array).is_empty():
		grant.append(UnlockLadder.FEAT_MOUNT)
	for id: String in grant:
		if not learned.has(id):
			learned.append(id)
	d["learned_abilities"] = learned
	# Existing saves skip the new townsfolk opening (Maiteln waits on it).
	var flags: Dictionary = d.get("story_flags", {})
	flags["town_quests_done"] = true
	d["story_flags"] = flags
	d["version"] = 44


## GID-142: the Spire became per-biome rifts. The old best floor maps onto the
## Grasslands rift at FLOORS_PER_TIER floors per tier; an active run keeps going
## in the Grasslands rift at tier 1.
static func _m45_rifts(d: Dictionary) -> void:
	var best: Dictionary = d.get("rift_best_tiers", {})
	var old_tiers: int = int(d.get("spire_best_floor", 0)) / RiftDefs.FLOORS_PER_TIER
	if old_tiers > int(best.get(RiftDefs.DEFAULT_RIFT, 0)):
		best[RiftDefs.DEFAULT_RIFT] = old_tiers
	d["rift_best_tiers"] = best
	var run: Dictionary = d.get("spire_run", {})
	if bool(run.get("active", false)) and not run.has("rift"):
		run["rift"] = RiftDefs.DEFAULT_RIFT
		run["tier"] = 1
		d["spire_run"] = run
	d["version"] = 45


## GID-175: the fixed skill bar became technique cards. The bar's abilities
## (or the default Strike/Mend/Kick bar, filtered to what the save knew) are
## queued as `technique_deck_pending` card ids; SaveManager owns the cards and
## deals them into the active deck on load (`_restore_technique_cards`).
static func _m46_technique_cards(d: Dictionary) -> void:
	var learned: Array = d.get("learned_abilities", [])
	var bar: Array = d.get("skill_bar", [])
	if bar.is_empty():
		bar = ["strike", "mend", "kick"]
	var pending: Array = []
	for v: Variant in bar:
		var id: String = str(v)
		var card: String = TechniqueDefs.card_for(id)
		if card != "" and (id == "strike" or learned.has(id)) and not pending.has(card):
			pending.append(card)
	d["technique_deck_pending"] = pending
	d.erase("skill_bar")
	d["version"] = 46


## GID-179: active skill-tree nodes became technique cards (the hero power is
## gone). Each one an existing save unlocked is queued like v46's skill bar, so
## SaveManager owns it and deals it into the active deck while that stays legal.
static func _m48_skill_techniques(d: Dictionary) -> void:
	var pending: Array = d.get("technique_deck_pending", [])
	for v: Variant in d.get("unlocked_skills", []):
		var card: String = TechniqueDefs.card_for_skill(str(v))
		if card != "" and not pending.has(card):
			pending.append(card)
	d["technique_deck_pending"] = pending
	d["version"] = 48


## GID-177: levelling became much slower (XpCurve). A save keeps its level and
## its progress toward the next one; only the XP number is rescaled.
static func _m47_slow_xp_curve(d: Dictionary) -> void:
	d["xp"] = XpCurve.migrate_xp(int(d.get("xp", 0)))
	d["version"] = 47


## `[target_version, payload]` rows in ascending version order.
## GID-138: the outdoor story towns moved into the overworld. A save standing in
## one moves to "main" at the same spot; stack entries for a stitched town become
## the overworld with a `pos:` return token at the door into the next map down.
static func _m43_stitched_towns(d: Dictionary) -> void:
	var cur: String = str(d.get("current_map", ""))
	if RealmLayout.is_stitched(cur):
		var shift: Vector2 = RealmLayout.world_shift(cur)
		d["player_x"] = float(d.get("player_x", 0.0)) + shift.x
		d["player_z"] = float(d.get("player_z", 0.0)) + shift.y
		d["current_map"] = "main"
	var ms: Array = d.get("map_stack", [])
	var ds: Array = d.get("door_stack", [])
	var new_ms: Array = []
	var new_ds: Array = []
	for i: int in range(ms.size()):
		var m: String = str(ms[i])
		var door: String = str(ds[i]) if i < ds.size() else ""
		if RealmLayout.is_stitched(m):
			var child: String = str(ms[i + 1]) if i + 1 < ms.size() else str(d.get("current_map", ""))
			var back: Variant = RealmLayout.return_pos_for(child)
			var p: Vector3 = back if back is Vector3 else RealmLayout.spawn_pos(m)
			m = "main"
			door = RealmLayout.pos_token(p.x, p.z)
		if not new_ms.is_empty() and str(new_ms[new_ms.size() - 1]) == m:
			new_ds[new_ds.size() - 1] = door  # the deeper entry knows the way back
			continue
		new_ms.append(m)
		new_ds.append(door)
	if RealmLayout.is_overworld(str(d.get("current_map", ""))):
		new_ms.clear()
		new_ds.clear()
	d["map_stack"] = new_ms
	d["door_stack"] = new_ds
	var wp: Dictionary = d.get("waypoint", {})
	if RealmLayout.is_stitched(str(wp.get("map", ""))):
		var local := Vector2i(int(wp.get("tx", 0)), int(wp.get("tz", 0)))
		var t: Vector2i = RealmLayout.to_world_tile(str(wp["map"]), local)
		d["waypoint"] = {"map": "main", "tx": t.x, "tz": t.y}
	d["version"] = 43


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
		[42, {"equipped_offhand": "", "owned_offhands": []}],
		[43, _m43_stitched_towns],
		[44, _m44_unlock_ladder],
		[45, _m45_rifts],
		[46, _m46_technique_cards],
		[47, _m47_slow_xp_curve],
		[48, _m48_skill_techniques],
		[49, {"profession_xp": {}, "materials": {}}],
		[50, {"well_fed": {}}],
	]
	return rows
