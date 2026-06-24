## Headless ENet loopback smoke test for PvP card battles (GID-091 / TID-333).
##
## Not part of the auto-discovered unit suite (it needs real sockets + frame
## polling, which the synchronous test framework can't drive). Run on demand:
##
##   godot --headless --path . -s tests/net_pvp_smoke.gd
##
## Exit code 0 = pass, 1 = fail. Proves the full PvP round-trip over real ENet
## loopback: the client sends an intent via the BattleNetSync relay, the host
## applies it to the canonical GameState and broadcasts the encoded state mirror,
## and the client receives a mirror whose seq/state reflect the applied action.
extends SceneTree

const _BattleNetSync = preload("res://scenes/battle/BattleNetSync.gd")
const _Proto = preload("res://game_logic/net/BattleNetProtocol.gd")
const _GameState = preload("res://game_logic/battle/GameState.gd")

const _PORT: int = 24568


# Host stand-in: owns the canonical GameState, applies relayed intents, broadcasts.
class _HostStub:
	extends Node
	var net: Node = null
	var state = null  # GameState
	var seq: int = 0
	func _on_pvp_intent(_sender: int, payload: Dictionary) -> void:
		var intent: Dictionary = _Proto.decode_intent(payload)
		if str(intent["type"]) == _Proto.INTENT_END_TURN:
			state.end_turn()
		seq += 1
		net.rpc("sync_state", _Proto.encode_state(state.to_dict(), seq))
	func _on_pvp_sync_request() -> void:
		seq += 1
		net.rpc("sync_state", _Proto.encode_state(state.to_dict(), seq))


# Client stand-in: records the last decoded mirror.
class _ClientStub:
	extends Node
	var received: Dictionary = {}
	func _on_pvp_state(payload: Dictionary) -> void:
		received = _Proto.decode_state(payload)


func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_pvp_smoke: %s" % ("PASS" if ok else "FAIL"))
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
	server_root.name = "SrvRoot"
	root.add_child(server_root)
	set_multiplayer(mp_server, server_root.get_path())
	mp_server.multiplayer_peer = server_peer
	var host_stub := _HostStub.new()
	host_stub.state = _GameState.new()
	var server_net: Node = _build_battle(server_root, host_stub)
	host_stub.net = server_net

	# --- Client peer + subtree ---
	var client_peer := ENetMultiplayerPeer.new()
	var cerr: Error = client_peer.create_client("127.0.0.1", _PORT)
	if cerr != OK:
		print("  [FAIL] create_client returned %d" % cerr)
		return false
	var mp_client := SceneMultiplayer.new()
	var client_root := Node.new()
	client_root.name = "CliRoot"
	root.add_child(client_root)
	set_multiplayer(mp_client, client_root.get_path())
	mp_client.multiplayer_peer = client_peer
	var client_stub := _ClientStub.new()
	var client_net: Node = _build_battle(client_root, client_stub)

	# Poll until connected.
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

	# Canonical state starts on player 0's turn; the client ends the turn.
	var before_idx: int = int(host_stub.state.current_player_idx)
	client_net.rpc_id(1, "send_intent", _Proto.encode_end_turn())

	for _j in range(200):
		mp_server.poll()
		mp_client.poll()
		if not client_stub.received.is_empty():
			break
		OS.delay_msec(10)

	if client_stub.received.is_empty():
		print("  [FAIL] client did not receive a state mirror")
		return false

	var decoded: Dictionary = client_stub.received
	if not bool(decoded["valid"]):
		print("  [FAIL] received mirror was invalid")
		return false
	var mirror_state: Dictionary = decoded["state"]
	var after_idx: int = int(mirror_state.get("current_player_idx", before_idx))
	if int(decoded["seq"]) >= 1 and after_idx == 1 - before_idx:
		print("  [PASS] intent applied on host, mirror reflects turn flip (seq=%d, idx %d->%d)" % [int(decoded["seq"]), before_idx, after_idx])
		return true
	print("  [FAIL] mirror did not reflect the applied end_turn (seq=%d, idx %d->%d)" % [int(decoded["seq"]), before_idx, after_idx])
	return false


# Builds BattleScene/BattleNetSync under `parent` (path matches on both peers),
# wires the relay's battle_scene back-reference to `stub`, returns the relay node.
func _build_battle(parent: Node, stub: Node) -> Node:
	var battle := Node.new()
	battle.name = "BattleScene"
	parent.add_child(battle)
	var net: Node = _BattleNetSync.new()
	net.name = "BattleNetSync"
	battle.add_child(net)
	net.set("battle_scene", stub)
	battle.add_child(stub)
	return net
