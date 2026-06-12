extends Node

## Scheduler for living-world events (roaming boss, traveling merchant, card shower).
##
## Concrete events register themselves via register_event() — typically from a
## WorldEvents init script preloaded by WorldScene. The scheduler ticks only while
## the player is in the infinite world and not in battle. At most one event fires at
## a time. Cooldown state is persisted in SaveManager.world_events.
##
## GameBus and SceneManager are accessed via get_node() so that this file compiles
## cleanly during GDScript's reload phase (before autoloads enter the SceneTree).

class _EventReg extends RefCounted:
	var id: String = ""
	var min_interval: float = 60.0
	var max_interval: float = 120.0
	var spawn: Callable = Callable()
	var cleanup: Callable = Callable()
	var elapsed: float = 0.0
	var next_interval: float = 60.0
	var active: bool = false

const _InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")

var _events: Dictionary = {}           # String -> _EventReg
var _active_event_id: String = ""     # "" = none active
var _event_positions: Dictionary = {} # String -> Vector3
var _in_battle: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Cached node references, set in _ready().
var _game_bus: Node = null
var _scene_mgr: Node = null

func _ready() -> void:
	_rng.randomize()
	_game_bus = get_node_or_null("/root/GameBus")
	_scene_mgr = get_node_or_null("/root/SceneManager")
	if _game_bus != null:
		_game_bus.connect("enemy_engaged", func(_d: Dictionary) -> void: _in_battle = true)
		_game_bus.connect("battle_won", func(_d: Dictionary) -> void: _in_battle = false)
		_game_bus.connect("battle_lost", func() -> void: _in_battle = false)

## Register a world event. min_interval/max_interval are in seconds.
## spawn_fn is called when the event fires; cleanup_fn is called when end_event() is invoked.
## Restores elapsed time from SaveManager so cooldowns survive restarts.
func register_event(id: String, min_interval: float, max_interval: float,
		spawn_fn: Callable, cleanup_fn: Callable) -> void:
	var reg := _EventReg.new()
	reg.id = id
	reg.min_interval = min_interval
	reg.max_interval = max_interval
	reg.spawn = spawn_fn
	reg.cleanup = cleanup_fn
	reg.next_interval = _rng.randf_range(min_interval, max_interval)
	# Restore saved elapsed/active state if present.
	var save_mgr: Node = _get_save_manager()
	if save_mgr != null:
		var we: Variant = save_mgr.get("world_events")
		if we is Dictionary:
			var saved: Dictionary = (we as Dictionary).get(id, {}) as Dictionary
			reg.elapsed = float(saved.get("elapsed", 0.0))
			if bool(saved.get("active", false)):
				# Event was active when saved — restart cooldown in v1; do not re-fire blindly.
				reg.active = false
				reg.elapsed = 0.0
	_events[id] = reg

func _process(delta: float) -> void:
	if _in_battle:
		return
	if _scene_mgr == null:
		return
	var current_map: String = str(_scene_mgr.get("current_map"))
	if current_map != "main":
		return
	_tick(delta)

## Advance all event timers by delta. Only fires if no event is currently active.
func _tick(delta: float) -> void:
	if _active_event_id != "":
		return
	for id: String in _events:
		var reg: _EventReg = _events[id] as _EventReg
		if reg == null:
			continue
		reg.elapsed += delta
		if reg.elapsed >= reg.next_interval:
			_fire_event(id, reg)
			break  # one event per tick; re-evaluates next frame

func _fire_event(id: String, reg: _EventReg) -> void:
	reg.active = true
	reg.elapsed = 0.0
	reg.next_interval = _rng.randf_range(reg.min_interval, reg.max_interval)
	_active_event_id = id
	reg.spawn.call()
	if _game_bus != null:
		_game_bus.emit_signal("world_event_started", id)
	_persist_events()

## Signal that event id has concluded. Calls cleanup and restarts the cooldown.
func end_event(id: String) -> void:
	if not _events.has(id):
		return
	var reg: _EventReg = _events[id] as _EventReg
	if reg == null:
		return
	reg.active = false
	reg.elapsed = 0.0
	reg.cleanup.call()
	if _active_event_id == id:
		_active_event_id = ""
	_event_positions.erase(id)
	if _game_bus != null:
		_game_bus.emit_signal("world_event_ended", id)
	_persist_events()

## Returns true if any world event is currently active.
func is_event_active() -> bool:
	return _active_event_id != ""

## Returns the id of the currently active event, or "" if none.
func get_active_event_id() -> String:
	return _active_event_id

## Store the world-space spawn position for the active event (called from spawn_fn).
func set_event_position(id: String, pos: Vector3) -> void:
	_event_positions[id] = pos

## Retrieve the world-space spawn position for an event, or Vector3.ZERO if not set.
func get_event_position(id: String) -> Vector3:
	return _event_positions.get(id, Vector3.ZERO) as Vector3

func _get_save_manager() -> Node:
	if _scene_mgr == null:
		return null
	var sm: Variant = _scene_mgr.get("save_manager")
	if sm is Node:
		return sm as Node
	return null

func _persist_events() -> void:
	var save_mgr: Node = _get_save_manager()
	if save_mgr == null:
		return
	var dict: Dictionary = {}
	for id: String in _events:
		var reg: _EventReg = _events[id] as _EventReg
		if reg == null:
			continue
		dict[id] = {"elapsed": reg.elapsed, "active": reg.active}
	save_mgr.set("world_events", dict)
	save_mgr.call("mark_dirty")

## Find a walkable grass tile between min_dist and max_dist world-units from player_pos.
## Samples up to 30 candidate positions. Falls back to player_pos + (min_dist, 0, 0) if none found.
## world_seed must match the current save's world_seed for correct tile lookups.
static func find_spawn_tile(player_pos: Vector3, min_dist: float, max_dist: float,
		world_seed: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	for _i: int in range(30):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(min_dist, max_dist)
		var tx: float = player_pos.x + cos(angle) * dist
		var tz: float = player_pos.z + sin(angle) * dist
		var cx: int = int(floor(tx / chunk_world))
		var cz: int = int(floor(tz / chunk_world))
		var chunk = _InfiniteWorldGen.generate_chunk_data_only(cx, cz, world_seed)
		if chunk == null:
			continue
		var local_tx: int = int(floor(tx / IsoConst.TILE_SIZE)) - cx * IsoConst.CHUNK_SIZE
		var local_tz: int = int(floor(tz / IsoConst.TILE_SIZE)) - cz * IsoConst.CHUNK_SIZE
		local_tx = clamp(local_tx, 0, IsoConst.CHUNK_SIZE - 1)
		local_tz = clamp(local_tz, 0, IsoConst.CHUNK_SIZE - 1)
		var tile_idx: int = local_tz * IsoConst.CHUNK_SIZE + local_tx
		if chunk.tiles[tile_idx] == IsoConst.TILE_GRASS:
			return Vector3(tx, 0.0, tz)
	return player_pos + Vector3(min_dist, 0.0, 0.0)
