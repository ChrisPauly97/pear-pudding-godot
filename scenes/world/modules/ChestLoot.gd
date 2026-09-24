## Opening a world chest: the mimic ambush, marking it open (and syncing that to
## the party), then the loot — a treasure-map fragment, or scattered cards and
## coin piles plus a chance at unowned equipment. In a co-op session with
## need/greed on, the loot goes to a party roll (CoopActivities) instead.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const _LootRoll = preload("res://game_logic/net/LootRoll.gd")
const _WorldItemScene = preload("res://scenes/world/entities/WorldItem.tscn")

## Chance an infinite-world chest yields a treasure-map fragment instead of loot
## (only while no treasure hunt is active).
const MAP_FRAGMENT_CHANCE: float = 0.20
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "armor", "ring", "trinket"]
## The starter weapon never drops.
const _STARTER_WEAPON: String = "rusty_dagger"

var _world: _WorldScene = null

## Chest tier from its id prefix: treasure room (dtr_) 3, dungeon (dc_) 2, world 1.
static func tier_for(chest_id: String) -> int:
	if chest_id.begins_with("dtr_"):
		return 3
	if chest_id.begins_with("dc_"):
		return 2
	return 1

func open(chest: Dictionary, px: float, pz: float) -> void:
	if chest.get("is_mimic", false):
		_spring_mimic(chest, px, pz)
		return
	var sm := SceneManager.save_manager
	var cid: String = str(chest.get("id", ""))
	chest["opened"] = true
	AudioManager.play_sfx("chest_open")
	if OS.has_feature("mobile") and bool(sm.get_setting("haptics", true)):
		Input.vibrate_handheld(40)
	sm.mark_chest_opened(cid)
	sm.bounties.increment_bounty_progress("open_chests", {})
	SceneManager.session_stats["chests_opened"] = int(SceneManager.session_stats.get("chests_opened", 0)) + 1
	var node: Node3D = _world._valid_node3d(_world._chest_nodes.get(cid))
	if node != null and node.has_method("mark_opened"):
		node.mark_opened()
	# Co-op (GID-096): reflect + persist the open for all players (this opener
	# keeps the loot below; peers only see the chest flip open). Inert solo.
	_world.coop_session._on_chest_opened_coop(cid)
	var tier: int = tier_for(cid)
	# Party loot rolls (GID-102 / TID-381): with need/greed on, the authority
	# rolls the loot among present members instead of the opener keeping it.
	if _world._coop_active and _world.coop_activities._coop_loot_mode_is_need_greed():
		_world.coop_activities._start_loot_roll(cid, tier)
		return
	if _world._is_infinite and sm.active_treasure.is_empty() and randf() < MAP_FRAGMENT_CHANCE:
		sm.collect_treasure_fragment()
		return
	var cx: float = float(chest.get("x", px))
	var cz: float = float(chest.get("z", pz))
	var origin := Vector3(cx, _world.get_terrain_height(cx, cz) + 0.25, cz)
	var card_ids: Array[String] = []
	card_ids.assign(chest.get("card_ids", []))
	spawn_card_items(card_ids, origin, tier)
	spawn_coin_piles(origin)
	var chance: float = _LootRoll.EQUIPMENT_CHANCE_TREASURE_ROOM if tier == 3 else _LootRoll.EQUIPMENT_CHANCE_DEFAULT
	_maybe_drop_equipment(chance)

func _spring_mimic(chest: Dictionary, px: float, pz: float) -> void:
	AudioManager.play_sfx("enemy_alert")
	SceneManager.show_toast("It's a Mimic!", "Prepare for battle!")
	var mimic_deck: Array[String] = []
	mimic_deck.assign(EnemyRegistry.get_deck("mimic"))
	GameBus.enemy_engaged.emit({
		"id": str(chest.get("id", "mimic_0")),
		"x": chest.get("x", px),
		"z": chest.get("z", pz),
		"alive": true,
		"tracking": false,
		"enemy_type": "mimic",
		"enemy_deck": mimic_deck,
	})

## Cards burst out of the chest and land in a ring around it, each with its own
## rarity roll (better odds from higher-tier chests).
func spawn_card_items(card_ids: Array[String], origin: Vector3, chest_tier: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	for i: int in range(card_ids.size()):
		var cid: String = card_ids[i]
		var rarity: String = CardDropUtil.effective_rarity(cid, CardDropUtil.roll_rarity(chest_tier))
		var stats: Dictionary = CardDropUtil.roll_stats(cid, rarity)
		var angle: float = (float(i) / float(card_ids.size())) * TAU + rng.randf_range(-0.4, 0.4)
		var land: Vector3 = _ring_point(origin, angle, rng.randf_range(1.0, 1.8))
		_spawn_item().setup(cid, origin, land, rarity,
			int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))

## 3–5 piles of 5–20 coins scattered around the chest.
func spawn_coin_piles(origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	var pile_count: int = rng.randi_range(3, 5)
	for i: int in range(pile_count):
		var angle: float = (float(i) / float(pile_count)) * TAU + rng.randf_range(-0.5, 0.5)
		var land: Vector3 = _ring_point(origin, angle, rng.randf_range(0.8, 2.0))
		_spawn_item().setup_coin(rng.randi_range(5, 20), origin, land)

static func _ring_point(origin: Vector3, angle: float, dist: float) -> Vector3:
	return origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

func _spawn_item() -> Node3D:
	var item: Node3D = _WorldItemScene.instantiate()
	_world._entity_root.add_child(item)
	return item

## With probability `chance`, grants one random equipment piece the player
## doesn't own yet (any slot). A miss, or owning everything, is silent.
func _maybe_drop_equipment(chance: float) -> void:
	if randf() >= chance:
		return
	var sm := SceneManager.save_manager
	var candidates: Array[String] = []
	for slot: String in EQUIPMENT_SLOTS:
		var owned: Array[String] = sm.get_owned_by_slot(slot)
		for eid: String in WeaponRegistry.get_by_slot(slot):
			if eid != _STARTER_WEAPON and not owned.has(eid):
				candidates.append(eid)
	if candidates.is_empty():
		return
	var picked: String = candidates[randi() % candidates.size()]
	var item: WeaponData = WeaponRegistry.get_weapon(picked)
	if item == null:
		return
	if item.slot == "weapon":
		sm.add_weapon(picked)
	else:
		sm.add_equipment(picked, item.slot)
	GameBus.hud_message_requested.emit("Found: %s!" % item.display_name)
	GameBus.equipment_dropped.emit(picked)
