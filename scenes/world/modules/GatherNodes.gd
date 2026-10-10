## Gathering nodes in the world (GID-182 / TID-760): the registry of live herb,
## ore and fish nodes that ChunkRenderer spawns, and the nearest-harvestable
## lookup behind WorldScene's `_find_nearby_gather_node`. The harvest itself is
## `GatherNode.interact()`, run by the simple-interaction table.
## Built by WorldScene._ensure_world_modules(); not registered with NetSync.
extends Node

const _GatherNode = preload("res://scenes/world/entities/GatherNode.gd")

var _nodes: Dictionary = {}  # gather id -> GatherNode (Node3D)


func register(gid: String, node: Node3D) -> void:
	_nodes[gid] = node


## Nearest-in-range node that can be harvested now. Depleted nodes are skipped
## until they respawn; freed nodes (chunk unloaded) are pruned.
func find_nearby(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for gid: String in _nodes.keys():
		var raw: Variant = _nodes[gid]
		if not is_instance_valid(raw):
			_nodes.erase(gid)
			continue
		var gn := raw as _GatherNode
		if gn == null or not gn.is_harvestable():
			continue
		var ddx: float = gn.position.x - px
		var ddz: float = gn.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return gn
	return null
