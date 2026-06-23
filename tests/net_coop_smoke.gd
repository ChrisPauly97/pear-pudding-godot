## Headless ENet loopback smoke test for co-op (GID-090 / TID-325).
##
## Not part of the auto-discovered unit suite (it needs real sockets + frame
## polling, which the synchronous test framework can't drive). Run on demand:
##
##   godot --headless --path . -s tests/net_coop_smoke.gd
##
## Exit code 0 = pass, 1 = fail. Proves: a server and client ENet peer connect
## over 127.0.0.1, and an avatar payload sent via the real NetSync.gd RPC is
## received and decoded on the other peer using AvatarSync.
extends SceneTree

const _NetSync = preload("res://scenes/world/NetSync.gd")
const _AvatarSync = preload("res://game_logic/net/AvatarSync.gd")

const _PORT: int = 24567


# Minimal stand-in for WorldScene: records the decoded avatar packet it receives.
class _StubWorld:
	extends Node
	var received: Dictionary = {}
	func _on_avatar_received(_sender: int, payload: Array) -> void:
		received = _AvatarSync.decode(payload)


func _initialize() -> void:
	# Fire-and-forget coroutine; quits when done. Awaiting a frame first lets the
	# root window/tree settle so added nodes are inside_tree (RPC path resolution).
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_coop_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	# --- Server peer + subtree ---
	var server_peer := ENetMultiplayerPeer.new()
	var serr: Error = server_peer.create_server(_PORT, 4)
	if serr != OK:
		print("  [FAIL] create_server returned %d (loopback sockets may be blocked)" % serr)
		return false
	var mp_server := SceneMultiplayer.new()
	var server_root := Node.new()
	server_root.name = "ServerRoot"
	root.add_child(server_root)
	set_multiplayer(mp_server, server_root.get_path())
	mp_server.multiplayer_peer = server_peer
	var server_netsync: Node = _build_world(server_root)

	# --- Client peer + subtree ---
	var client_peer := ENetMultiplayerPeer.new()
	var cerr: Error = client_peer.create_client("127.0.0.1", _PORT)
	if cerr != OK:
		print("  [FAIL] create_client returned %d" % cerr)
		return false
	var mp_client := SceneMultiplayer.new()
	var client_root := Node.new()
	client_root.name = "ClientRoot"
	root.add_child(client_root)
	set_multiplayer(mp_client, client_root.get_path())
	mp_client.multiplayer_peer = client_peer
	_build_world(client_root)

	# Poll both APIs until the client connects (or timeout).
	var connected := false
	for _i in range(400):
		mp_server.poll()
		mp_client.poll()
		if mp_server.get_peers().size() > 0:
			connected = true
			break
		OS.delay_msec(10)
	if not connected:
		print("  [FAIL] peers did not connect within timeout")
		return false
	print("  [PASS] ENet loopback connected (server sees %d peer)" % mp_server.get_peers().size())

	# Server broadcasts an avatar packet; client should receive + decode it.
	var payload: Array = _AvatarSync.encode(12.5, -3.25, true, true)
	server_netsync.rpc("recv_avatar", payload)

	var client_stub: _StubWorld = client_root.get_node("WorldScene/Stub") as _StubWorld
	for _j in range(200):
		mp_server.poll()
		mp_client.poll()
		if not client_stub.received.is_empty():
			break
		OS.delay_msec(10)

	if client_stub.received.is_empty():
		print("  [FAIL] client did not receive the avatar RPC")
		return false

	var d: Dictionary = client_stub.received
	var x_ok: bool = absf(float(d["x"]) - 12.5) < 0.001
	var z_ok: bool = absf(float(d["z"]) - (-3.25)) < 0.001
	var flip_ok: bool = bool(d["flip_h"])
	var move_ok: bool = bool(d["moving"])
	if x_ok and z_ok and flip_ok and move_ok:
		print("  [PASS] avatar packet received and decoded correctly")
		return true
	print("  [FAIL] decoded packet mismatch: %s" % str(d))
	return false


# Builds WorldScene/NetSync (+ a _StubWorld sibling "Stub") under `parent`,
# wires the NetSync's world_scene to the stub, and returns the NetSync node.
func _build_world(parent: Node) -> Node:
	var world := Node.new()
	world.name = "WorldScene"
	parent.add_child(world)
	var netsync: Node = _NetSync.new()
	netsync.name = "NetSync"
	world.add_child(netsync)
	var stub := _StubWorld.new()
	stub.name = "Stub"
	world.add_child(stub)
	netsync.set("world_scene", stub)
	return netsync
