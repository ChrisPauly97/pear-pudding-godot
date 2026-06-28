## Headless smoke test for dedicated-server PvP referee (GID-097 / TID-353).
##
## Not part of the auto-discovered unit suite (needs real sockets + frame polling).
## Run on demand:
##
##   godot --headless --path . -s tests/net_pvp_dedicated_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
##
## Proves the 3-peer referee round-trip over real ENet loopback:
##   Server (peer 1) runs BattleScene with _local_player_idx=-1 (headless referee).
##   Client A (player 0) and Client B (player 1) each run a real BattleScene.
##   Client A sends an end_turn intent; the referee applies it and broadcasts the
##   updated state; both clients receive a mirror that reflects the turn flip.
extends SceneTree

const _BattlePacked := "res://scenes/battle/BattleScene.tscn"
const _Proto = preload("res://game_logic/net/BattleNetProtocol.gd")

const _PORT: int = 24575


func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_pvp_dedicated_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	# --- Referee peer (server, peer_id=1) ---
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

	var server_connected_peers: Array[int] = []
	mp_server.peer_connected.connect(func(id: int) -> void: server_connected_peers.append(id))

	# --- Client A peer (will be player 0) ---
	var peer_a := ENetMultiplayerPeer.new()
	if peer_a.create_client("127.0.0.1", _PORT) != OK:
		print("  [FAIL] create_client A failed")
		return false
	var mp_a := SceneMultiplayer.new()
	var root_a := Node.new()
	root_a.name = "CliA"
	root.add_child(root_a)
	set_multiplayer(mp_a, root_a.get_path())
	mp_a.multiplayer_peer = peer_a

	# --- Client B peer (will be player 1) ---
	var peer_b := ENetMultiplayerPeer.new()
	if peer_b.create_client("127.0.0.1", _PORT) != OK:
		print("  [FAIL] create_client B failed")
		return false
	var mp_b := SceneMultiplayer.new()
	var root_b := Node.new()
	root_b.name = "CliB"
	root.add_child(root_b)
	set_multiplayer(mp_b, root_b.get_path())
	mp_b.multiplayer_peer = peer_b

	# Poll until fully connected — wait for peer_connected signals AND unique IDs.
	var fully_connected := false
	for _i in range(800):
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		if server_connected_peers.size() >= 2 and mp_a.get_unique_id() > 0 and mp_b.get_unique_id() > 0:
			fully_connected = true
			break
		OS.delay_msec(10)
	if not fully_connected:
		print("  [FAIL] not fully connected within timeout (server_peers=%d)" % server_connected_peers.size())
		return false

	var peer_a_id: int = mp_a.get_unique_id()
	var peer_b_id: int = mp_b.get_unique_id()
	print("  [PASS] all three peers connected (a_id=%d, b_id=%d)" % [peer_a_id, peer_b_id])

	# Build shared minimal 12-card decks so _build_pvp_decks doesn't crash.
	var deck_a: Array[String] = []
	var deck_b: Array[String] = []
	for _ci in 6:
		deck_a.append("ghost")
		deck_a.append("skeleton")
		deck_b.append("wraith")
		deck_b.append("zombie")

	# --- Instantiate BattleScene on each peer ---
	var referee: Node = _make_battle(-1, [], {peer_a_id: 0, peer_b_id: 1}, deck_a, deck_b)
	server_root.add_child(referee)

	var battle_a: Node = _make_battle(0, deck_b, {}, [], [])
	root_a.add_child(battle_a)

	var battle_b: Node = _make_battle(1, deck_a, {}, [], [])
	root_b.add_child(battle_b)

	print("  [PASS] BattleScene instantiated on all three peers without crashing in _ready")

	# Pump frames until both clients receive the initial state mirror from the referee.
	var initial_synced := false
	for _j in range(240):
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		if is_instance_valid(referee):
			referee._process(0.5)
		if is_instance_valid(battle_a):
			battle_a._process(0.5)
		if is_instance_valid(battle_b):
			battle_b._process(0.5)
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		OS.delay_msec(16)
		var a_seq: int = int(battle_a.get("_last_applied_seq"))
		var b_seq: int = int(battle_b.get("_last_applied_seq"))
		if a_seq >= 0 and b_seq >= 0:
			initial_synced = true
			break

	var init_a_seq: int = int(battle_a.get("_last_applied_seq"))
	var init_b_seq: int = int(battle_b.get("_last_applied_seq"))
	if not initial_synced:
		print("  [FAIL] clients did not receive initial mirror (a_seq=%d, b_seq=%d)" % [init_a_seq, init_b_seq])
		return false
	print("  [PASS] both clients received initial referee mirror (A seq=%d, B seq=%d)" % [init_a_seq, init_b_seq])

	# --- Client A (player 0) sends end_turn intent to the referee ---
	var a_net: Node = battle_a.get_node_or_null("BattleNetSync")
	if a_net == null:
		print("  [FAIL] client A BattleNetSync not found")
		return false
	a_net.rpc_id(1, "send_intent", _Proto.encode_end_turn())

	var intent_done := false
	for _k in range(300):
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		if is_instance_valid(referee):
			referee._process(0.5)
		if is_instance_valid(battle_a):
			battle_a._process(0.5)
		if is_instance_valid(battle_b):
			battle_b._process(0.5)
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		OS.delay_msec(10)
		var ia: int = int(battle_a.get("_last_applied_seq"))
		var ib: int = int(battle_b.get("_last_applied_seq"))
		if ia > init_a_seq and ib > init_b_seq:
			intent_done = true
			break

	var final_a_seq: int = int(battle_a.get("_last_applied_seq"))
	var final_b_seq: int = int(battle_b.get("_last_applied_seq"))
	if not intent_done:
		print("  [FAIL] clients did not receive updated mirror after end_turn (a=%d, b=%d)" % [final_a_seq, final_b_seq])
		return false

	# Confirm the turn actually flipped in the referee's canonical state.
	var ref_state: Object = referee.get("_state")
	if ref_state == null:
		print("  [FAIL] referee _state is null")
		return false
	var cur_idx: int = int(ref_state.get("current_player_idx"))
	if cur_idx != 1:
		print("  [FAIL] after client A end_turn, expected current_player_idx=1, got %d" % cur_idx)
		return false

	print("  [PASS] referee applied client A end_turn; turn flipped to player %d" % cur_idx)
	print("  [PASS] both clients received updated mirror (A seq=%d, B seq=%d)" % [final_a_seq, final_b_seq])

	peer_a.close()
	peer_b.close()
	server_peer.close()
	return true


func _make_battle(local_idx: int, opponent_deck: Array, peer_to_idx: Dictionary,
		p0_deck: Array, p1_deck: Array) -> Node:
	var packed: PackedScene = load(_BattlePacked)
	var b: Node = packed.instantiate()
	b.name = "BattleScene"
	b.set("_pvp", true)
	b.set("_local_player_idx", local_idx)
	b.set("pvp_opponent_deck", opponent_deck)
	b.set("pvp_player0_deck", p0_deck)
	b.set("pvp_player1_deck", p1_deck)
	b.set("_pvp_peer_to_idx", peer_to_idx)
	b.set("enemy_data", {
		"display_name": "Player",
		"enemy_type": "",
		"is_boss": false,
		"drop_pool": [],
		"coin_reward": 0,
	})
	return b
