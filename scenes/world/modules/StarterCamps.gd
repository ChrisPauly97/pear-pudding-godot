## Madrian's starter-zone camps (GID-141 / TID-591): keeps each `StarterZone`
## camp near the player stocked with its authored enemies, refilling a fallen
## slot after `StarterZone.CAMP_RESPAWN_S`. Camp enemies are loose enemies (like
## night-hunt spectres) with a preset `enemy_level`, and never saved as defeated.
## Created by `WorldScene._ensure_world_modules()` as `starter_camps`; ticked
## from WorldScene's overworld branch.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _StarterZone = preload("res://game_logic/world/StarterZone.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _EnemyScene: PackedScene = preload("res://scenes/world/entities/EnemyNPC.tscn")

## How often camps are checked (s).
const CHECK_INTERVAL: float = 1.5

var _world: _WorldScene = null
var _timer: float = 0.0
## member id → live node
var _members: Dictionary = {}
## member id → seconds until it may refill (only while fallen)
var _cooldowns: Dictionary = {}


func tick(delta: float) -> void:
	for id: Variant in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var player: Node3D = _world._player
	if player == null or _world.map_name != "main" or NetworkManager.is_active():
		return
	for camp: Dictionary in _StarterZone.CAMPS:
		var t: Vector2i = camp["tile"]
		var centre := Vector3((float(t.x) + 0.5) * IsoConst.TILE_SIZE, 0.0, (float(t.y) + 0.5) * IsoConst.TILE_SIZE)
		var near: bool = Vector2(centre.x - player.position.x, centre.z - player.position.z).length() \
				<= _StarterZone.ACTIVE_RANGE
		for slot: int in range(int(camp["count"])):
			_update_slot(camp, slot, near)

func _update_slot(camp: Dictionary, slot: int, near: bool) -> void:
	var id: String = _StarterZone.member_id(camp, slot)
	var node: Node3D = _world._valid_node3d(_members.get(id))
	if node != null:
		if not near and not SceneManager.fights_in_world():
			_despawn(id, node)
		return
	if _members.has(id):
		# Fell since the last check: start its refill timer.
		_members.erase(id)
		_world._enemy_nodes.erase(id)
		_world._loose_enemy_nodes.erase(id)
		_cooldowns[id] = _StarterZone.CAMP_RESPAWN_S
		return
	if not near or float(_cooldowns.get(id, 0.0)) > 0.0:
		return
	_cooldowns.erase(id)
	_spawn(camp, slot, id)

func _spawn(camp: Dictionary, slot: int, id: String) -> void:
	var t: Vector2i = _StarterZone.slot_tile(camp, slot)
	var x: float = (float(t.x) + 0.5) * IsoConst.TILE_SIZE
	var z: float = (float(t.y) + 0.5) * IsoConst.TILE_SIZE
	var etype: String = str(camp["enemy_type"])
	var node: Node3D = _EnemyScene.instantiate() as Node3D
	node.call("init_from_data", {
		"id": id,
		"enemy_type": etype,
		"enemy_deck": _EnemyRegistry.get_deck(etype),
		"tracking": bool(camp.get("tracking", false)),
		"enemy_level": int(camp["level"]),
		"camp": str(camp["id"]),
	})
	node.position = Vector3(x, _world.get_terrain_height(x, z) + 0.5, z)
	_world._entity_root.add_child(node)
	_members[id] = node
	_world.register_loose_enemy(id, node)

func _despawn(id: String, node: Node3D) -> void:
	_members.erase(id)
	_world._enemy_nodes.erase(id)
	_world._loose_enemy_nodes.erase(id)
	node.queue_free()

## Camp members alive right now (tests / debugging).
func alive_count() -> int:
	var n: int = 0
	for id: Variant in _members:
		if _world._valid_node3d(_members[id]) != null:
			n += 1
	return n
