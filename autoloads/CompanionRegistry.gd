extends Node

const CompanionData = preload("res://data/CompanionData.gd")

const _C_MAITELN := preload("res://data/companions/maiteln.tres")

static var _companions: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var all: Array = [
		_C_MAITELN,
	]
	for res in all:
		var c: CompanionData = res as CompanionData
		if c != null and not c.companion_id.is_empty():
			_companions[c.companion_id] = c

static func get_companion(id: String) -> CompanionData:
	_ensure_loaded()
	return _companions.get(id, null) as CompanionData

static func all_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _companions.keys():
		result.append(str(k))
	return result

static func is_unlocked(id: String) -> bool:
	_ensure_loaded()
	var c: CompanionData = get_companion(id)
	if c == null:
		return false
	if c.unlock_story_flag == "":
		return true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var sm: Node = tree.root.get_node_or_null("SaveManager")
	if sm == null:
		return false
	return bool(sm.get_story_flag(c.unlock_story_flag))
