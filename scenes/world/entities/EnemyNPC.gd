extends Node3D

var enemy_data: Dictionary = {}
var _alive: bool = true
var _tracking: bool = true
const TRACKING_SPEED: float = 2.5
const AUTO_BATTLE_RANGE: float = 1.5
const AUTO_BATTLE_RANGE_SQ: float = AUTO_BATTLE_RANGE * AUTO_BATTLE_RANGE
var _engaged: bool = false
var _player_ref: WeakRef = WeakRef.new()

func set_player(player: Node3D) -> void:
	_player_ref = weakref(player)

func init_from_data(data: Dictionary) -> void:
	enemy_data = data
	_alive = data.get("alive", true)
	_tracking = data.get("tracking", true)

func _process(_delta: float) -> void:
	if not _alive or _engaged:
		return

	var player: Node3D = _player_ref.get_ref() as Node3D
	if player == null:
		return

	# Use squared distance to skip sqrt
	var dx: float = position.x - player.position.x
	var dz: float = position.z - player.position.z
	var dist_sq: float = dx * dx + dz * dz

	if dist_sq <= AUTO_BATTLE_RANGE_SQ:
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
