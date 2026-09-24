## Named deck loadouts (GID-058): validation, switching, add / rename / duplicate /
## delete.
##
## Owned by SaveManager (`SaveManager.decks`), created in its `_init`. The state
## stays on SaveManager because PERSISTED_FIELDS walks its properties, so this
## reads and writes it through `_save.<field>`.
extends RefCounted

const _SaveManager = preload("res://autoloads/SaveManager.gd")

var _save: _SaveManager


func _init(save_manager: _SaveManager) -> void:
	_save = save_manager


## Returns true if the loadout at index has a card count within [DECK_MIN, DECK_MAX].
func is_loadout_valid(index: int) -> bool:
	if index < 0 or index >= _save.loadouts.size():
		return false
	var cards: Array = _save.loadouts[index].get("cards", [])
	return cards.size() >= IsoConst.DECK_MIN and cards.size() <= IsoConst.DECK_MAX

## Returns the list of loadout names in order.
func get_loadout_names() -> Array[String]:
	var names: Array[String] = []
	for lo: Dictionary in _save.loadouts:
		names.append(str(lo.get("name", "Deck")))
	return names

## Switches the active loadout; syncs player_deck to the new loadout's cards.
## Returns false if the index is out of range.
func set_active_loadout(index: int) -> bool:
	if index < 0 or index >= _save.loadouts.size():
		return false
	_save.active_loadout = index
	_save.player_deck.assign(_save.loadouts[_save.active_loadout].get("cards", []))
	_save._dirty = true
	return true

## Creates a new empty loadout with the given name (max MAX_LOADOUTS).
## Returns the new index, or -1 if the limit is reached.
func add_loadout(name: String) -> int:
	if _save.loadouts.size() >= _save.MAX_LOADOUTS:
		return -1
	_save.loadouts.append({"name": name, "cards": []})
	_save._dirty = true
	return _save.loadouts.size() - 1

## Renames the loadout at index. No-op if out of range.
func rename_loadout(index: int, new_name: String) -> void:
	if index < 0 or index >= _save.loadouts.size():
		return
	_save.loadouts[index]["name"] = new_name
	_save._dirty = true

## Duplicates the loadout at index and appends it (max MAX_LOADOUTS).
## Returns the new index, or -1 if the limit is reached.
func duplicate_loadout(index: int) -> int:
	if index < 0 or index >= _save.loadouts.size():
		return -1
	if _save.loadouts.size() >= _save.MAX_LOADOUTS:
		return -1
	var src: Dictionary = _save.loadouts[index]
	var copy_cards: Array[String] = []
	copy_cards.assign(src.get("cards", []))
	var copy_name: String = str(src.get("name", "Deck")) + " (Copy)"
	_save.loadouts.append({"name": copy_name, "cards": copy_cards})
	_save._dirty = true
	return _save.loadouts.size() - 1

## Deletes the loadout at index. The last remaining loadout cannot be deleted.
## If deleting the active loadout, switches to the nearest valid index.
## Returns false if refused (last loadout or out of range).
func delete_loadout(index: int) -> bool:
	if _save.loadouts.size() <= 1:
		return false
	if index < 0 or index >= _save.loadouts.size():
		return false
	_save.loadouts.remove_at(index)
	if _save.active_loadout >= _save.loadouts.size():
		_save.active_loadout = _save.loadouts.size() - 1
	_save.player_deck.assign(_save.loadouts[_save.active_loadout].get("cards", []))
	_save._dirty = true
	return true
