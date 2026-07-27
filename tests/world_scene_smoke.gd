## Headless structural smoke test for scenes/world/WorldScene.tscn and its NetSync
## RPC dispatch surface.
##
## Not part of the auto-discovered unit suite (tests/runner.gd) — it instantiates
## the real scene, drives real _process frames, and needs `await`, which the
## synchronous test framework can't do. Run on demand:
##
##   godot --headless --path . -s tests/world_scene_smoke.gd
##
## Exit code 0 = pass, 1 = fail. Proves:
##   1. WorldScene.tscn instantiates, _ready() completes, and the node survives
##      several _process frames without crashing (fresh new_game(1), map_name "main").
##   2. The subsystems _ready() actually builds (HUD, WorldHUD, Minimap,
##      ChunkStreamingManager, DayNightCycle, entity root, player) exist afterward.
##   3. Every `_on_*` handler name that scenes/world/NetSync.gd's `_route()` can
##      dispatch to (parsed from NetSync.gd's own source at runtime — never
##      hardcoded, so this keeps working as handlers are added, renamed, or moved)
##      is actually reachable through a real `_route()` call and runs without
##      taking WorldScene out of the tree.
##
## IMPORTANT — why this drives NetSync._route() instead of asserting
## ws.has_method(name): NetSync no longer dispatches straight to WorldScene. It
## routes through a shared `_route(method, args)` helper that tries `world_scene`
## first, then every module registered via `register_handler()` (WorldScene's
## `_ensure_coop_modules()` registers CoopSession, CoopSocial, CoopActivities and
## CoopPvP — see scenes/world/coop/*.gd). About a third of the 77 handlers already live on those
## modules, not on WorldScene itself. Asserting `ws.has_method()` directly would
## therefore fail on every one of those *by design*, which is a false alarm, not a
## regression. Calling the real `_route()` is both the accurate existence check
## (a false/no-handler result prints "NetSync: no handler for ...") and the actual
## dispatch-and-call in one authentic step — and it stays correct no matter which
## node a future refactor moves a handler to, which is the whole point of this test.
##
## GDScript has no try/catch, so a handler that hits a real runtime error (e.g. an
## out-of-bounds array index) prints a Godot error but does not abort this script —
## the sweep continues and the final in-tree check still passes. The one known
## exception is documented in _UNSAFE_TO_CALL_COLD below: it is excluded from the
## live-call sweep (but still required to exist, checked without invoking it) so
## its genuine defect doesn't get accidentally papered over by "well, nothing
## crashed."
extends SceneTree

const _NetSyncScriptPath: String = "res://scenes/world/NetSync.gd"
const _WorldScenePath: String = "res://scenes/world/WorldScene.tscn"
const _NetSyncScript = preload("res://scenes/world/NetSync.gd")

## Handlers known to be unsafe to invoke cold, with the concrete reason — found by
## reading the handler + the *Sync helper it calls, not guessed. Still required to
## pass the existence check in part 3a (checked without calling it); only skipped
## in the live dispatch sweep in part 3b. Do not add an entry here to dodge a test
## bug — only a genuine pre-existing crash earns a spot.
const _UNSAFE_TO_CALL_COLD: Dictionary = {}

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var ok: bool = await _run()
	print("\nworld_scene_smoke: %s" % ("PASS" if ok else "FAIL"))
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
	var save_manager: Object = sm.get("save_manager")
	if save_manager == null:
		print("  [FAIL] SceneManager.save_manager not found")
		return false
	save_manager.call("new_game", 1)

	var packed: PackedScene = load(_WorldScenePath)
	var ws: Node = packed.instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	# In real play WorldScene IS the tree's current_scene — some handlers (e.g.
	# _on_coop_spire_run_ended_received) reach for get_tree().current_scene to parent
	# an overlay. Setting it here keeps the cold-call sweep realistic rather than
	# papering over a null current_scene that would never occur in the real game.
	current_scene = ws

	var ok: bool = _check(is_instance_valid(ws), "WorldScene.tscn instantiated")
	if not is_instance_valid(ws):
		return false

	# --- Part 1: _ready() completes and the node survives several frames ---
	for _i in 10:
		await process_frame
	ok = _check(is_instance_valid(ws) and ws.is_inside_tree(),
		"WorldScene survived 10 process frames after _ready()") and ok

	# --- Part 2: expected subsystems built in _ready() ---
	ok = _check(ws.get("_hud") is CanvasLayer, "_hud CanvasLayer exists") and ok
	ok = _check(ws.get("_world_hud") != null, "_world_hud (WorldHUD) built") and ok
	ok = _check(ws.get("_minimap") != null, "_minimap (Minimap) built") and ok
	ok = _check(ws.get("_csm") != null, "_csm (ChunkStreamingManager) built") and ok
	ok = _check(ws.get("_dnc") != null, "_dnc (DayNightCycle) built") and ok
	ok = _check(ws.get("_entity_root") != null, "_entity_root (Entities Node3D) built") and ok
	var player: Object = ws.get("_player")
	ok = _check(player != null and is_instance_valid(player), "_player spawned") and ok
	ok = _check(ws.get_node_or_null("WorldHUD") != null,
		"WorldHUD child node present") and ok
	ok = _check(ws.get_node_or_null("ChunkStreamingManager") != null,
		"ChunkStreamingManager child node present") and ok
	ok = _check(ws.get_node_or_null("DayNightCycle") != null,
		"DayNightCycle child node present") and ok
	ok = _check(ws.get_node_or_null("Entities") != null,
		"Entities child node present") and ok

	# --- Wire a real NetSync + co-op modules WITHOUT a live network peer ---
	# _setup_coop() itself is gated on NetworkManager.is_active() (no session here)
	# and also does button/signal wiring unrelated to RPC dispatch, so we replicate
	# only its two dispatch-relevant lines: create the fixed-name NetSync child, and
	# call WorldScene's own _ensure_coop_modules() so it builds + registers whatever
	# co-op handler modules currently exist — no module names hardcoded here, this
	# just runs WorldScene's real setup code for that one piece.
	var net_sync: Node = _NetSyncScript.new()
	net_sync.name = "NetSync"
	net_sync.set("world_scene", ws)
	ws.add_child(net_sync)
	ws.set("_net_sync", net_sync)
	ws.call("_ensure_coop_modules")

	# --- Part 3: parse NetSync's handler surface, then check + sweep it ---
	var handler_names: Array = _parse_netsync_handlers()
	ok = _check(handler_names.size() >= 70,
		"parsed a plausible number of NetSync handler names (%d found)" % handler_names.size()) and ok

	# 3a: every parsed handler must resolve to a real method somewhere in the
	# dispatch chain (WorldScene itself, or a registered co-op module) — checked
	# without invoking, via has_method on each candidate _route() would try.
	var missing: Array = []
	for h in handler_names:
		if not _handler_resolves(ws, net_sync, h):
			missing.append(h)
	ok = _check(missing.is_empty(),
		"every parsed NetSync handler resolves to a real method somewhere NetSync._route() looks (missing: %s)"
		% str(missing)) and ok

	# 3b: call each handler for real through NetSync._route(), the actual production
	# dispatch path — this both proves dispatch reaches a live method and exercises
	# that method with synthesized dummy arguments in the same step.
	var called: int = 0
	var dispatch_failed: Array = []
	var skipped: Array = []
	for h in handler_names:
		if _UNSAFE_TO_CALL_COLD.has(h):
			skipped.append(h)
			continue
		var owner: Object = _resolve_owner(ws, net_sync, h)
		if owner == null:
			continue  # already reported as missing above; nothing to call
		var args: Array = _synthesize_args(owner, h)
		var routed: bool = bool(net_sync.call("_route", h, args))
		if not routed:
			dispatch_failed.append(h)
		called += 1
	ok = _check(dispatch_failed.is_empty(),
		"NetSync._route() successfully dispatched every called handler (failed: %s)"
		% str(dispatch_failed)) and ok
	# Let any handler that deferred work (call_deferred, signals) settle before the
	# final liveness check.
	await process_frame
	ok = _check(is_instance_valid(ws) and ws.is_inside_tree(),
		("WorldScene still valid & in-tree after sweeping %d/%d handlers " +
		"(%d skipped as unsafe-cold: %s)")
		% [called, handler_names.size(), skipped.size(), str(skipped)]) and ok

	ws.free()
	return ok


