## Swap-deck prompt in the world (GID-181 / TID-756). With gambits auto-skipped the engage
## prompt never shows, so the matchup swap has to be offered before the fight: while a hostile
## enemy is within awareness range and auto-skip is on, a "Swap deck" action sits in the
## HUD's ZONE_CONTEXT bar. Tapping it opens the matchup row (LoadoutSwapRow) in a modal.
##
## The swap only changes the active loadout. It never starts a battle: engage still goes
## through SceneManager.accepts_engage(), and the open modal holds engage (hold_engage /
## release_engage) so an enemy cannot start a fight behind it. Not offered in co-op, or
## outside the plain world state (battles, pickers, pause).
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _WorldHUD = preload("res://scenes/world/WorldHUD.gd")
const _LoadoutSwapRow = preload("res://scenes/ui/LoadoutSwapRow.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

const ACTION_ID: String = "swap_deck"
const CHECK_INTERVAL: float = 0.25

var _world: _WorldScene = null
var _button_built: bool = false
var _check_left: float = 0.0
## Enemy type of the hostile enemy in range this check ("" when none).
var _near_type: String = ""
var _prompt_layer: CanvasLayer = null
var _held: bool = false
## Keeps the open prompt's row (and its button callbacks) alive until it closes.
var _swap_rows: Array[_LoadoutSwapRow] = []


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	_refresh()


func _refresh() -> void:
	if _world == null or _world._world_hud == null:
		return
	if not _button_built:
		_build_button()
	_near_type = _nearby_enemy_type()
	_world._world_hud.set_action_visible(ACTION_ID, _near_type != "")


## The enemy type of a hostile, not-yet-defeated enemy within awareness range, or "" when the
## swap offer does not apply (co-op, gambit prompt on, not plainly in the world, no player).
func _nearby_enemy_type() -> String:
	if NetworkManager.is_active() or _prompt_layer != null:
		return ""
	if not SceneManager.is_in_world() or not SceneManager.accepts_engage():
		return ""
	if not bool(SceneManager.save_manager.get_setting("auto_skip_gambits", false)):
		return ""
	return _hostile_type_in_reach()

## The enemy type of the nearest-first hostile, not-yet-defeated enemy in awareness range.
func _hostile_type_in_reach() -> String:
	if _world._player == null:
		return ""
	var pos: Vector3 = _world._player.position
	var node: Node3D = _world._find_nearby_enemy(pos.x, pos.z, IsoConst.ENEMY_AWARENESS_RANGE)
	if node == null or not is_instance_valid(node):
		return ""
	var edata: Variant = node.get("enemy_data")
	if not (edata is Dictionary):
		return ""
	var data: Dictionary = edata
	var eid: String = str(data.get("id", ""))
	if eid != "" and SceneManager.save_manager.is_enemy_defeated(eid):
		return ""
	return str(data.get("enemy_type", ""))


func _build_button() -> void:
	_button_built = true
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	_world._world_hud.register_action(ACTION_ID, "Swap deck", _WorldHUD.ZONE_CONTEXT, _open_prompt,
			Callable(), Vector2(vh * 0.16, vh * 0.055))
	_world._world_hud.set_action_visible(ACTION_ID, false)


func _open_prompt() -> void:
	if _near_type == "" or _prompt_layer != null or not SceneManager.accepts_engage():
		return
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var prompt: Dictionary = _world._build_prompt(60, 0.02)
	_prompt_layer = prompt.get("layer")
	var vbox: VBoxContainer = prompt.get("vbox")
	# Hold engage while the modal is up. Released when the layer leaves the tree, which covers
	# every way it closes (pick, close, or the world being freed).
	SceneManager.hold_engage()
	_held = true
	_prompt_layer.tree_exiting.connect(_on_prompt_gone)

	_UiUtil.make_label("Swap deck for %s" % _display_name(_near_type), int(vh * 0.028), Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var row := _LoadoutSwapRow.new(_near_type, vh, _on_swapped)
	row.attach(vbox)
	_swap_rows.append(row)
	_UiUtil.make_button("Close", Vector2(vh * 0.22, vh * 0.06), int(vh * 0.024), _close_prompt, vbox)


func _on_swapped(_index: int) -> void:
	_close_prompt()


func _close_prompt() -> void:
	if _prompt_layer != null and is_instance_valid(_prompt_layer):
		_prompt_layer.queue_free()
	_on_prompt_gone()


func _on_prompt_gone() -> void:
	_prompt_layer = null
	_swap_rows.clear()
	if _held:
		_held = false
		SceneManager.release_engage()


func _display_name(enemy_type: String) -> String:
	var name: String = _EnemyRegistry.get_display_name(enemy_type)
	return name if name != "" else enemy_type.capitalize()
