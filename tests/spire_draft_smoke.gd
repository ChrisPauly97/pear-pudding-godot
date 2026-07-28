## Drives a full Endless Spire floor victory through the real SceneManager.
##
## The regression this guards (drafting-dungeon-stuck): _spire_battle_won parented
## the SpireDraftScene to get_tree().current_scene immediately after calling
## _restore_world(). _restore_world defers its scene swap behind
## TransitionManager's 0.2 s fade, so current_scene was still the battle overlay
## that _finish_battle had just queue_free()d — the draft became its child and was
## destroyed with it at the end of the frame. Clearing a floor showed no draft at
## all, and the run continued with the same deck.
##
## Nothing in the synchronous unit runner can catch that: it drives tests from
## SceneTree._initialize, where SceneManager.get_tree() is still null and no frame
## ever passes, so the fade never resolves and the overlay is never reparented.
## This test uses real frames and real timers instead.
extends SceneTree

const _SpireFloorGen = preload("res://game_logic/spire/SpireFloorGen.gd")

var _pass_count: int = 0
var _fail_count: int = 0

# Long enough for TransitionManager's fade-out + callback + fade-in (0.2 s each).
const _TRANSITION_WAIT: float = 1.0


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var ok: bool = await _run()
	print("\nspire_draft_smoke: %s" % ("PASS" if ok else "FAIL"))
	print("  (%d checks passed, %d failed)" % [_pass_count, _fail_count])
	quit(0 if ok else 1)


func _check(cond: bool, msg: String) -> bool:
	if cond:
		_pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		_fail_count += 1
		print("  [FAIL] %s" % msg)
	return cond


func _run() -> bool:
	var sm: Node = root.get_node_or_null("SceneManager")
	if sm == null:
		print("  [FAIL] SceneManager autoload not found under /root")
		return false
	var save: Object = sm.get("save_manager")
	if save == null:
		print("  [FAIL] SceneManager.save_manager not found")
		return false

	const RUN_SEED: int = 4242
	# SpireFloorGen persists each floor to user://maps/, so a leftover file from a
	# previous run would be loaded instead of generated — and an old one still
	# carries the pre-fix shared enemy id. Start from nothing.
	_purge_generated_floors(RUN_SEED)
	save.call("start_spire_run", RUN_SEED)
	sm.map_stack.push_back("madrian")
	sm.door_stack.push_back("")
	sm.current_map = "spire_floor_1_%d" % RUN_SEED

	# Stand up what a battle leaves behind: the world detached into
	# _saved_world_scene, a battle overlay sitting in current_scene.
	var world := Node.new()
	world.name = "SpireFloorStandIn"
	root.add_child(world)
	current_scene = world
	sm.set("_saved_world_scene", world)
	root.remove_child(world)

	var battle := Node.new()
	battle.name = "BattleStandIn"
	root.add_child(battle)
	current_scene = battle
	sm.set("_battle_overlay", battle)
	sm.set("_state", 2)  # State.BATTLE
	# What WorldScene's engage path sets. Without it _spire_battle_won never calls
	# mark_enemy_defeated, and the cross-floor spawn suppression below can't
	# reproduce — the check would pass for the wrong reason.
	sm.set("_current_battle_enemy_id", _SpireFloorGen.enemy_id_for(1, RUN_SEED))

	sm._on_battle_won({"hero_hp": 21})
	await create_timer(_TRANSITION_WAIT).timeout

	var ok: bool = _check(save.call("get_story_flag", "spire_floor_1_%d_cleared" % RUN_SEED),
		"floor-cleared flag set (unlocks the arena's exit door)")
	ok = _check(save.call("is_enemy_defeated", _SpireFloorGen.enemy_id_for(1, RUN_SEED)),
		"floor 1's enemy recorded as defeated") and ok
	ok = _check(current_scene == world, "world scene restored as current_scene") and ok

	var overlay: Variant = sm.get("_spire_draft_overlay")
	ok = _check(is_instance_valid(overlay), "draft overlay survived the battle teardown") and ok
	if not is_instance_valid(overlay):
		# Everything below inspects the overlay; without it there is nothing left
		# to check and the regression has already reproduced.
		return false
	ok = _check(overlay.get_parent() == world,
		"draft parented to the restored world, not the dying battle overlay") and ok
	ok = _check(sm.call("is_spire_draft_open"), "is_spire_draft_open() reports the owed pick") and ok
	ok = _check(_descendants(overlay) > 3, "draft built its card UI") and ok

	# The overlay doesn't pause world input, so the exit door must hold the floor
	# until the pick is made — otherwise walking out silently discards the card.
	sm.exit_map()
	await create_timer(_TRANSITION_WAIT).timeout
	ok = _check(sm.current_map == "spire_floor_1_%d" % RUN_SEED,
		"exit door does not advance the floor while a pick is owed") and ok
	ok = _check(int(save.call("get_spire_run").get("floor", 0)) == 1,
		"run stays on floor 1 while a pick is owed") and ok

	var picked_card: String = _first_pickable_card(overlay)
	ok = _check(picked_card != "", "draft offered at least one card to pick") and ok
	if picked_card == "":
		return false
	overlay.call("_on_pick", picked_card)
	await create_timer(_TRANSITION_WAIT).timeout

	ok = _check(not sm.call("is_spire_draft_open"), "draft closes once a card is picked") and ok
	var run: Dictionary = save.call("get_spire_run")
	var deck: Array = run.get("draft_deck", [])
	ok = _check(deck.has(picked_card), "picked card landed in the run's draft deck") and ok

	# With the pick made, the door works and the run climbs.
	sm.exit_map()
	await create_timer(_TRANSITION_WAIT).timeout
	ok = _check(int(save.call("get_spire_run").get("floor", 0)) == 2, "exit door advances to floor 2") and ok
	ok = _check(sm.current_map == "spire_floor_2_%d" % RUN_SEED, "floor 2 map loaded") and ok

	# Floor 2 must actually have an enemy. Every floor used to emit the literal id
	# "spire_enemy", and defeated_enemies is a permanent, map-agnostic list — so
	# beating floor 1 suppressed the spawn on every floor after it.
	# ChunkRenderer._spawn_entities skipped it, the cleared flag was never set and
	# the exit door (its only flag_key) stayed locked: an empty arena with no way
	# forward and no way out.
	ok = _check(not save.call("is_enemy_defeated", _SpireFloorGen.enemy_id_for(2, RUN_SEED)),
		"floor 2's enemy is not pre-marked defeated") and ok
	ok = _check(_spawned_enemy_count() > 0, "floor 2 spawned its enemy") and ok
	ok = _check(not save.call("get_story_flag", "spire_floor_2_%d_cleared" % RUN_SEED),
		"floor 2 starts uncleared (its door is locked until the kill)") and ok

	return _check_legacy_save_repair(save) and ok


