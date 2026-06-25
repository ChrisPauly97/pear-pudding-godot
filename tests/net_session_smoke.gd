## Headless smoke test for persistent multiplayer sessions (GID-095 / TID-348).
##
## Run on demand (not in the auto unit suite — needs real sockets + the SessionStore
## / SaveManager autoloads + frame polling):
##
##   godot --headless --path . -s tests/net_session_smoke.gd
##
## Exit code 0 = pass, 1 = fail. Proves end-to-end:
##   1. A client identifies (token A) over a real ENet loopback; the host (authority)
##      creates a seeded starter character and sends it via the real
##      NetSync.recv_character RPC; the client adopts a full 12-card deck.
##   2. After in-session progress (coins + a defeated enemy) is persisted and the
##      session is closed, RE-OPENING the same session id resumes the SAME character
##      (coins preserved) and the SAME world progress (defeated enemy preserved) —
##      i.e. reconnecting with token A restores the saved character, from disk.
##   3. Single-player save_slot_*.json is never created or touched by any of this.
extends SceneTree

const _NetSync = preload("res://scenes/world/NetSync.gd")

const _PORT: int = 24571
const _SESSION_ID: String = "smoke_session_pptcg"
const _TOKEN_A: String = "smoke_token_aaaa"


# Host-side stand-in for WorldScene's authority handlers. On a client's identity it
# resolves (or creates) that token's character via the real SessionStore and sends it.
# `store` is the SessionStore autoload node (fetched dynamically — autoload globals
# aren't resolvable at compile time in a bare `-s` main script).
class _HostStub:
	extends Node
	var net_sync: Node = null
	var store: Node = null
	func _on_identity_received(sender: int, payload: Array, _is_reply: bool) -> void:
		var token: String = str(payload[0]) if payload.size() > 0 else ""
		if token == "" or not store.is_open():
			return
		var st = store.get_state()
		var resume: bool = st != null and st.has_member(token)
		var rec: Dictionary = store.ensure_member(token, "Saimtar")
		net_sync.rpc_id(sender, "recv_character", rec, resume)


