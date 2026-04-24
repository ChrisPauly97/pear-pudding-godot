extends Node

const CardData = preload("res://data/CardData.gd")
const CARD_DIR := "res://data/cards"

static var _cards: Dictionary = {}  # id -> CardData
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(CARD_DIR)
	if not dir:
		push_error("CardRegistry: failed to open card directory '%s'" % CARD_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := ResourceLoader.load(CARD_DIR + "/" + fname)
			if res is CardData:
				var card := res as CardData
				if card.id != "":
					_cards[card.id] = card
				else:
					push_error("CardRegistry: card '%s' has empty id, skipped" % fname)
			elif res != null:
				push_error("CardRegistry: '%s' is not a CardData resource (type: %s)" % [fname, res.get_class()])
		fname = dir.get_next()
	if _cards.is_empty():
		push_error("CardRegistry: no cards loaded — check '%s'" % CARD_DIR)

## Returns a template Dictionary compatible with CardInstance.from_template()
## and all existing callers. Returns {} if the ID is unknown.
static func get_template(id: String) -> Dictionary:
	_ensure_loaded()
	if _cards.has(id):
		return (_cards[id] as CardData).to_template_dict()
	return {}

## Returns all known card IDs, in no guaranteed order.
## Add a new card by dropping a CardData .tres in res://data/cards/ — no code changes needed.
static func get_all_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _cards.keys():
		result.append(str(k))
	return result

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
