## Headless ENet loopback smoke test for the PvP *client scene launch* (GID-092 /
## TID-336). Complements tests/net_pvp_smoke.gd (which uses lightweight stubs):
## this one stands up two REAL BattleScene instances — host (idx 0) and client
## (idx 1) — over real ENet loopback and asserts the client launches and applies
## the host's first state mirror without crashing.
##
## Not part of the auto-discovered unit suite (needs real sockets + frame polling).
## Run on demand:
##
##   godot --headless --path . -s tests/net_pvp_client_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _PORT: int = 24570
const _BattlePacked := "res://scenes/battle/BattleScene.tscn"


func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_pvp_client_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	# --- server subtree + peer ---
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

	# --- client subtree + peer ---
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

	# Stand up the two REAL battle scenes. The host (idx 0) builds the canonical
	# state in _ready and broadcasts it; the client (idx 1) starts on a default
	# placeholder GameState and must sync from the mirror.
	var host_battle: Node = _make_battle(0)
	server_root.add_child(host_battle)
	var client_battle: Node = _make_battle(1)
	client_root.add_child(client_battle)
	print("  [PASS] both real BattleScenes launched without crashing in _ready")

	# Pump frames + poll. set_multiplayer subtrees aren't auto-polled by the loop,
	# so poll manually and drive the client's request_sync retry via _process.
	var synced := false
	for _j in range(180):
		mp_server.poll()
		mp_client.poll()
		if is_instance_valid(client_battle):
			client_battle._process(0.5)
		if is_instance_valid(host_battle):
			host_battle._process(0.5)
		mp_server.poll()
		mp_client.poll()
		OS.delay_msec(16)
		if int(client_battle.get("_last_applied_seq")) >= 0:
			synced = true
			break

	if not synced:
		print("  [FAIL] client never applied a host state mirror")
		return false
	print("  [PASS] client applied first mirror (seq=%d) with no crash" % int(client_battle.get("_last_applied_seq")))
	return true


func _make_battle(local_idx: int) -> Node:
	var packed: PackedScene = load(_BattlePacked)
	var b: Node = packed.instantiate()
	b.name = "BattleScene"  # fixed RPC path: <subroot>/BattleScene/BattleNetSync
	b.set("_pvp", true)
	b.set("_local_player_idx", local_idx)
	b.set("pvp_opponent_deck", [])
	b.set("enemy_data", {
		"display_name": "Player",
		"enemy_type": "",
		"is_boss": false,
		"drop_pool": [],
		"coin_reward": 0,
	})
	return b
