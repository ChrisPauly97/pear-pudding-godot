extends Node

const CardData = preload("res://data/CardData.gd")

const _C_ARCANE_SEAL      := preload("res://data/cards/arcane_seal.tres")
const _C_ALIGHT           := preload("res://data/cards/alight.tres")
const _C_ANCIENT_GUARDIAN := preload("res://data/cards/ancient_guardian.tres")
const _C_ASH              := preload("res://data/cards/ash.tres")
const _C_ASH_WARDEN       := preload("res://data/cards/ash_warden.tres")
const _C_BLESSED_LIGHT    := preload("res://data/cards/blessed_light.tres")
const _C_BLITZ_GHOUL      := preload("res://data/cards/blitz_ghoul.tres")
const _C_BRITTLE          := preload("res://data/cards/brittle.tres")
const _C_BULWARK          := preload("res://data/cards/bulwark.tres")
const _C_CHAR             := preload("res://data/cards/char.tres")
const _C_DAGGER_THROW     := preload("res://data/cards/dagger_throw.tres")
const _C_DARK_PACT        := preload("res://data/cards/dark_pact.tres")
const _C_DUEL_CROWN       := preload("res://data/cards/duel_crown.tres")
const _C_DAWN_ACOLYTE     := preload("res://data/cards/dawn_acolyte.tres")
const _C_DAWN_GUARDIAN    := preload("res://data/cards/dawn_guardian.tres")
const _C_DAWN_HEALER      := preload("res://data/cards/dawn_healer.tres")
const _C_DAWN_PALADIN     := preload("res://data/cards/dawn_paladin.tres")
const _C_DRAIN            := preload("res://data/cards/drain.tres")
const _C_DUSK_SEER        := preload("res://data/cards/dusk_seer.tres")
const _C_DUSK_VAMPIRE     := preload("res://data/cards/dusk_vampire.tres")
const _C_DUSK_WRAITH      := preload("res://data/cards/dusk_wraith.tres")
const _C_EMBER            := preload("res://data/cards/ember.tres")
const _C_EMBER_IMP        := preload("res://data/cards/ember_imp.tres")
const _C_FLICKER          := preload("res://data/cards/flicker.tres")
const _C_GHOST            := preload("res://data/cards/ghost.tres")
const _C_GHOUL            := preload("res://data/cards/ghoul.tres")
const _C_INSIGHT          := preload("res://data/cards/insight.tres")
const _C_IRON_REVENANT    := preload("res://data/cards/iron_revenant.tres")
const _C_MEND             := preload("res://data/cards/mend.tres")
const _C_PHOENIX_RISE     := preload("res://data/cards/phoenix_rise.tres")
const _C_RADIANCE         := preload("res://data/cards/radiance.tres")
const _C_RALLY            := preload("res://data/cards/rally.tres")
const _C_RESTORE          := preload("res://data/cards/restore.tres")
const _C_SCORCH           := preload("res://data/cards/scorch.tres")
const _C_SHADOW_BOLT      := preload("res://data/cards/shadow_bolt.tres")
const _C_SHROUDED_WRAITH  := preload("res://data/cards/shrouded_wraith.tres")
const _C_SIPHON           := preload("res://data/cards/siphon.tres")
const _C_SKELETON         := preload("res://data/cards/skeleton.tres")
const _C_SOUL_HARVEST     := preload("res://data/cards/soul_harvest.tres")
const _C_SOUL_REND        := preload("res://data/cards/soul_rend.tres")
const _C_SPARK            := preload("res://data/cards/spark.tres")
const _C_SURGE_SPIRIT     := preload("res://data/cards/surge_spirit.tres")
const _C_TIME_WARP        := preload("res://data/cards/time_warp.tres")
const _C_VEILED_PALADIN   := preload("res://data/cards/veiled_paladin.tres")
const _C_VOID_CREEPER     := preload("res://data/cards/void_creeper.tres")
const _C_VOID_WYRM        := preload("res://data/cards/void_wyrm.tres")
const _C_WITHER           := preload("res://data/cards/wither.tres")
const _C_ZOMBIE           := preload("res://data/cards/zombie.tres")
const _C_SHADOW_WARD       := preload("res://data/cards/shadow_ward.tres")
const _C_SIG_PACK_LEADER   := preload("res://data/cards/sig_pack_leader.tres")
const _C_SIG_SHAMBLER      := preload("res://data/cards/sig_shambler.tres")
const _C_SIG_WANDERER      := preload("res://data/cards/sig_wanderer.tres")
const _C_SIG_WARLORD       := preload("res://data/cards/sig_warlord.tres")
const _C_ISFIG_SHADOW_ECHO := preload("res://data/cards/isfig_shadow_echo.tres")
const _C_EMBER_COVENANT    := preload("res://data/cards/ember_covenant.tres")
const _C_PYRE_WARDEN       := preload("res://data/cards/pyre_warden.tres")
const _C_SACRED_LIGHT      := preload("res://data/cards/sacred_light.tres")
const _C_HALLOWED_GROUND   := preload("res://data/cards/hallowed_ground.tres")
const _C_TWILIGHT_VEIL     := preload("res://data/cards/twilight_veil.tres")
const _C_ASH_ARBITER       := preload("res://data/cards/ash_arbiter.tres")

