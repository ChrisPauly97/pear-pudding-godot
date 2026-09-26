## Headless smoke test for fighting in place (GID-135 / TID-528).
##
## With Battle Mode = Real-time, a solo battle opens over the live WorldScene:
## the world stays in the tree but frozen, its CanvasLayers (HUD) hide, the
## camera pushes in, and the battle overlay becomes current_scene. Leaving the
## battle thaws the world, restores the HUD and zooms back out — no wipe.
##
##   godot --headless --path . -s tests/in_world_battle_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _WORLD_SCENE_PATH: String = "res://scenes/world/WorldScene.tscn"
const _SceneFlow = preload("res://game_logic/SceneFlow.gd")

func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var fails: Array[String] = await _run()
	for f: String in fails:
		print("  [FAIL] " + f)
	print("\nin_world_battle_smoke: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)

func _wait(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

func _run() -> Array[String]:
	var fails: Array[String] = []
	var sm: Node = root.get_node_or_null("SceneManager")
	var save_manager: Object = sm.get("save_manager")
	save_manager.call("new_game", 1)
	save_manager.call("set_setting", "battle_mode", "realtime")
	var ws: Node = (load(_WORLD_SCENE_PATH) as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	sm.call("_transition_to", _SceneFlow.State.WORLD)
	await _wait(300)
	var cam: Camera3D = ws.get("_camera") as Camera3D
	var hud: CanvasLayer = ws.get_node_or_null("HUD") as CanvasLayer
	var cam_size: float = cam.size

	sm.call("_start_battle", {"enemy_type": "undead_basic", "is_boss": false,
		"enemy_deck": ["ghost", "ghost", "skeleton", "skeleton", "ghost", "ghost"]})
	await _wait(600)
	var battle: Node = current_scene
	if not ws.is_inside_tree():
		fails.append("world was detached instead of fought in place")
	if ws.process_mode != Node.PROCESS_MODE_DISABLED:
		fails.append("world not frozen during the battle")
	if battle == ws or battle == null or not bool(battle.get("in_world")):
		fails.append("battle overlay is not the in-world current scene")
	if hud != null and hud.visible:
		fails.append("world HUD still visible over the battle")
	if not (cam.size < cam_size * 0.9):
		fails.append("camera did not push in (%.2f -> %.2f)" % [cam_size, cam.size])

	sm.call("_finish_battle")
	sm.call("_restore_world")
	await _wait(600)
	if current_scene != ws:
		fails.append("world is not current_scene after the battle")
	if ws.process_mode != Node.PROCESS_MODE_INHERIT:
		fails.append("world still frozen after the battle")
	if hud != null and not hud.visible:
		fails.append("world HUD not restored")
	if absf(cam.size - cam_size) > 0.01:
		fails.append("camera did not zoom back out (%.2f vs %.2f)" % [cam.size, cam_size])
	if int(sm.call("current_state")) != _SceneFlow.State.WORLD:
		fails.append("SceneManager not back in WORLD state")
	return fails
