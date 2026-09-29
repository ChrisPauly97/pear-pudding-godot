## Two-process co-op check on the overworld (BID-063). Starts a real host or
## client game, enters the shared co-op map and prints a RESULT line with the
## map, the world seed and how many remote avatars it sees. Run the host first:
##   ROLE=host godot --headless --path . -s tools/coop_overworld_check.gd &
##   sleep 4; ROLE=client godot --headless --path . -s tools/coop_overworld_check.gd
## Pass: both print map=main, the same seed, and the client sees remotes=1.
extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for _i in 5:
		await process_frame
	var nm: Node = root.get_node("NetworkManager")
	var sm: Node = root.get_node("SceneManager")
	var save: Object = sm.get("save_manager")
	var role: String = OS.get_environment("ROLE")
	save.call("new_game", false)
	if role == "host":
		print("host err=", nm.call("host", 24611))
	else:
		print("join err=", nm.call("join", "127.0.0.1", 24611))
		var t0: int = Time.get_ticks_msec()
		while not bool(nm.call("is_active")) or root.multiplayer.multiplayer_peer.get_connection_status() != 2:
			await process_frame
			if Time.get_ticks_msec() - t0 > 10000:
				print("RESULT client: never connected")
				quit(1)
				return
	sm.call("enter_map_coop", "main")
	var t1: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < (26000 if role == "host" else 14000):
		await process_frame
	var ws: Node = current_scene
	var remotes: Dictionary = ws.get("_remote_player_nodes") if ws != null else {}
	print("RESULT %s: scene=%s map=%s infinite=%s remotes=%d seed=%s" % [role, ws.name if ws else "null",
		str(ws.get("map_name")), str(ws.get("_is_infinite")), remotes.size(), str(save.get("world_seed"))])
	quit(0)
