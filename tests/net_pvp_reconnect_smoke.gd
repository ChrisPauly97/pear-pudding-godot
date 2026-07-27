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

const _Harness = preload("res://tests/net_harness.gd")

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
	var srv: Dictionary = _Harness.start_server(self, _PORT, 4)
	if srv.is_empty():
		return false
	var mp_server: SceneMultiplayer = srv["mp"]
	var server_root: Node = srv["root"]

	# --- first client subtree + peer (the one that will "drop") ---
	var cli: Dictionary = _Harness.start_client(self, _PORT)
	if cli.is_empty():
		return false
	var client_peer: ENetMultiplayerPeer = cli["peer"]
	var mp_client: SceneMultiplayer = cli["mp"]
	var client_root: Node = cli["root"]

	if not _Harness.wait_connected(mp_server, mp_client):
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
	# The disconnect handler lives on the BattleNet module (BattleScene's
	# networked surface), where NetworkManager.peer_disconnected is connected in
	# production; the state it sets (_pvp_ended, _pvp_reconnect_idx) is read back
	# off the BattleScene node below, which is where it still lives.
	var host_net: Node = host_battle.get("battle_net")
	if host_net == null:
		print("  [FAIL] host battle has no battle_net module")
		return false
	host_net.call("_on_pvp_peer_disconnected", first_client_id)
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
	var recon: Dictionary = _Harness.start_client(self, _PORT, "ReconnectRoot", "  [FAIL] reconnect create_client returned %d")
	if recon.is_empty():
		return false
	var mp_reconnect: SceneMultiplayer = recon["mp"]
	var reconnect_root: Node = recon["root"]

	# Two peers may transiently be visible right after queue_free(); require the
	# *new* peer's id specifically.
	var reconnected: bool = _Harness.pump([mp_server, mp_reconnect], 400, 10, func() -> bool:
		for pid in mp_server.get_peers():
			if int(pid) != first_client_id:
				return true
		return false)
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
