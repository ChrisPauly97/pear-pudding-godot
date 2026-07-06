extends Node

const ScriptedBattleData = preload("res://game_logic/battle/ScriptedBattleData.gd")

# Explicit preloads — compile-time dependency chain for Android APK inclusion.
# Add a line here whenever a new scripted battle .tres is created.
const _SB_TEST := preload("res://data/scripted_battles/scripted_test.tres")
const _SB_RABBIT_HUNT := preload("res://data/scripted_battles/rabbit_hunt.tres")
const _SB_SCOUT_AMBUSH := preload("res://data/scripted_battles/scout_ambush.tres")

static var _battles: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	# scripted_test is intentionally included so tests and dev tooling can load
	# a known-valid fixture without needing real story content.
	var all: Array = [_SB_TEST, _SB_RABBIT_HUNT, _SB_SCOUT_AMBUSH]
	for res in all:
		var b: ScriptedBattleData = res as ScriptedBattleData
		if b != null and not b.battle_id.is_empty():
			_battles[b.battle_id] = b

static func get_battle(id: String) -> ScriptedBattleData:
	_ensure_loaded()
	return _battles.get(id, null) as ScriptedBattleData

static func all_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _battles.keys():
		result.append(str(k))
	return result
