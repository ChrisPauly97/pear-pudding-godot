class_name ZoneState
extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

const SLOT_COUNT: int = 5

var slots: Array[CardInstance] = []  # CardInstance or null per slot
var _snapshot: Array[CardInstance] = []

func _init() -> void:
	slots.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		slots[i] = null

func first_empty_slot() -> int:
	for i in range(SLOT_COUNT):
		if slots[i] == null:
			return i
	return -1

func is_full() -> bool:
	return first_empty_slot() == -1

func add_card(card: CardInstance) -> bool:
	var slot := first_empty_slot()
	if slot == -1:
		return false
	slots[slot] = card
	return true

func remove_card(card: CardInstance) -> bool:
	for i in range(SLOT_COUNT):
		if slots[i] == card:
			slots[i] = null
			return true
	return false

func get_cards() -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for s in slots:
		if s != null:
			result.append(s)
	return result

func snapshot() -> void:
	_snapshot = slots.duplicate()

func restore_snapshot() -> void:
	slots = _snapshot.duplicate()

func start_turn() -> void:
	for s in slots:
		if s != null:
			s.start_turn()

func to_dict() -> Array:
	var result: Array = []
	for i in range(SLOT_COUNT):
		var s: CardInstance = slots[i]
		if s == null:
			result.append(null)
		else:
			result.append(s.to_dict())
	return result

static func from_dict(slots_arr: Array) -> ZoneState:
	var z := ZoneState.new()
	for i in range(mini(slots_arr.size(), SLOT_COUNT)):
		var entry = slots_arr[i]
		if entry == null or not entry is Dictionary:
			z.slots[i] = null
		else:
			z.slots[i] = CardInstance.from_dict(entry)
	return z
