## Regression tests for NetworkManager.is_session_peer() — the gate behind
## is_active() (claude/game-launch-multiplayer-bug-2312bs).
##
## The engine assigns a default OfflineMultiplayerPeer to `multiplayer` on
## launch, and that peer reports CONNECTION_CONNECTED with is_server() == true.
## Treating it as a live session made the first New Game after a fresh app
## launch start in co-op mode (WorldScene._setup_coop() activated, "Hosting"
## toast, party UI) until a menu round-trip called leave() and nulled the peer.
extends "res://tests/framework/test_case.gd"

const NM = preload("res://autoloads/NetworkManager.gd")

## Ephemeral port for the create_server test; well away from DEFAULT_PORT so a
## developer's live host session can't collide with the test run.
const _TEST_PORT: int = 34565


func test_null_peer_is_not_a_session() -> void:
	assert_false(NM.is_session_peer(null), "null peer must not read as a session")


func test_default_offline_peer_is_not_a_session() -> void:
	var offline := OfflineMultiplayerPeer.new()
	# Sanity-check the engine behaviour the bug depended on: the offline peer
	# really does claim to be connected.
	assert_eq(offline.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED,
		"OfflineMultiplayerPeer should report CONNECTED (the trap this gate exists for)")
	assert_false(NM.is_session_peer(offline),
		"the engine's default offline peer must not read as a session")


func test_unconnected_enet_peer_is_not_a_session() -> void:
	var enet := ENetMultiplayerPeer.new()
	assert_false(NM.is_session_peer(enet),
		"an ENet peer that never connected must not read as a session")


func test_hosting_enet_peer_is_a_session() -> void:
	var enet := ENetMultiplayerPeer.new()
	var err: Error = enet.create_server(_TEST_PORT, 1)
	assert_eq(err, OK, "test server should bind")
	if err == OK:
		assert_true(NM.is_session_peer(enet), "a hosting ENet peer is a session")
		enet.close()
