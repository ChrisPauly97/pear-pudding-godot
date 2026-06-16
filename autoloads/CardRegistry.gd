extends Node

const CardData = preload("res://data/CardData.gd")

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
const _C_ISFIG_SHADOW_ECHO := preload("res://data/cards/isfig_shadow_echo.tres")

static var _cards: Dictionary = {}  # id -> CardData
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var all: Array = [
		_C_ALIGHT, _C_ANCIENT_GUARDIAN, _C_ASH, _C_ASH_WARDEN, _C_BLESSED_LIGHT, _C_BLITZ_GHOUL,
		_C_BRITTLE, _C_BULWARK, _C_CHAR, _C_DAGGER_THROW, _C_DARK_PACT, _C_DUEL_CROWN,
		_C_DAWN_ACOLYTE, _C_DAWN_GUARDIAN, _C_DAWN_HEALER, _C_DAWN_PALADIN, _C_DRAIN,
		_C_DUSK_SEER, _C_DUSK_VAMPIRE, _C_DUSK_WRAITH, _C_EMBER, _C_EMBER_IMP, _C_FLICKER,
		_C_GHOST, _C_GHOUL, _C_INSIGHT, _C_IRON_REVENANT, _C_MEND, _C_PHOENIX_RISE,
		_C_RADIANCE, _C_RALLY, _C_RESTORE, _C_SCORCH, _C_SHADOW_BOLT,
		_C_SHROUDED_WRAITH, _C_SIPHON, _C_SKELETON, _C_SOUL_HARVEST, _C_SOUL_REND,
		_C_SPARK, _C_SURGE_SPIRIT, _C_TIME_WARP, _C_VEILED_PALADIN,
		_C_VOID_CREEPER, _C_VOID_WYRM, _C_WITHER, _C_ZOMBIE,
		_C_ISFIG_SHADOW_ECHO,
	]
	for res in all:
		var card := res as CardData
		if card == null:
			continue
		if card.id != "":
			_cards[card.id] = card
		else:
			push_error("CardRegistry: a preloaded card has empty id, skipped")
	if _cards.is_empty():
		push_error("CardRegistry: no cards loaded")

## Returns a template Dictionary compatible with CardInstance.from_template()
## and all existing callers. Returns {} if the ID is unknown.
static func get_template(id: String) -> Dictionary:
	_ensure_loaded()
	if _cards.has(id):
		return (_cards[id] as CardData).to_template_dict()
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
		return (_cards[id] as CardData).can_craft
	return false

## Returns true if the card is available (not a locked legendary).
## Legendary cards are gated behind achievements; use SceneManager.save_manager
## to check unlocked_achievements.
static func is_unlocked(card_id: String, unlocked_achievements: Array[String]) -> bool:
	_ensure_loaded()
	if not _cards.has(card_id):
		return false
	var card := _cards[card_id] as CardData
	if card.card_class != "legendary":
		return true
	const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")
	for a: Dictionary in AchievementRegistry.get_all():
		if str(a.get("reward_card_id", "")) == card_id:
			return unlocked_achievements.has(str(a["id"]))
	# Legendary with no achievement gate — always unlocked.
	return true
