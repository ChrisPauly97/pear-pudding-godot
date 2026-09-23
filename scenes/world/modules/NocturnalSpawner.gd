## Single-player Night Hunts (GID-055): while it is night in the infinite world,
## spectral enemies spawn on grass a short walk from the player, get stronger
## the further from the origin they appear, and fade away at dawn.
##
## A child node of WorldScene (see WorldScene._ensure_world_modules). The shared
## `_enemy_nodes` table stays on WorldScene; this module owns only the spawns it
## created. The co-op variant is CoopActivities' deterministic night hunt.
extends Node

const _EnemyScene = preload("res://scenes/world/entities/EnemyNPC.tscn")

const MAX_ALIVE: int = 12
const SPAWN_INTERVAL_MIN: float = 30.0
const SPAWN_INTERVAL_MAX: float = 60.0
const SPAWN_DIST_MIN: float = 6.0
const SPAWN_DIST_MAX: float = 14.0
const SPAWN_TRIES: int = 20
## Chunks from the origin at which the tougher spectres start to appear.
const HAUNT_FROM_CHUNK: int = 3
const DREAD_FROM_CHUNK: int = 8

var _world: Node = null

var _enemies: Dictionary = {}        # spawn_id -> {"node": Node3D, "chunk": Vector2i}
var _spawn_timer: float = 0.0
var _id_counter: int = 0
var _tutorial_shown_session: bool = false

func tick(delta: float) -> void:
	var player: Node3D = _world._player
	if not _world._is_infinite or player == null:
		return
	if _world._dnc == null or not _world._dnc.is_night_now():
		_spawn_timer = 0.0
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
	if _prune_and_count() >= MAX_ALIVE:
		return
	var spawn_pos: Vector3 = _find_spawn_pos(player.position)
	if spawn_pos == Vector3.ZERO:
		return
	_spawn(spawn_pos, _tier_for(player.position))
	_maybe_show_tutorial()

## Spectre type for a spawn near `pos`: tougher the further from the origin.
static func _tier_for(pos: Vector3) -> String:
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var dist: int = int(Vector2(pos.x, pos.z).length() / chunk_world)
	if dist >= DREAD_FROM_CHUNK:
		return "spectre_dread"
	if dist >= HAUNT_FROM_CHUNK:
		return "spectre_haunt"
	return "spectre_wisp"

func _prune_and_count() -> int:
	var alive: int = 0
	for sid: String in _enemies.keys():
		if _world._valid_node3d(_enemies[sid].get("node")) == null:
			_enemies.erase(sid)
		else:
			alive += 1
	return alive

func _spawn(pos: Vector3, enemy_type: String) -> void:
	var node: Node3D = _EnemyScene.instantiate() as Node3D
	if node == null:
		return
	_id_counter += 1
	var spawn_id: String = "nocturnal_%d" % _id_counter
	node.set_meta("is_nocturnal", true)
	node.call("init_from_data", {
		"id": spawn_id,
		"enemy_type": enemy_type,
		"tracking": true,
		"nocturnal": true,
	})
	node.position = pos
	_world._entity_root.add_child(node)
	_enemies[spawn_id] = {"node": node, "chunk": _chunk_of(pos.x, pos.z)}
	_world._enemy_nodes[spawn_id] = node

## Once per session on the first night spawn, and only until the player has
## seen it once.
func _maybe_show_tutorial() -> void:
	if _tutorial_shown_session:
		return
	_tutorial_shown_session = true
	if not SceneManager.save_manager.get_story_flag("seen_tutorial_night_hunts"):
		SceneManager.save_manager.set_story_flag("seen_tutorial_night_hunts")
		GameBus.tutorial_popup_requested.emit("night_hunts")

static func _chunk_of(wx: float, wz: float) -> Vector2i:
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	return Vector2i(int(floor(wx / chunk_world)), int(floor(wz / chunk_world)))

## A random loaded grass tile SPAWN_DIST_MIN..MAX units from `origin`, or
## Vector3.ZERO when none turned up within SPAWN_TRIES attempts.
func _find_spawn_pos(origin: Vector3) -> Vector3:
	var csm: Node = _world._csm
	for _try: int in range(SPAWN_TRIES):
		var angle: float = randf() * TAU
		var dist: float = randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
		var tx: float = origin.x + cos(angle) * dist
		var tz: float = origin.z + sin(angle) * dist
		var key: Vector2i = _chunk_of(tx, tz)
		if not csm.has_chunk_data(key):
			continue
		var chunk: RefCounted = csm.get_chunk_data(key)
		var tile_x: int = clampi(int(tx / IsoConst.TILE_SIZE) - key.x * IsoConst.CHUNK_SIZE, 0, IsoConst.CHUNK_SIZE - 1)
		var tile_z: int = clampi(int(tz / IsoConst.TILE_SIZE) - key.y * IsoConst.CHUNK_SIZE, 0, IsoConst.CHUNK_SIZE - 1)
		var li: int = tile_z * IsoConst.CHUNK_SIZE + tile_x
		if li >= chunk.tiles.size() or chunk.tiles[li] != IsoConst.TILE_GRASS:
			continue
		return Vector3(tx, _world.get_terrain_height(tx, tz) + 0.5, tz)
	return Vector3.ZERO

## Dawn: clear every spectre, optionally fading them out first.
func despawn_all(fade: bool) -> void:
	for sid: String in _enemies.keys():
		_world._enemy_nodes.erase(sid)
		var n: Node3D = _world._valid_node3d(_enemies[sid].get("node"))
		if n == null:
			continue
		if fade and n.has_method("fade_out_and_free"):
			n.call("fade_out_and_free", 1.0)
		else:
			n.queue_free()
	_enemies.clear()

## A chunk streamed out: drop the spectres that were standing in it.
func evict_chunk(chunk_key: Vector2i) -> void:
	for sid: String in _enemies.keys():
		if _enemies[sid].get("chunk") != chunk_key:
			continue
		var n: Node3D = _world._valid_node3d(_enemies[sid].get("node"))
		if n != null:
			n.queue_free()
		_world._enemy_nodes.erase(sid)
		_enemies.erase(sid)
