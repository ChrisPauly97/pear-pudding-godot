## Ambient critters (CritterDef): keeps a handful of wildlife around the hero
## in the overworld — mice, rats, butterflies, bees, fawns, snow rabbits,
## scorched larvae, blackened adders by biome. Scenery only: no battles, no
## save state, not synced in co-op (each peer sees its own).
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _CritterDef = preload("res://game_logic/world/CritterDef.gd")
const _Critter = preload("res://scenes/world/entities/Critter.gd")
const _ChunkRenderer = preload("res://scenes/world/ChunkRenderer.gd")

const MAX_CRITTERS: int = 10
const SPAWN_MIN: float = 8.0
const SPAWN_MAX: float = 22.0
const DESPAWN_DIST: float = 32.0
const TICK: float = 0.4

var _world: _WorldScene = null
var _root: Node3D = null
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0


func _ready() -> void:
	_rng.randomize()


## Live critters (tests, debugging).
func critters() -> Array[Node]:
	return _root.get_children() if _root != null and is_instance_valid(_root) else [] as Array[Node]


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	if _world == null or _world._player == null or not _world._is_infinite:
		return
	if _root == null or not is_instance_valid(_root):
		_root = Node3D.new()
		_root.name = "Critters"
		_world.add_child(_root)
	var hero: Vector3 = _world._player.global_position
	var day: bool = _world._dnc == null or not _world._dnc.is_night_now()
	for n: Node in _root.get_children():
		var c := n as _Critter
		if c == null:
			continue
		var far: bool = Vector2(c.position.x - hero.x, c.position.z - hero.z).length() > DESPAWN_DIST
		var hides: bool = not day and bool(_CritterDef.params(c.species).get("day_only", false))
		if far or hides:
			c.queue_free()
	if _root.get_child_count() < MAX_CRITTERS:
		_try_spawn(hero, day)


func _try_spawn(hero: Vector3, day: bool) -> void:
	var key: String = _CritterDef.species_for(_world._current_biome, day, _rng.randi())
	if key.is_empty():
		return
	var a: float = _rng.randf() * TAU
	var r: float = _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
	var p := Vector3(hero.x + cos(a) * r, 0.0, hero.z + sin(a) * r)
	if not _walkable(p.x, p.z):
		return
	p.y = _world.get_terrain_height(p.x, p.z)
	var c := _Critter.new()
	c.setup(key, p, _rng.randi(), _world.get_terrain_height, _walkable, _hero_pos)
	_root.add_child(c)


func _hero_pos() -> Vector3:
	return _world._player.global_position if _world != null and _world._player != null else Vector3.INF


## Open ground (grass or hill) and dry.
func _walkable(x: float, z: float) -> bool:
	var t: int = _world.get_tile_global(floori(x / IsoConst.TILE_SIZE), floori(z / IsoConst.TILE_SIZE))
	if t != IsoConst.TILE_GRASS and t != IsoConst.TILE_HILL:
		return false
	return _ChunkRenderer.water_at_world(_world._csm, x, z, _world.world_seed) <= 0.0