# Client-side stand-in: records the adopted character record.
class _ClientStub:
	extends Node
	var got_record: Dictionary = {}
	var got_resume: bool = false
	func _on_character_received(record: Dictionary, resume: bool) -> void:
		got_record = record
		got_resume = resume


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var ok: bool = _run()
	# Best-effort cleanup so repeat runs start clean.
	_cleanup()
	print("\nnet_session_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	# Fetch the real autoload nodes by path (autoload globals aren't resolvable at
	# compile time in the bare `-s` main script).
	var store: Node = root.get_node_or_null("SessionStore")
	if store == null:
		print("  [FAIL] SessionStore autoload not found under /root")
		return false
	_store = store

	# Record single-player save state up front to prove isolation later.
	var slot_existed_before: bool = FileAccess.file_exists("user://save_slot_1.json")

	# Fresh session file for a deterministic run.
	_cleanup()
	store.open(_SESSION_ID, "Smoke World")
	if not store.is_open():
		print("  [FAIL] SessionStore did not open")
		return false
	# Seed shared world progress the way the host does on co-op entry.
	var st = store.get_state()
	st.current_map = "madrian"
	st.world_seed = 4242

	# --- Phase 1: socket handshake → starter character delivered ---
	if not _socket_handshake(false):
		return false
	var client_stub: _ClientStub = _last_client_stub
	if client_stub.got_record.is_empty():
		print("  [FAIL] client did not receive a character record")
		return false
	var deck: Array = client_stub.got_record.get("player_deck", [])
	if deck.size() != 12:
		print("  [FAIL] expected a 12-card starter deck, got %d" % deck.size())
		return false
	if client_stub.got_resume:
		print("  [FAIL] first join should NOT be a resume")
		return false
	print("  [PASS] client adopted a fresh 12-card starter for token A")

	# --- Simulate in-session progress, then persist + close ---
	var rec: Dictionary = store.get_state().get_member(_TOKEN_A)
	rec["coins"] = 777
	store.update_member(_TOKEN_A, rec)
	store.get_state().defeated_enemies.append("smoke_enemy_1")
	store.mark_dirty()
	store.flush_now()
	store.close(true)
	if store.is_open():
		print("  [FAIL] SessionStore should be closed")
		return false
	if not FileAccess.file_exists("user://sessions/%s.json" % _SESSION_ID):
		print("  [FAIL] session file was not written to user://sessions/")
		return false
	print("  [PASS] progress persisted and session file written")

	# --- Phase 2: reconnect → resume the SAME character + world from disk ---
	store.open(_SESSION_ID, "Smoke World")
	var st2 = store.get_state()
	if not st2.has_member(_TOKEN_A):
		print("  [FAIL] reopened session lost token A's member")
		return false
	if not st2.defeated_enemies.has("smoke_enemy_1"):
		print("  [FAIL] reopened session lost world progress")
		return false
	# A second socket handshake with the same token must report resume + preserved coins.
	if not _socket_handshake(true):
		return false
	var client2: _ClientStub = _last_client_stub
	if not client2.got_resume:
		print("  [FAIL] reconnect should be flagged as a resume")
		return false
	if int(client2.got_record.get("coins", -1)) != 777:
		print("  [FAIL] reconnect did not restore the saved coins (got %s)"
			% str(client2.got_record.get("coins", -1)))
		return false
	print("  [PASS] reconnect resumed the same character (coins=777) + world progress")
	store.close(true)

	# --- Phase 3: single-player save isolation ---
	var slot_exists_after: bool = FileAccess.file_exists("user://save_slot_1.json")
	if slot_exists_after != slot_existed_before:
		print("  [FAIL] session persistence touched save_slot_1.json (isolation broken)")
		return false
	print("  [PASS] save_slot_*.json untouched by session persistence")
	return true


# Stash so _run can read the stub built inside _socket_handshake.
var _last_client_stub: _ClientStub = null
# The SessionStore autoload node, fetched in _run and reused by the host stub.
var _store: Node = null


## Stand up a real ENet host+client, have the client send its identity (token A) to
## the host, and pump frames until the client receives its character record. Returns
## false on any socket/timeout failure. Tears the peers down before returning.
func _socket_handshake(_is_reconnect: bool) -> bool:
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
	var host_world := Node.new()
	host_world.name = "WorldScene"
	server_root.add_child(host_world)
	var host_netsync: Node = _NetSync.new()
	host_netsync.name = "NetSync"
	host_world.add_child(host_netsync)
	var host_stub := _HostStub.new()
	host_stub.name = "Stub"
	host_stub.net_sync = host_netsync
	host_stub.store = _store
	host_world.add_child(host_stub)
	host_netsync.set("world_scene", host_stub)

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
	var client_world := Node.new()
	client_world.name = "WorldScene"
	client_root.add_child(client_world)
	var client_netsync: Node = _NetSync.new()
	client_netsync.name = "NetSync"
	client_world.add_child(client_netsync)
	var client_stub := _ClientStub.new()
	client_stub.name = "Stub"
	client_world.add_child(client_stub)
	client_netsync.set("world_scene", client_stub)
	_last_client_stub = client_stub

	# Wait for connect.
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

	# Client → host identity (token A); host replies with the character record.
	client_netsync.rpc_id(1, "recv_identity", [_TOKEN_A, "Saimtar", "ffffff"], false)
	var got := false
	for _j in range(300):
		mp_server.poll()
		mp_client.poll()
		if not client_stub.got_record.is_empty():
			got = true
			break
		OS.delay_msec(10)
	_teardown(server_root, client_root, server_peer, client_peer)
	if not got:
		print("  [FAIL] character record did not arrive over the socket")
		return false
	return true


func _teardown(server_root: Node, client_root: Node, server_peer: MultiplayerPeer, client_peer: MultiplayerPeer) -> void:
	client_peer.close()
	server_peer.close()
	client_root.queue_free()
	server_root.queue_free()


func _cleanup() -> void:
	var path: String = "user://sessions/%s.json" % _SESSION_ID
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
