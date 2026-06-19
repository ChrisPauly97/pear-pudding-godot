class_name ZoneState
extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

const SLOT_COUNT: int = 5

var slots: Array[CardInstance] = []  # CardInstance or null per slot
var slot_enhancements: Array[Dictionary] = []  # length SLOT_COUNT; {} means no enhancement
var _snapshot: Array[CardInstance] = []

func _init() -> void:
	slots.resize(SLOT_COUNT)
	slot_enhancements.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		slots[i] = null
		slot_enhancements[i] = {}

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

func add_card_at_slot(card: CardInstance, idx: int) -> bool:
	if idx < 0 or idx >= SLOT_COUNT or slots[idx] != null:
		return false
	slots[idx] = card
	return true

func enhance_slot(idx: int, enhancement_type: String, value: int) -> void:
	if idx < 0 or idx >= SLOT_COUNT:
		return
	slot_enhancements[idx] = {"type": enhancement_type, "value": value}

func consume_slot_enhancement(idx: int) -> Dictionary:
	if idx < 0 or idx >= SLOT_COUNT:
		return {}
	var enh: Dictionary = slot_enhancements[idx].duplicate()
	slot_enhancements[idx] = {}
	return enh

func get_slot_enhancement(idx: int) -> Dictionary:
	if idx < 0 or idx >= SLOT_COUNT:
		return {}
	return slot_enhancements[idx]

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

func from_dict(slots_arr: Array) -> void:
	for i in range(mini(slots_arr.size(), SLOT_COUNT)):
		var entry = slots_arr[i]
		if entry == null or not entry is Dictionary:
			slots[i] = null
		else:
			var ci := CardInstance.new()
			ci.from_dict(entry)
			slots[i] = ci

func enhancements_to_dict() -> Array:
	var result: Array = []
	for i in range(SLOT_COUNT):
		result.append(slot_enhancements[i].duplicate())
	return result

func enhancements_from_dict(arr: Array) -> void:
	for i in range(mini(arr.size(), SLOT_COUNT)):
		var entry = arr[i]
		if entry is Dictionary:
			slot_enhancements[i] = entry.duplicate()
		else:
			slot_enhancements[i] = {}
