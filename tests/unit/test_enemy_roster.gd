## GID-149: the eight new enemies — registry rows, placement, fight traits, art.
extends "res://tests/framework/test_case.gd"

const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _EnemyTraits = preload("res://game_logic/battle/EnemyTraits.gd")
const _GameState = preload("res://game_logic/battle/GameState.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const _StarterZone = preload("res://game_logic/world/StarterZone.gd")
const _Nocturnal = preload("res://scenes/world/modules/NocturnalSpawner.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _CaptureTracker = preload("res://game_logic/battle/CaptureTracker.gd")

const ROSTER: Array[String] = ["wolf_pack", "bog_hag", "martarquas_scout", "scarab_swarm", "ember_cultist",
	"frost_wendigo", "rift_echo", "barrow_king"]

func test_every_new_enemy_is_complete() -> void:
	for t: String in ROSTER:
		var deck: Array[String] = _EnemyRegistry.get_deck(t)
		assert_gt(deck.size(), 8, t + " deck")
		for cid: String in deck:
			assert_false(_CardRegistry.get_template(cid).is_empty(), "%s deck card %s exists" % [t, cid])
		var sig: String = _EnemyRegistry.get_signature_card(t)
		assert_false(_CardRegistry.get_template(sig).is_empty(), t + " signature exists")
		var ct := _CaptureTracker.new(_EnemyRegistry.get_capture_condition(t), _EnemyRegistry.get_capture_param(t))
		assert_ne(ct.condition_text(), "", t + " capture condition has text")
		assert_not_null(_SpriteRegistry.enemy_texture(t), t + " has art")

func test_packs_and_pack_art() -> void:
	assert_eq(_EnemyRegistry.get_pack("wolf_pack").size(), 3)
	assert_eq(_EnemyRegistry.get_pack("scarab_swarm").size(), 5)
	assert_ne(_SpriteRegistry.pack_member_texture("wolf"), _SpriteRegistry.pack_member_texture("skeleton"))
	assert_ne(_SpriteRegistry.pack_member_texture("scarab"), _SpriteRegistry.pack_member_texture("skeleton"))

func test_biome_pools_carry_the_roster() -> void:
	assert_true(_BiomeDef.ENEMY_POOLS[_BiomeDef.GRASSLANDS].has("wolf_pack"))
	assert_true(_BiomeDef.ENEMY_POOLS[_BiomeDef.FOREST].has("bog_hag"))
	assert_true(_BiomeDef.ENEMY_POOLS[_BiomeDef.DESERT].has("scarab_swarm"))
	assert_true(_BiomeDef.ENEMY_POOLS[_BiomeDef.SCORCHED].has("ember_cultist"))
	assert_true(_BiomeDef.LEY_ECHO_BIOMES.has(_BiomeDef.DESERT))

func test_wendigo_only_on_the_peaks() -> void:
	assert_eq(_Nocturnal.wendigo_or("spectre_wisp", _BiomeDef.MOUNTAINS, 0.0), "frost_wendigo")
	assert_eq(_Nocturnal.wendigo_or("spectre_wisp", _BiomeDef.MOUNTAINS, 0.99), "spectre_wisp")
	assert_eq(_Nocturnal.wendigo_or("spectre_wisp", _BiomeDef.FOREST, 0.0), "spectre_wisp")

func test_barrow_king_wakes_after_crypt_and_stays_dead() -> void:
	var id: String = str(_StarterZone.BARROW_KING["id"])
	assert_false(_StarterZone.is_camp_enemy(id), "unique, so defeat is saved")
	assert_false(_StarterZone.barrow_king_awake([], []))
	assert_true(_StarterZone.barrow_king_awake(["sealed_crypt"], []))
	assert_false(_StarterZone.barrow_king_awake(["sealed_crypt"], [id]))
	assert_true(_EnemyRegistry.is_boss("barrow_king"))

func _board_count(gs: _GameState, cid: String) -> int:
	var n: int = 0
	for c: _CardInstance in gs.players[1].board.get_cards():
		if c.template_id == cid:
			n += 1
	return n

func test_howl_adds_one_wolf_on_round_three() -> void:
	var gs := _GameState.new()
	var traits: Array[String] = ["howl"]
	_EnemyTraits.on_enemy_round(gs, 1, traits, 2, 1)
	assert_eq(_board_count(gs, "wolf"), 0)
	var lines: Array[String] = _EnemyTraits.on_enemy_round(gs, 1, traits, 3, 1)
	assert_eq(_board_count(gs, "wolf"), 1)
	assert_eq(lines.size(), 1)

func test_brood_refills_up_to_cap() -> void:
	var gs := _GameState.new()
	var traits: Array[String] = ["brood"]
	for r: int in range(1, 10):
		_EnemyTraits.on_enemy_round(gs, 1, traits, r, 1)
	assert_eq(_board_count(gs, "scarab"), _EnemyTraits.BROOD_CAP)

func test_frenzy_buffs_late() -> void:
	var gs := _GameState.new()
	var wolf: _CardInstance = _EnemyTraits.make_unit("wolf", 1)
	_EnemyTraits.place(gs.players[1], wolf)
	var base: int = wolf.attack
	var traits: Array[String] = ["frenzy"]
	_EnemyTraits.on_enemy_round(gs, 1, traits, _EnemyTraits.FRENZY_FROM - 1, 1)
	assert_eq(wolf.attack, base)
	_EnemyTraits.on_enemy_round(gs, 1, traits, _EnemyTraits.FRENZY_FROM, 1)
	assert_eq(wolf.attack, base + 1)

func test_mirror_swaps_spells_only() -> void:
	var deck: Array[String] = ["flux_kinetic_bolt", "ghost"]
	var mine: Array[String] = ["drain"]
	assert_eq(_EnemyTraits.mirror_deck(deck, mine), ["drain", "ghost"] as Array[String])
	var none: Array[String] = []
	assert_eq(_EnemyTraits.mirror_deck(deck, none), deck)
