## Headless ENet loopback smoke test for PvP duel reconnect (GID-102 / TID-372).
## Mirrors tests/net_pvp_client_smoke.gd's two-real-BattleScene setup, then simulates
## the client peer dropping mid-duel and a NEW connection reconnecting via
## announce_reconnect. Asserts the host does NOT immediately forfeit (grace window
## active) and resumes (cancels the grace timer, re-mirrors) once the reconnect lands.
##
## peer_disconnected is simulated via a direct call to the host's handler rather than
## a real socket-level drop: this test's two BattleScene instances live in separate
## custom SceneMultiplayer subtrees (same pattern as net_pvp_client_smoke.gd), which
## are invisible to the NetworkManager autoload's own peer_connected/disconnected
## relay — exactly like that file, real per-frame engine signal delivery isn't
## exercised here, only the RPC wire behavior once a handler fires.
##
## Not part of the auto-discovered unit suite (needs real sockets + frame polling).
## Run on demand:
##
##   godot --headless --path . -s tests/net_pvp_reconnect_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _PORT: int = 24571
const _BattlePacked := "res://scenes/battle/BattleScene.tscn"


func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_pvp_reconnect_smoke: %s" % ("PASS" if ok else "FAIL"))
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

	# --- first client subtree + peer (the one that will "drop") ---
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

	var connected := false
	for _i in range(400):
		mp_server.poll()
		mp_client.poll()
		if mp_server.get_peers().size() > 0:
			connected = true
			break
		OS.delay_msec(10)
	if not connected:
		print("  [FAIL] first client did not connect within timeout")
		return false
	var first_client_id: int = mp_server.get_peers()[0]
	print("  [PASS] first client connected (peer_id=%d)" % first_client_id)

	var host_battle: Node = _make_battle(0)
	server_root.add_child(host_battle)
	var client_battle: Node = _make_battle(1)
	client_root.add_child(client_battle)

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
		print("  [FAIL] first client never applied a host state mirror")
		return false
	print("  [PASS] duel started, first client synced (seq=%d)" % int(client_battle.get("_last_applied_seq")))

	# --- simulate the client dropping mid-duel ---
	host_battle.call("_on_pvp_peer_disconnected", first_client_id)
	if bool(host_battle.get("_pvp_ended")):
		print("  [FAIL] host forfeited immediately instead of starting a grace window")
		return false
	if int(host_battle.get("_pvp_reconnect_idx")) != 1:
		print("  [FAIL] host did not record a pending reconnect for idx 1")
		return false
	print("  [PASS] disconnect started a grace window, no immediate forfeit")

	client_root.queue_free()
	client_peer.close()

	# --- a NEW connection reconnects ---
	var reconnect_peer := ENetMultiplayerPeer.new()
	var rerr: Error = reconnect_peer.create_client("127.0.0.1", _PORT)
	if rerr != OK:
		print("  [FAIL] reconnect create_client returned %d" % rerr)
		return false
	var mp_reconnect := SceneMultiplayer.new()
	var reconnect_root := Node.new()
	reconnect_root.name = "ReconnectRoot"
	root.add_child(reconnect_root)
	set_multiplayer(mp_reconnect, reconnect_root.get_path())
	mp_reconnect.multiplayer_peer = reconnect_peer

	var reconnected := false
	for _i in range(400):
		mp_server.poll()
		mp_reconnect.poll()
		# Two peers may transiently be visible right after queue_free(); require
		# the *new* peer's id specifically.
		for pid in mp_server.get_peers():
			if int(pid) != first_client_id:
				reconnected = true
				break
		if reconnected:
			break
		OS.delay_msec(10)
	if not reconnected:
		print("  [FAIL] reconnecting peer did not connect within timeout")
		return false
	print("  [PASS] reconnecting peer connected")

	var reconnect_battle: Node = _make_battle(1)
	reconnect_root.add_child(reconnect_battle)  # _ready() sends announce_reconnect

	var resumed := false
	for _j in range(180):
		mp_server.poll()
		mp_reconnect.poll()
		if is_instance_valid(reconnect_battle):
			reconnect_battle._process(0.5)
		if is_instance_valid(host_battle):
			host_battle._process(0.5)
		mp_server.poll()
		mp_reconnect.poll()
		OS.delay_msec(16)
		if int(host_battle.get("_pvp_reconnect_idx")) == -1 and int(reconnect_battle.get("_last_applied_seq")) >= 0:
			resumed = true
			break
	if not resumed:
		print("  [FAIL] reconnect did not resolve (host still mid-grace or client never synced)")
		return false
	if bool(host_battle.get("_pvp_ended")):
		print("  [FAIL] host ended the duel (forfeit) instead of resuming")
		return false
	print("  [PASS] host resumed (grace window cancelled, no forfeit), reconnecting client synced (seq=%d)" \
		% int(reconnect_battle.get("_last_applied_seq")))
	return true


func _make_battle(local_idx: int) -> Node:
	var packed: PackedScene = load(_BattlePacked)
	var b: Node = packed.instantiate()
	b.name = "BattleScene"  # fixed RPC path: <subroot>/BattleScene/BattleNetSync
	b.set("_pvp", true)
	b.set("_local_player_idx", local_idx)
	b.set("pvp_opponent_deck", [])
	# Empty pvp_opponent_token (host side, local_idx 0) exercises the documented
	# same-LAN "accept any reconnect" fallback — a real two-process test can't share
	# distinct MpProfile tokens anyway (it's a single-process singleton autoload).
	b.set("enemy_data", {
		"display_name": "Player",
		"enemy_type": "",
		"is_boss": false,
		"drop_pool": [],
		"coin_reward": 0,
	})
	return b
