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
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := ResourceLoader.load(CARD_DIR + "/" + fname)
			if res is CardData:
				var card := res as CardData
				_cards[card.id] = card
		fname = dir.get_next()

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