## Parses scenes/world/NetSync.gd's own source for every shape it uses to name a
## dispatch target handler. Current NetSync routes every RPC through a shared
## `_route(method: String, args: Array)` helper that does the has_method()/callv()
## dispatch itself (`_route("_on_avatar_received", [sender, payload])`), but this
## also matches the older direct-dispatch shapes (`world_scene.has_method("_on_...")`
## / `world_scene._on_...(`) so it keeps working across either style. Deliberately
## not hardcoded — this list grows automatically as NetSync grows, which is the
## whole point of this test.
func _parse_netsync_handlers() -> Array:
	var f: FileAccess = FileAccess.open(_NetSyncScriptPath, FileAccess.READ)
	if f == null:
		return []
	var src: String = f.get_as_text()
	f.close()
	var names: Dictionary = {}  # used as an ordered set
	var patterns: Array[String] = [
		"_route\\(\"(_on_\\w+)\"",         # current: shared _route(method, args) helper
		"has_method\\(\"(_on_\\w+)\"\\)",  # older: direct world_scene.has_method(...) guard
		"world_scene\\.(_on_\\w+)\\(",     # older: direct world_scene._on_...(...) call
	]
	for pat in patterns:
		var re := RegEx.new()
		re.compile(pat)
		for m in re.search_all(src):
			names[m.get_string(1)] = true
	var out: Array = names.keys()
	out.sort()
	return out


## Mirrors NetSync._route()'s own search order (world_scene, then each registered
## module in _handlers) to find which live object actually owns `handler`, without
## invoking it. Returns null if none do.
func _resolve_owner(ws: Node, net_sync: Node, handler: String) -> Object:
	if ws.has_method(handler):
		return ws
	var handlers: Array = net_sync.get("_handlers")
	if handlers != null:
		for h in handlers:
			if is_instance_valid(h) and (h as Object).has_method(handler):
				return h
	return null


func _handler_resolves(ws: Node, net_sync: Node, handler: String) -> bool:
	return _resolve_owner(ws, net_sync, handler) != null


## Builds one synthesized dummy argument per parameter `handler` declares on
## `target`, using get_method_list()'s reflected arg types (never a hardcoded
## per-handler arg list, so this also survives handlers being added/changed).
func _synthesize_args(target: Object, handler: String) -> Array:
	for m: Dictionary in target.get_method_list():
		if str(m.get("name", "")) != handler:
			continue
		var out: Array = []
		for a: Dictionary in (m.get("args", []) as Array):
			out.append(_dummy_for_type(int(a.get("type", TYPE_NIL))))
		return out
	return []


func _dummy_for_type(t: int) -> Variant:
	match t:
		TYPE_INT:
			return 1
		TYPE_FLOAT:
			return 0.0
		TYPE_BOOL:
			return false
		TYPE_STRING, TYPE_STRING_NAME:
			return ""
		TYPE_ARRAY:
			return []
		TYPE_DICTIONARY:
			return {}
		_:
			return null
