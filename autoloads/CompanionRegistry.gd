extends Node

const CompanionData = preload("res://data/CompanionData.gd")

# Explicit preloads keep the .tres files in the Android APK dependency chain.
const _C_MAITELN := preload("res://data/companions/maiteln.tres")

static var _companions: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded and not _companions.is_empty():
		return
	_loaded = true
	_companions.clear()
	# Instantiate each companion from its .tres data directly.
	# _C_MAITELN is preloaded for APK packaging; we create a fresh instance
	# because resource loader does not always initialize GDScript properties
	# in headless/test contexts.
	var maiteln := CompanionData.new()
	maiteln.companion_id = "maiteln"
	maiteln.display_name = "Maiteln"
	maiteln.description = "The old wizard shares his insight: draw an extra card at the start of each turn."
	maiteln.passive_type = "draw_card"
	maiteln.passive_value = 1
	maiteln.unlock_story_flag = "story_intro_complete"
	_companions["maiteln"] = maiteln

static func get_companion(id: String) -> CompanionData:
	_ensure_loaded()
	return _companions.get(id, null)

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
