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
## Walkers farther than this from the hero (beyond the iso view) are driven every
## FAR_EVERY-th frame, round-robin, with the time they skipped (GID-162). Their
## position is a pure function of the clock, so they land exactly where they would
## have; they just step coarsely while nobody can see them.
const FAR_RADIUS: float = 40.0
const FAR_EVERY: int = 6
## Seconds between siege-town re-reads and record pruning.
const SLOW_INTERVAL: float = 1.0

var _world: _WorldScene = null
var _plans: Dictionary = {}  # town → {npc id → walker}
var _lag: Dictionary = {}    # npc id → seconds behind the clock
var _skipped: Dictionary = {}  # npc id → seconds not yet driven (far walkers)
var _frame: int = 0
## Per-NPC lookups resolved once per spawned node (GID-164 / TID-676):
## npc id → {"node" (raw, may be freed), "w" walker ({} = stays put), "town",
## "shift", "sprite", "walk"}. Rebuilt when the id's node changes.
var _recs: Dictionary = {}
var _besieged: String = ""
var _slow_left: float = 0.0


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
	# The clock only steps at 2 Hz (lighting); walkers sampled from it jumped
	# every 0.5 s and stood still between — the smooth reading moves them per frame.
	var tod: float = _world._dnc.get_smooth_time_of_day()
	var t: float = tod * _world.day_duration
	var hero: Vector3 = _world._player.global_position
	_slow_left -= delta
	if _slow_left <= 0.0:
		_slow_left = SLOW_INTERVAL
		_besieged = _siege_town()
		_prune_recs()
	_frame += 1
	var slot: int = 0
	for nid: Variant in _world._npc_nodes:
		var raw: Variant = _world._npc_nodes[nid]
		var rec: Dictionary = _recs.get(nid, {})
		if rec.is_empty() or not is_same(rec["node"], raw):
			rec = _make_rec(str(nid), raw)
			_recs[nid] = rec
		var w: Dictionary = rec["w"]
		if w.is_empty():
			continue
		var node: Node3D = _world._valid_node3d(raw)
		if node == null or not node.is_inside_tree():
			continue
		slot += 1
		var id: String = str(nid)
		var dt: float = delta + float(_skipped.get(id, 0.0))
		var p: Vector3 = node.global_position
		if Vector2(hero.x - p.x, hero.z - p.z).length_squared() > FAR_RADIUS * FAR_RADIUS \
				and (slot + _frame) % FAR_EVERY != 0:
			_skipped[id] = dt
			continue
		if dt != delta:
			_skipped.erase(id)
		var out: bool = _TownLife.is_out(str(w["role"]), tod) and str(rec["town"]) != _besieged
		_drive(id, node, rec, t, out, hero, dt)


## The cached lookups for one spawned NPC node.
func _make_rec(id: String, raw: Variant) -> Dictionary:
	var rec: Dictionary = {"node": raw, "w": walker(id), "sprite": null, "walk": null}
	var w: Dictionary = rec["w"]
	if w.is_empty():
		return rec
	var town: String = id.get_slice(":", 0)
	rec["town"] = town
	rec["shift"] = _RealmLayout.world_shift(town)
	var node: Node3D = _world._valid_node3d(raw)
	if node != null:
		var sprite: Sprite3D = _sprite_of(node)
		rec["sprite"] = sprite
		if sprite != null:
			var walk: Node = node.get_node_or_null(WALK_NODE)
			if walk == null:
				walk = _WalkCycle.for_sprite(sprite, WALK_NODE)
				node.add_child(walk)
			walk.set_process(false)  # stepped from _drive
			var wc: _WalkCycle = walk as _WalkCycle
			rec["walk"] = wc if wc != null and wc.has_tracks() else null
	return rec


func _prune_recs() -> void:
	for nid: Variant in _recs.keys():
		if not _world._npc_nodes.has(nid):
			_recs.erase(nid)


func _drive(id: String, node: Node3D, rec: Dictionary, t: float, out: bool, hero: Vector3, delta: float) -> void:
	var w: Dictionary = rec["w"]
	var data: Dictionary = _world._active_npc_data.get(id, {})
	var to_hero := Vector2(hero.x - node.global_position.x, hero.z - node.global_position.z)
	var held: bool = out and node.visible and to_hero.length() <= HOLD_RADIUS
	var lag: float = float(_lag.get(id, 0.0))
	lag = minf(lag + delta, MAX_LAG) if held else maxf(lag - delta, 0.0)
	_lag[id] = lag
	var s: Dictionary = _TownLife.sample(w, t - lag)
	var shift: Vector2 = rec["shift"]
	var pos: Vector2 = (s["pos"] as Vector2) + shift
	node.global_position = Vector3(pos.x, _world.get_terrain_height(pos.x, pos.y), pos.y)
	data["x"] = pos.x
	data["z"] = pos.y
	data["hidden"] = not out
	if not is_instance_valid(rec["sprite"]):
		return
	var sprite: Sprite3D = rec["sprite"]
	if is_instance_valid(rec["walk"]):
		var walk: _WalkCycle = rec["walk"]
		walk.tick(delta)
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
