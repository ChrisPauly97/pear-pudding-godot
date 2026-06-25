## Headless ENet loopback smoke test for N-peer co-op + identity (GID-094).
##
## Not part of the auto-discovered unit suite (real sockets + frame polling). Run:
##
##   godot --headless --path . -s tests/net_coop_npeer_smoke.gd
##
## Exit code 0 = pass, 1 = fail. Proves, for a 3-peer session (host + 2 clients):
##   1. all three connect over 127.0.0.1 (host sees 2 peers);
##   2. a host avatar broadcast reaches BOTH clients;
##   3. a CLIENT identity broadcast reaches the OTHER client — i.e. the server-relay
##      path that N-peer rendering depends on (clients aren't directly connected in
##      ENet client-server; the host relays), carrying a PlayerIdentity payload.
extends SceneTree

const _NetSync = preload("res://scenes/world/NetSync.gd")
const _AvatarSync = preload("res://game_logic/net/AvatarSync.gd")
const _PlayerIdentity = preload("res://game_logic/net/PlayerIdentity.gd")

const _PORT: int = 24568


# Minimal stand-in for WorldScene: records decoded avatar + identity packets.
class _StubWorld:
	extends Node
	var avatars: Array = []        # decoded avatar dicts
	var identities: Dictionary = {}  # sender_id -> decoded identity dict
	func _on_avatar_received(_sender: int, payload: Array) -> void:
		avatars.append(_AvatarSync.decode(payload))
	func _on_identity_received(sender: int, payload: Array, _is_reply: bool) -> void:
		identities[sender] = _PlayerIdentity.decode(payload)


var _peers: Array = []  # [{mp, root, netsync, stub}]


func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_coop_npeer_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	# --- Host ---
	var server_peer := ENetMultiplayerPeer.new()
	var serr: Error = server_peer.create_server(_PORT, 3)  # 3 clients (TID-341 cap)
	if serr != OK:
		print("  [FAIL] create_server returned %d (loopback may be blocked)" % serr)
		return false
	var host := _make_peer("Host", server_peer)

	# --- Two clients ---
	var c1 := _make_peer("Client1", _make_client())
	if c1.is_empty():
		return false
	var c2 := _make_peer("Client2", _make_client())
	if c2.is_empty():
		return false

	# Poll until the host sees both clients (or timeout).
	var host_mp: MultiplayerAPI = host["mp"]
	var connected := false
	for _i in range(600):
		_poll_all()
		if host_mp.get_peers().size() >= 2:
			connected = true
			break
		OS.delay_msec(10)
	if not connected:
		print("  [FAIL] only %d/2 clients connected" % host_mp.get_peers().size())
		return false
	print("  [PASS] 3-peer session connected (host sees %d clients)" % host_mp.get_peers().size())

	# 2. Host avatar broadcast → both clients receive.
	(host["netsync"] as Node).rpc("recv_avatar", _AvatarSync.encode(5.0, -2.0, true, true))
	if not _wait(func() -> bool:
			return not (c1["stub"] as _StubWorld).avatars.is_empty() \
				and not (c2["stub"] as _StubWorld).avatars.is_empty()):
		print("  [FAIL] host avatar did not reach both clients")
		return false
	print("  [PASS] host avatar broadcast reached both clients")

	# 3. Client1 identity broadcast → must reach Client2 via the server relay.
	var ident: Array = _PlayerIdentity.encode("tok-c1", "Saimtar", Color(0.2, 0.7, 0.3))
	(c1["netsync"] as Node).rpc("recv_identity", ident, false)
	var c2_stub: _StubWorld = c2["stub"]
	if not _wait(func() -> bool: return not c2_stub.identities.is_empty()):
		print("  [FAIL] client->client identity did not arrive (server relay broken?)")
		return false
	var got: Dictionary = c2_stub.identities.values()[0]
	if str(got.get("name", "")) != "Saimtar" or str(got.get("token", "")) != "tok-c1":
		print("  [FAIL] relayed identity decoded wrong: %s" % str(got))
		return false
	print("  [PASS] client->client identity relayed and decoded correctly")
	return true


# --- helpers ---

func _make_client() -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client("127.0.0.1", _PORT)
	if err != OK:
		print("  [FAIL] create_client returned %d" % err)
		return null
	return peer

## Build a subtree (WorldScene/NetSync + Stub) scoped to its own SceneMultiplayer.
func _make_peer(label: String, peer: MultiplayerPeer) -> Dictionary:
	if peer == null:
		return {}
	var mp := SceneMultiplayer.new()
	var p_root := Node.new()
	p_root.name = "%sRoot" % label
	root.add_child(p_root)
	set_multiplayer(mp, p_root.get_path())
	mp.multiplayer_peer = peer
	var world := Node.new()
	world.name = "WorldScene"
	p_root.add_child(world)
	var netsync: Node = _NetSync.new()
	netsync.name = "NetSync"
	world.add_child(netsync)
	var stub := _StubWorld.new()
	stub.name = "Stub"
	world.add_child(stub)
	netsync.set("world_scene", stub)
	var entry := {"mp": mp, "root": p_root, "netsync": netsync, "stub": stub}
	_peers.append(entry)
	return entry

func _poll_all() -> void:
	for e in _peers:
		(e["mp"] as MultiplayerAPI).poll()

## Poll all peers up to ~2s, returning true as soon as `cond` holds.
func _wait(cond: Callable) -> bool:
	for _i in range(200):
		_poll_all()
		if bool(cond.call()):
			return true
		OS.delay_msec(10)
	return false
