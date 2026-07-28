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

	sm._on_battle_won({"hero_hp": 21})
	await create_timer(_TRANSITION_WAIT).timeout

	var ok: bool = _check(save.call("get_story_flag", "spire_floor_1_%d_cleared" % RUN_SEED),
		"floor-cleared flag set (unlocks the arena's exit door)")
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

	return ok


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
