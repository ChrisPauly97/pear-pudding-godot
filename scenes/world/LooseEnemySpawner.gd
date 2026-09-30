## Spawns an enemy placed by code rather than by chunk data — night hunts,
## sieges, starter camps, nocturnal spectres. One path so every such enemy is
## instanced, initialised, stood on the terrain, parented under the entity root
## and registered as loose the same way.
extends RefCounted

const _EnemyScene: PackedScene = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _WorldScene = preload("res://scenes/world/WorldScene.gd")

## Height above the terrain an enemy's origin sits at.
const GROUND_OFFSET: float = 0.5

## `data` goes to `init_from_data` (it must carry "id"); a truthy "nocturnal"
## also tags the node `is_nocturnal`. Returns the node, or null if it failed to
## instance.
static func spawn_at(world: _WorldScene, data: Dictionary, pos: Vector3) -> Node3D:
	var node: Node3D = _EnemyScene.instantiate() as Node3D
	if node == null:
		return null
	if bool(data.get("nocturnal", false)):
		node.set_meta("is_nocturnal", true)
	node.call("init_from_data", data)
	node.position = pos
	world._entity_root.add_child(node)
	world.register_loose_enemy(str(data.get("id", "")), node)
	return node

## `spawn_at` standing on the terrain at world (x, z).
static func spawn(world: _WorldScene, data: Dictionary, x: float, z: float) -> Node3D:
	return spawn_at(world, data, Vector3(x, world.get_terrain_height(x, z) + GROUND_OFFSET, z))
