extends Node3D

var enemy_data: Dictionary = {}
var _alive: bool = true
var _tracking: bool = true
const TRACKING_SPEED: float = 2.5
const AUTO_BATTLE_RANGE: float = 1.5
var _engaged: bool = false

func init_from_data(data: Dictionary) -> void:
	enemy_data = data
	_alive = data.get("alive", true)
	_tracking = data.get("tracking", true)

func _process(delta: float) -> void:
	if not _alive or _engaged:
		return

	var world := get_parent().get_parent()
	if not world.has_method("get") or not world.get("_player"):
		return
	var player: Node3D = world.get("_player")
	if player == null:
		return

	var my_pos := Vector2(position.x, position.z)
	var pl_pos := Vector2(player.position.x, player.position.z)
	var dist := my_pos.distance_to(pl_pos)

	if dist <= AUTO_BATTLE_RANGE:
		_engaged = true
		enemy_data["alive"] = false
		_alive = false
		var edata := enemy_data.duplicate()
		edata["enemy_deck"] = ["ghost", "skeleton", "zombie", "ghoul",
							   "ghost", "skeleton", "zombie", "ghoul"]
		GameBus.enemy_engaged.emit(edata)
		queue_free()
		return

func mark_defeated() -> void:
	_alive = false
	queue_free()
