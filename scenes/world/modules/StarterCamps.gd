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
const _LooseEnemySpawner = preload("res://scenes/world/LooseEnemySpawner.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")

## How often camps are checked (s).
const CHECK_INTERVAL: float = 1.5

var _world: _WorldScene = null
var _timer: float = 0.0
## member id → live node
var _members: Dictionary = {}
## member id → seconds until it may refill (only while fallen)
var _cooldowns: Dictionary = {}
## Graveyard dressing root (GID-143 / TID-605), built once per overworld load.
var _scenery: Node3D = null


func tick(delta: float) -> void:
	for id: Variant in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	if _scenery == null and _world.map_name == "main" and not NetworkManager.is_dedicated_server():
		_build_scenery()
	var player: Node3D = _world._player
	if player == null or _world.map_name != "main" or NetworkManager.is_active():
		return
	for camp: Dictionary in _StarterZone.CAMPS:
		var t: Vector2i = camp["tile"]
		var centre := Vector3(IsoConst.tile_center(t.x), 0.0, IsoConst.tile_center(t.y))
		var near: bool = Vector2(centre.x - player.position.x, centre.z - player.position.z).length() \
				<= _StarterZone.ACTIVE_RANGE
		for slot: int in range(int(camp["count"])):
			_update_slot(camp, slot, near)
	_update_barrow_king(player)

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
	var x: float = IsoConst.tile_center(t.x)
	var z: float = IsoConst.tile_center(t.y)
	var etype: String = str(camp["enemy_type"])
	_members[id] = _LooseEnemySpawner.spawn(_world, {
		"id": id,
		"enemy_type": etype,
		"enemy_deck": _EnemyRegistry.get_deck(etype),
		"tracking": bool(camp.get("tracking", false)),
		"enemy_level": int(camp["level"]),
		"camp": str(camp["id"]),
	}, x, z)

## GID-149: the unique Barrow King, spawned beside his crypt once it is opened.
func _update_barrow_king(player: Node3D) -> void:
	var bk: Dictionary = _StarterZone.BARROW_KING
	var id: String = str(bk["id"])
	var save := SceneManager.save_manager
	if _world._valid_node3d(_members.get(id)) != null \
			or not _StarterZone.barrow_king_awake(save.quests_completed, save.defeated_enemies):
		return
	var t: Vector2i = bk["tile"]
	var x: float = IsoConst.tile_center(t.x)
	var z: float = IsoConst.tile_center(t.y)
	if Vector2(x - player.position.x, z - player.position.z).length() > _StarterZone.ACTIVE_RANGE:
		return
	_members[id] = _LooseEnemySpawner.spawn(_world, {"id": id, "enemy_type": str(bk["enemy_type"]),
		"tracking": false, "enemy_deck": _EnemyRegistry.get_deck(str(bk["enemy_type"])),
		"enemy_level": int(bk["level"])}, x, z)

func _despawn(id: String, node: Node3D) -> void:
	_members.erase(id)
	_world._enemy_nodes.erase(id)
	_world._loose_enemy_nodes.erase(id)
	node.queue_free()

## Headstones, the iron fence and the crypt door as static billboards.
func _build_scenery() -> void:
	_scenery = Node3D.new()
	_scenery.name = "StarterScenery"
	_world._entity_root.add_child(_scenery)
	for entry: Array in _StarterZone.graveyard_props():
		var tex: Texture2D = _SpriteRegistry.graveyard_prop(str(entry[0]))
		if tex == null:
			continue
		var t: Vector2i = _RealmLayout.to_world_tile("madrian", entry[1] as Vector2i)
		var axis: String = str(entry[2])
		var off: Vector2 = entry[3]
		var x: float = (float(t.x) + 0.5 + off.x) * IsoConst.TILE_SIZE
		var z: float = (float(t.y) + 0.5 + off.y) * IsoConst.TILE_SIZE
		var sprite := Sprite3D.new()
		_SpriteRegistry.apply_billboard_flags(sprite)
		_SpriteRegistry.setup_sprite(sprite, tex)
		var holder := Node3D.new()
		if axis != "":
			# A flat, double-sided panel along the fence line (TID-605 fix).
			sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			holder.rotation.y = PI * 0.5 if axis == "z" else 0.0
		holder.position = Vector3(x, _world.get_terrain_height(x, z), z)
		holder.add_child(sprite)
		_scenery.add_child(holder)

## Camp members alive right now (tests / debugging).
func alive_count() -> int:
	var n: int = 0
	for id: Variant in _members:
		if _world._valid_node3d(_members[id]) != null:
			n += 1
	return n
