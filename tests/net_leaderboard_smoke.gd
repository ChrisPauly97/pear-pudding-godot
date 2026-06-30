## Headless smoke test for the ranked leaderboard RPCs (GID-102 / TID-373).
##
## Run on demand (not in the auto unit suite — needs real sockets + frame polling):
##
##   godot --headless --path . -s tests/net_leaderboard_smoke.gd
##
## Exit code 0 = pass, 1 = fail. Proves end-to-end over a real ENet loopback:
##   1. The authority's recv_leaderboard broadcast reaches the client via the real
##      NetSync RPC and the row dicts decode with the exact SessionState.get_leaderboard
##      shape ({token, name, rating, games, wins, losses}).
##   2. A client's submit_leaderboard_request reaches the authority (mirrors the
##      party-bounty submit_party_bounty_progress pattern).
extends SceneTree

const _NetSync = preload("res://scenes/world/NetSync.gd")
const _SessionState = preload("res://game_logic/net/SessionState.gd")

const _PORT: int = 24576


# Server-side stand-in for WorldScene — records inbound refresh requests.
class _ServerStub:
	extends Node
	var requests: Array = []  # sender peer ids
	func _on_leaderboard_request_submitted(sender: int) -> void:
		requests.append(sender)


# Client-side stand-in for WorldScene — records what arrives.
class _ClientStub:
	extends Node
	var rows: Array = []
	func _on_leaderboard_received(received_rows: Array) -> void:
		rows = received_rows


var _server_stub: _ServerStub = null
var _client_stub: _ClientStub = null


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_leaderboard_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	var server_peer := ENetMultiplayerPeer.new()
	if server_peer.create_server(_PORT, 4) != OK:
		print("  [FAIL] create_server failed (loopback blocked?)")
		return false
	var mp_server := SceneMultiplayer.new()
	var server_root := Node.new()
	server_root.name = "ServerRoot"
	root.add_child(server_root)
	set_multiplayer(mp_server, server_root.get_path())
	mp_server.multiplayer_peer = server_peer
	var host_netsync: Node = _build_world(server_root, false)

	var client_peer := ENetMultiplayerPeer.new()
	if client_peer.create_client("127.0.0.1", _PORT) != OK:
		print("  [FAIL] create_client failed")
		return false
	var mp_client := SceneMultiplayer.new()
	var client_root := Node.new()
	client_root.name = "ClientRoot"
	root.add_child(client_root)
	set_multiplayer(mp_client, client_root.get_path())
	mp_client.multiplayer_peer = client_peer
	var client_netsync: Node = _build_world(client_root, true)

	var connected := false
	for _i in range(400):
		mp_server.poll()
		mp_client.poll()
		if mp_server.get_peers().size() > 0:
			connected = true
			break
		OS.delay_msec(10)
	if not connected:
		print("  [FAIL] peers did not connect")
		_teardown(server_root, client_root, server_peer, client_peer)
		return false
	print("  [PASS] ENet loopback connected")

	# Build a realistic leaderboard via the real SessionState (TID-370 shape) and
	# broadcast it exactly as WorldScene._broadcast_leaderboard does.
	var st := _SessionState.new()
	st.ensure_member("tok_a", "Alice")
	st.ensure_member("tok_b", "Bob")
	var rec_a: Dictionary = st.get_member("tok_a")
	rec_a["pvp_rating"] = 1200
	rec_a["pvp_games"] = 5
	rec_a["pvp_wins"] = 4
	rec_a["pvp_losses"] = 1
	st.update_member("tok_a", rec_a)
	var rec_b: Dictionary = st.get_member("tok_b")
	rec_b["pvp_rating"] = 950
	rec_b["pvp_games"] = 3
	rec_b["pvp_wins"] = 1
	rec_b["pvp_losses"] = 2
	st.update_member("tok_b", rec_b)
	var rows: Array = st.get_leaderboard(20)

	host_netsync.rpc("recv_leaderboard", rows)

	var ok := false
	for _j in range(300):
		mp_server.poll()
		mp_client.poll()
		if _client_stub.rows.size() >= 2:
			ok = true
			break
		OS.delay_msec(10)
	if not ok:
		print("  [FAIL] recv_leaderboard did not reach the client")
		_teardown(server_root, client_root, server_peer, client_peer)
		return false

	# Validate decoded shape + ordering (rating desc — Alice 1200 before Bob 950).
	var first: Dictionary = _client_stub.rows[0]
	var second: Dictionary = _client_stub.rows[1]
	if str(first.get("token", "")) != "tok_a" or int(first.get("rating", 0)) != 1200:
		print("  [FAIL] leaderboard row 0 wrong: %s" % str(first))
		_teardown(server_root, client_root, server_peer, client_peer)
		return false
	if str(second.get("token", "")) != "tok_b" or int(second.get("rating", 0)) != 950:
		print("  [FAIL] leaderboard row 1 wrong: %s" % str(second))
		_teardown(server_root, client_root, server_peer, client_peer)
		return false
	if str(first.get("name", "")) != "Alice" or int(first.get("wins", 0)) != 4 \
			or int(first.get("losses", 0)) != 1 or int(first.get("games", 0)) != 5:
		print("  [FAIL] leaderboard row 0 missing fields: %s" % str(first))
		_teardown(server_root, client_root, server_peer, client_peer)
		return false
	print("  [PASS] recv_leaderboard reached the client with correct shape + ordering")

	# Client requests a refresh; authority should see it.
	client_netsync.rpc_id(1, "submit_leaderboard_request")
	var req_ok := false
	for _k in range(300):
		mp_server.poll()
		mp_client.poll()
		if _server_stub.requests.size() >= 1:
			req_ok = true
			break
		OS.delay_msec(10)
	_teardown(server_root, client_root, server_peer, client_peer)
	if not req_ok:
		print("  [FAIL] submit_leaderboard_request did not reach the authority")
		return false
	print("  [PASS] submit_leaderboard_request reached the authority")
	return true


# Builds WorldScene/NetSync under `parent`. The client side gets a _ClientStub wired
# as the NetSync's world_scene; the server side gets a _ServerStub.
func _build_world(parent: Node, is_client: bool) -> Node:
	var world := Node.new()
	world.name = "WorldScene"
	parent.add_child(world)
	var netsync: Node = _NetSync.new()
	netsync.name = "NetSync"
	world.add_child(netsync)
	if is_client:
		var stub := _ClientStub.new()
		stub.name = "Stub"
		world.add_child(stub)
		netsync.set("world_scene", stub)
		_client_stub = stub
	else:
		var stub := _ServerStub.new()
		stub.name = "Stub"
		world.add_child(stub)
		netsync.set("world_scene", stub)
		_server_stub = stub
	return netsync


func _teardown(server_root: Node, client_root: Node, server_peer: MultiplayerPeer, client_peer: MultiplayerPeer) -> void:
	client_peer.close()
	server_peer.close()
	client_root.queue_free()
	server_root.queue_free()
