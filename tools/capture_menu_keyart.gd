## Captures the main-menu key art (GID-143 / TID-606): Madrian at twilight, HUD,
## name tags and quest beacons hidden. Run under a virtual display, then save as
## assets/textures/ui/menu_keyart.jpg (quality 88):
##   TOD=0.765 PX=14 PZ=4 OUT=/tmp/keyart.png xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capture_menu_keyart.gd
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for _i in 5:
		await process_frame
	var sm: Node = root.get_node("SceneManager")
	var save: Object = sm.get("save_manager")
	save.call("new_game", false)
	save.set("time_of_day", float(OS.get_environment("TOD")) if OS.get_environment("TOD") != "" else 0.74)
	for tip in ["rt_intro", "cantrips", "coins", "mana", "tap_and_hold"]:
		save.call("set_story_flag", "seen_tutorial_" + tip)
	var ws: Node = (load("res://scenes/world/WorldScene.tscn") as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	await process_frame
	var player: Node3D = ws.get("_player")
	player.position = Vector3(float(OS.get_environment("PX")), player.position.y, float(OS.get_environment("PZ")))
	for _i in 150:
		await process_frame
	for c in ws.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	for n: Node in ws.find_children("*", "Label3D", true, false):
		(n as Label3D).visible = false
	for n: Node in ws.find_children("ObjectiveBeacon*", "", true, false):
		(n as Node3D).visible = false
	for _i in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	quit()