static var _cards: Dictionary = {}  # id -> CardData
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var all: Array = [
		_C_ARCANE_SEAL,
		_C_ALIGHT, _C_ANCIENT_GUARDIAN, _C_ASH, _C_ASH_WARDEN, _C_BLESSED_LIGHT, _C_BLITZ_GHOUL,
		_C_BRITTLE, _C_BULWARK, _C_CHAR, _C_DAGGER_THROW, _C_DARK_PACT, _C_DUEL_CROWN,
		_C_DAWN_ACOLYTE, _C_DAWN_GUARDIAN, _C_DAWN_HEALER, _C_DAWN_PALADIN, _C_DRAIN,
		_C_DUSK_SEER, _C_DUSK_VAMPIRE, _C_DUSK_WRAITH, _C_EMBER, _C_EMBER_IMP, _C_FLICKER,
		_C_GHOST, _C_GHOUL, _C_INSIGHT, _C_IRON_REVENANT, _C_MEND, _C_PHOENIX_RISE,
		_C_RADIANCE, _C_RALLY, _C_RESTORE, _C_SCORCH, _C_SHADOW_BOLT,
		_C_SHADOW_WARD,
		_C_SIG_PACK_LEADER, _C_SIG_SHAMBLER, _C_SIG_WANDERER, _C_SIG_WARLORD,
		_C_SHROUDED_WRAITH, _C_SIPHON, _C_SKELETON, _C_SOUL_HARVEST, _C_SOUL_REND,
		_C_SPARK, _C_SURGE_SPIRIT, _C_TIME_WARP, _C_VEILED_PALADIN,
		_C_VOID_CREEPER, _C_VOID_WYRM, _C_WITHER, _C_ZOMBIE,
		_C_ISFIG_SHADOW_ECHO,
		_C_EMBER_COVENANT, _C_PYRE_WARDEN, _C_SACRED_LIGHT,
		_C_HALLOWED_GROUND, _C_TWILIGHT_VEIL, _C_ASH_ARBITER,
	]
	for preloaded in all:
		if preloaded == null:
			continue
		# preload() caches a Resource without a live GDScript instance in headless/runtime mode.
		# Re-load bypassing the cache so the resource loader creates a proper script instance.
		# The preload const above guarantees the file is included in Android APKs.
		var path: String = preloaded.resource_path
		if path == "":
			continue
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			continue
		var id_val = res.get("id")
		var card_id: String = str(id_val) if id_val != null else ""
		if card_id != "":
			_cards[card_id] = res
		else:
			push_error("CardRegistry: a preloaded card has empty id, skipped")
	if _cards.is_empty():
		push_error("CardRegistry: no cards loaded")

## Returns a template Dictionary compatible with CardInstance.from_template()
## and all existing callers. Returns {} if the ID is unknown.
static func get_template(id: String) -> Dictionary:
	_ensure_loaded()
	if _cards.has(id):
		var res: Resource = _cards[id] as Resource
		if res != null and res.has_method("to_template_dict"):
			return res.call("to_template_dict")
	return {}

## Returns true when the player has more corruption_points than redemption_points.
## Requires the SaveManager autoload to be active; returns false if not available.
static func is_dark_aligned() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var sm: Node = tree.root.get_node_or_null("SaveManager")
	if sm == null:
		return false
	return int(sm.get("corruption_points")) > int(sm.get("redemption_points"))

## Returns a template dict for the given id resolved to the specified face.
## face = "dark" returns the Dark face for dual-faced cards; anything else returns Light.
## For non-dual cards the face parameter is ignored.
static func get_template_for_face(id: String, face: String) -> Dictionary:
	_ensure_loaded()
	if _cards.has(id):
		var res: Resource = _cards[id] as Resource
		if res != null and res.has_method("to_template_dict"):
			return res.call("to_template_dict", face)
	return {}

## Returns all known card IDs, in no guaranteed order.
static func get_all_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _cards.keys():
		result.append(str(k))
	return result

## Returns true if this card can be crafted via the crafting system.
## Cards with can_craft = false are excluded (achievement-gated legendaries).
static func is_craftable(id: String) -> bool:
	_ensure_loaded()
	if _cards.has(id):
		var val = _cards[id].get("can_craft")
		return val == null or bool(val)
	return false

## Returns true if the card is available (not a locked legendary).
## Legendary cards are gated behind achievements; use SceneManager.save_manager
## to check unlocked_achievements.
static func is_unlocked(card_id: String, unlocked_achievements: Array[String]) -> bool:
	_ensure_loaded()
	if not _cards.has(card_id):
		return false
	var card_class_val: String = str(_cards[card_id].get("card_class", ""))
	if card_class_val != "legendary":
		return true
	const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")
	for a: Dictionary in AchievementRegistry.get_all():
		if str(a.get("reward_card_id", "")) == card_id:
			return unlocked_achievements.has(str(a["id"]))
	# Legendary with no achievement gate — always unlocked.
	return true
