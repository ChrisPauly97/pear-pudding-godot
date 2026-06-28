## Headless smoke test for co-op world-object sync (GID-096).
##
## Run on demand (not in the auto unit suite — needs real sockets + the SessionStore
## autoload + frame polling):
##
##   godot --headless --path . -s tests/net_world_sync_smoke.gd
##
## Exit code 0 = pass, 1 = fail. Proves end-to-end:
##   1. Over a real ENet loopback, the authority's discrete world events
##      (enemy_removed, chest_opened) reach the client via the real NetSync RPCs and
##      decode correctly with WorldObjectSync.
##   2. A late-join world snapshot (removed enemies + opened chests) reaches the
##      client and decodes.
##   3. An enemy position batch reaches the client and decodes with EnemySync.
##   4. The authority persists a defeated enemy + an opened chest into the GID-095
##      session file; RE-OPENING the same session resumes both from disk.
##   5. Single-player save_slot_*.json is never created or touched.
extends SceneTree

const _NetSync = preload("res://scenes/world/NetSync.gd")
const _WorldObjectSync = preload("res://game_logic/net/WorldObjectSync.gd")
const _EnemySync = preload("res://game_logic/net/EnemySync.gd")

const _PORT: int = 24573
const _SESSION_ID: String = "smoke_worldsync_pptcg"


# Client-side stand-in for WorldScene's world-sync receivers — records what arrives.
class _ClientStub:
	extends Node
	var events: Array = []          # [{kind, id}, ...]
	var snapshot: Dictionary = {}   # {removed_enemies, opened_objects}
	var positions: Array = []       # [{id, x, z, alive}, ...]
	func _on_world_event_received(_sender: int, payload: Array) -> void:
		events.append(_WorldObjectSync.decode_event(payload))
	func _on_world_snapshot_received(payload: Array) -> void:
		snapshot = _WorldObjectSync.decode_snapshot(payload)
	func _on_enemy_positions_received(payload: Array) -> void:
		positions = _EnemySync.decode_batch(payload)


var _store: Node = null
var _client_stub: _ClientStub = null


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var ok: bool = _run()
	_cleanup()
	print("\nnet_world_sync_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	_store = root.get_node_or_null("SessionStore")
	if _store == null:
		print("  [FAIL] SessionStore autoload not found under /root")
		return false

	var slot_existed_before: bool = FileAccess.file_exists("user://save_slot_1.json")

	# --- Phase 1: live RPC reflection over a real socket ---
	if not _socket_phase():
		return false

	# --- Phase 2: persistence + reconnect via SessionStore ---
	_cleanup()
	_store.open(_SESSION_ID, "Smoke World")
	if not _store.is_open():
		print("  [FAIL] SessionStore did not open")
		return false
	var st = _store.get_state()
	st.current_map = "madrian"
	# Simulate the authority recording a defeat + an open chest.
	st.defeated_enemies.append("orc_7")
	st.opened_chests.append("dc_3")
	_store.mark_dirty()
	_store.flush_now()
	_store.close(true)
	if not FileAccess.file_exists("user://sessions/%s.json" % _SESSION_ID):
		print("  [FAIL] session file was not written")
		return false

	_store.open(_SESSION_ID, "Smoke World")
	var st2 = _store.get_state()
	if not st2.defeated_enemies.has("orc_7"):
		print("  [FAIL] reopened session lost the defeated enemy")
		return false
	if not st2.opened_chests.has("dc_3"):
		print("  [FAIL] reopened session lost the opened chest")
		return false
	print("  [PASS] defeated enemy + opened chest resumed from the session file")
	_store.close(true)

	# --- Phase 3: single-player save isolation ---
	var slot_exists_after: bool = FileAccess.file_exists("user://save_slot_1.json")
	if slot_exists_after != slot_existed_before:
		print("  [FAIL] world-sync persistence touched save_slot_1.json (isolation broken)")
		return false
	print("  [PASS] save_slot_*.json untouched by session persistence")
	return true


func _socket_phase() -> bool:
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
	_build_world(client_root, true)

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

	# Authority broadcasts discrete events + a snapshot + a position batch.
	host_netsync.rpc("recv_world_event",
		_WorldObjectSync.encode_event(_WorldObjectSync.EV_ENEMY_REMOVED, "orc_7"))
	host_netsync.rpc("recv_world_event",
		_WorldObjectSync.encode_event(_WorldObjectSync.EV_CHEST_OPENED, "dc_3"))
	host_netsync.rpc("recv_world_snapshot",
		_WorldObjectSync.encode_snapshot(["orc_7", "orc_8"], ["dc_3"]))
	host_netsync.rpc("recv_enemy_positions", _EnemySync.encode_batch([
		_EnemySync.encode_state("orc_9", 5.0, -2.0, true)]))

	var ok := false
	for _j in range(300):
		mp_server.poll()
		mp_client.poll()
		if _client_stub.events.size() >= 2 and not _client_stub.snapshot.is_empty() \
				and not _client_stub.positions.is_empty():
			ok = true
			break
		OS.delay_msec(10)
	_teardown(server_root, client_root, server_peer, client_peer)
	if not ok:
		print("  [FAIL] world-sync packets did not all arrive over the socket")
		return false

	# Validate decoded contents.
	var kinds: Array = []
	var ids: Array = []
	for e in _client_stub.events:
		kinds.append(str((e as Dictionary).get("kind", "")))
		ids.append(str((e as Dictionary).get("id", "")))
	if not (kinds.has(_WorldObjectSync.EV_ENEMY_REMOVED) and kinds.has(_WorldObjectSync.EV_CHEST_OPENED)):
		print("  [FAIL] events missing expected kinds: %s" % str(kinds))
		return false
	if not (ids.has("orc_7") and ids.has("dc_3")):
		print("  [FAIL] events missing expected ids: %s" % str(ids))
		return false
	print("  [PASS] enemy_removed + chest_opened events reflected on the client")

	var removed: Array = _client_stub.snapshot.get("removed_enemies", [])
	var opened: Array = _client_stub.snapshot.get("opened_objects", [])
	if not (removed.has("orc_7") and removed.has("orc_8") and opened.has("dc_3")):
		print("  [FAIL] snapshot contents wrong: %s" % str(_client_stub.snapshot))
		return false
	print("  [PASS] late-join world snapshot reflected on the client")

	var pos0: Dictionary = _client_stub.positions[0]
	if str(pos0.get("id", "")) != "orc_9" or absf(float(pos0.get("x", 0.0)) - 5.0) > 0.001:
		print("  [FAIL] enemy position batch wrong: %s" % str(_client_stub.positions))
		return false
	print("  [PASS] enemy position batch reflected on the client")
	return true


# Builds WorldScene/NetSync under `parent`. The client side also gets a _ClientStub
# wired as the NetSync's world_scene (stashed in _client_stub).
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
	return netsync


func _teardown(server_root: Node, client_root: Node, server_peer: MultiplayerPeer, client_peer: MultiplayerPeer) -> void:
	client_peer.close()
	server_peer.close()
	client_root.queue_free()
	server_root.queue_free()


func _cleanup() -> void:
	var path: String = "user://sessions/%s.json" % _SESSION_ID
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
