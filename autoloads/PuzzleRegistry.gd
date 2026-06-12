extends Node

const PuzzleData = preload("res://game_logic/battle/PuzzleData.gd")

# Explicit preloads — compile-time dependency chain for Android APK inclusion.
# Add a line here whenever a new puzzle .tres is created.
const _P_TEST                := preload("res://data/puzzles/puzzle_test.tres")
const _P_SURGE_LETHAL        := preload("res://data/puzzles/puzzle_surge_lethal.tres")
const _P_WARD_BYPASS         := preload("res://data/puzzles/puzzle_ward_bypass.tres")
const _P_SHROUD_TIMING       := preload("res://data/puzzles/puzzle_shroud_timing.tres")
const _P_ATTACK_ORDER        := preload("res://data/puzzles/puzzle_attack_order.tres")
const _P_MANA_EFFICIENCY     := preload("res://data/puzzles/puzzle_mana_efficiency.tres")

static var _puzzles: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	# puzzle_test is intentionally included so tests and dev tooling can load
	# a known-valid fixture without needing real puzzle content.
	var all: Array = [
		_P_TEST,
		_P_SURGE_LETHAL, _P_WARD_BYPASS, _P_SHROUD_TIMING,
		_P_ATTACK_ORDER, _P_MANA_EFFICIENCY,
	]
	for res in all:
		var p: PuzzleData = res as PuzzleData
		if p != null and not p.puzzle_id.is_empty():
			_puzzles[p.puzzle_id] = p

static func get_puzzle(id: String) -> PuzzleData:
	_ensure_loaded()
	return _puzzles.get(id, null) as PuzzleData

static func all_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _puzzles.keys():
		result.append(str(k))
	return result