## Repairs-an-old-save check: a save written before SpireFloorGen.enemy_id_for()
## carries the shared "spire_enemy" kill, and its user://maps/ floors still use
## that id. Loading an uncleared floor must clear it so the arena isn't empty.
func _check_legacy_save_repair(save: Object) -> bool:
	save.call("start_spire_run", 999)
	save.call("mark_enemy_defeated", "spire_enemy")
	save.call("mark_enemy_defeated", "map_some_real_enemy")
	save.call("prepare_spire_floor", 2, 999)
	var ok: bool = _check(not save.call("is_enemy_defeated", "spire_enemy"),
		"legacy shared 'spire_enemy' kill cleared when an uncleared floor loads")
	ok = _check(save.call("is_enemy_defeated", "map_some_real_enemy"),
		"non-Spire kills are left untouched by the repair") and ok

	# A floor the player already beat and is standing on must not resurrect.
	save.call("set_story_flag", "spire_floor_3_999_cleared")
	save.call("mark_enemy_defeated", _SpireFloorGen.enemy_id_for(3, 999))
	save.call("prepare_spire_floor", 3, 999)
	ok = _check(save.call("is_enemy_defeated", _SpireFloorGen.enemy_id_for(3, 999)),
		"a cleared floor's enemy stays defeated") and ok
	return ok


## Deletes any previously generated floor maps for `run_seed`.
func _purge_generated_floors(run_seed: int) -> void:
	var dir: DirAccess = DirAccess.open("user://maps")
	if dir == null:
		return
	for fname: String in dir.get_files():
		if fname.begins_with("spire_floor_") and fname.contains("_%d." % run_seed):
			dir.remove(fname)


## Live enemy nodes under the current world scene.
func _spawned_enemy_count() -> int:
	var world: Node = current_scene
	if world == null:
		return 0
	var count: int = 0
	for n: Node in _walk(world):
		if n.get("enemy_data") != null and n.has_method("engage"):
			count += 1
	return count


## Total descendants under `n` — an overlay that built nothing has almost none.
func _descendants(n: Node) -> int:
	var total: int = 0
	for c in n.get_children():
		total += 1 + _descendants(c)
	return total


## The card id behind the first enabled "Pick" button, found by walking the
## overlay's tree — the draft rolls its offers from the run seed, so nothing here
## can hard-code one.
func _first_pickable_card(overlay: Node) -> String:
	for node: Node in _walk(overlay):
		if not (node is Button):
			continue
		var btn := node as Button
		if btn.disabled or btn.text != "Pick":
			continue
		for conn: Dictionary in btn.pressed.get_connections():
			var cb: Callable = conn.get("callable")
			var bound: Array = cb.get_bound_arguments()
			if bound.size() == 1 and bound[0] is String:
				return str(bound[0])
	return ""


func _walk(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_walk(c))
	return out
