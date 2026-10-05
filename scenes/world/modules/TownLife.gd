## Walking townsfolk in the stitched towns (GID-156): moves each walker's NPC
## node along its TownLife loop, keeps the interaction data (`_active_npc_data`
## x/z) on the node, fades walkers in and out with their role's hours, and holds
## a walker still (facing the hero) while the hero stands beside them.
##
## A walker's spot is TownLife.sample(loop, time of day − lag). The lag grows
## while the walker is held and shrinks again at walking pace afterwards, so a
## held walker catches back up along its own street route — never through a
## wall — and converges on the clock-derived spot every co-op peer computes.
##
## Also owns the other half of "who is out": NPCs whose MapNpc.hide_flag_key
## gets set leave on the spot (`despawn_flag_hidden`).
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _TownLife = preload("res://game_logic/world/TownLife.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _WalkCycle = preload("res://scenes/world/entities/WalkCycle.gd")
const _CritterDef = preload("res://game_logic/world/CritterDef.gd")

## The hero this close (world units) stops a walker for a chat.
const HOLD_RADIUS: float = 2.6
## A walker never falls further behind its loop than this (seconds).
const MAX_LAG: float = 45.0
## Seconds to fade a walker in or out at the edge of its hours.
const FADE_TIME: float = 0.8
const WALK_NODE: String = "TownWalk"

var _world: _WorldScene = null
var _plans: Dictionary = {}  # town → {npc id → walker}
var _lag: Dictionary = {}    # npc id → seconds behind the clock


## The walker loop for `npc_id` ({} when that NPC stays put).
func walker(npc_id: String) -> Dictionary:
	var town: String = npc_id.get_slice(":", 0)
	if not npc_id.contains(":") or not _RealmLayout.is_stitched(town):
		return {}
	if not _plans.has(town):
		_plans[town] = _plan_town(town)
	var plan: Dictionary = _plans[town]
	return plan.get(npc_id, {})


## Removes already-spawned NPCs whose MapNpc.hide_flag_key is now set. The spawn
## side of the same rule lives in ChunkRenderer, which skips them outright.
func despawn_flag_hidden() -> void:
	for nid: Variant in _world._active_npc_data.keys():
		var d: Dictionary = _world._active_npc_data[nid]
		var hide_flag: String = str(d.get("hide_flag_key", ""))
		if hide_flag == "" or not SceneManager.save_manager.get_story_flag(hide_flag):
			continue
		var node: Node3D = _world._valid_node3d(_world._npc_nodes.get(nid))
		if node != null:
			node.queue_free()
		_world._npc_nodes.erase(nid)
		_world._active_npc_data.erase(nid)


## Guards out on patrol (visible, lantern lit) — NightLights hangs a lantern on each.
func lanterns() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for nid: Variant in _world._npc_nodes:
		var w: Dictionary = walker(str(nid))
		if w.is_empty() or str(w["role"]) != _TownLife.ROLE_GUARD:
			continue
		var node: Node3D = _world._valid_node3d(_world._npc_nodes[nid])
		if node != null and node.is_inside_tree() and node.visible:
			out.append(node)
	return out


func _process(delta: float) -> void:
	if _world == null or not _world._is_infinite or _world._dnc == null or _world._player == null:
		return
	var tod: float = _world._dnc.get_time_of_day()
	var t: float = tod * _world.day_duration
	var hero: Vector3 = _world._player.global_position
	var besieged: String = _siege_town()
	for nid: Variant in _world._npc_nodes:
		var id: String = str(nid)
		var w: Dictionary = walker(id)
		if w.is_empty():
			continue
		var node: Node3D = _world._valid_node3d(_world._npc_nodes[nid])
		if node == null or not node.is_inside_tree():
			continue
		var out: bool = _TownLife.is_out(str(w["role"]), tod) and id.get_slice(":", 0) != besieged
		_drive(id, node, w, t, out, hero, delta)


func _drive(id: String, node: Node3D, w: Dictionary, t: float, out: bool, hero: Vector3, delta: float) -> void:
	var data: Dictionary = _world._active_npc_data.get(id, {})
	var to_hero := Vector2(hero.x - node.global_position.x, hero.z - node.global_position.z)
	var held: bool = out and node.visible and to_hero.length() <= HOLD_RADIUS
	var lag: float = float(_lag.get(id, 0.0))
	lag = minf(lag + delta, MAX_LAG) if held else maxf(lag - delta, 0.0)
	_lag[id] = lag
	var s: Dictionary = _TownLife.sample(w, t - lag)
	var shift: Vector2 = _RealmLayout.world_shift(id.get_slice(":", 0))
	var pos: Vector2 = (s["pos"] as Vector2) + shift
	node.global_position = Vector3(pos.x, _world.get_terrain_height(pos.x, pos.y), pos.y)
	data["x"] = pos.x
	data["z"] = pos.y
	data["hidden"] = not out
	var sprite: Sprite3D = _sprite_of(node)
	if sprite == null:
		return
	if node.get_node_or_null(WALK_NODE) == null:
		node.add_child(_WalkCycle.for_sprite(sprite, WALK_NODE))
	if held:
		sprite.flip_h = _CritterDef.faces_left(Vector3(to_hero.x, 0.0, to_hero.y))
	elif bool(s["moving"]):
		var dir: Vector2 = s["dir"]
		sprite.flip_h = _CritterDef.faces_left(Vector3(dir.x, 0.0, dir.y))
	var a: float = move_toward(sprite.modulate.a, 1.0 if out else 0.0, delta / FADE_TIME)
	sprite.modulate.a = a
	node.visible = a > 0.01


func _sprite_of(node: Node3D) -> Sprite3D:
	for c: Node in node.get_children():
		var s := c as Sprite3D
		if s != null:
			return s
	return null


## The stitched town under siege right now ("" = none): its folk stay indoors.
func _siege_town() -> String:
	if _world._coop_active and _world._coop_siege_active:
		return _world.story_place()
	var active: Dictionary = SceneManager.save_manager.town_siege.get_active_siege()
	return str(active.get("town", ""))


## TownLife.plan for `town` from its stitched NPCs (moved back into town-local units).
func _plan_town(town: String) -> Dictionary:
	var shift: Vector2 = _RealmLayout.world_shift(town)
	var npcs: Array[Dictionary] = []
	for e: Dictionary in _RealmLayout.entities("npcs"):
		if str(e.get("town", "")) != town:
			continue
		var local: Dictionary = e.duplicate()
		local["x"] = float(e.get("x", 0.0)) - shift.x
		local["z"] = float(e.get("z", 0.0)) - shift.y
		npcs.append(local)
	return _TownLife.plan(_RealmLayout.street_plan(town), _RealmLayout.hub_of(town), npcs, hash(town),
			_world.day_duration)
