## Shared ENet loopback bootstrap for tests/net_*_smoke.gd (see CLAUDE.md's
## "Running Tests" section for how these standalone `extends SceneTree`
## scripts are invoked).
##
## Every smoke test stands up one or more ENetMultiplayerPeer server/client
## pairs, each scoped to its own SceneMultiplayer subtree, polls until
## connected, then exercises a real RPC path. This file collects that
## repeated peer/subtree bootstrap and poll-loop code so each smoke test only
## states what's different about it.
##
## Not a test itself: it has no assertions and never calls quit(). Preload it
## as a const (per CLAUDE.md's class_name rule) rather than relying on
## autoload registration:
##   const _Harness = preload("res://tests/net_harness.gd")
##
## `set_multiplayer()` is a SceneTree method (not a Node method), so every
## helper that needs it takes the SceneTree in as `tree` — pass `self` from
## a smoke test's own `extends SceneTree` script.
extends RefCounted


## Creates a bare ENet server peer listening on `port`, without building a
## SceneMultiplayer subtree (for callers that manage the subtree themselves,
## e.g. because several peers share custom bookkeeping). On failure, prints
## `fail_msg` (formatted with the Error code if it contains "%d") and
## returns null.
static func make_server_peer(port: int, max_peers: int,
		fail_msg: String = "  [FAIL] create_server returned %d (loopback sockets may be blocked)") -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_peers)
	if err != OK:
		if fail_msg.find("%d") >= 0:
			print(fail_msg % err)
		else:
			print(fail_msg)
		return null
	return peer


## Creates a bare ENet client peer connecting to 127.0.0.1:`port`, without
## building a SceneMultiplayer subtree. On failure, prints `fail_msg`
## (formatted with the Error code if it contains "%d") and returns null.
static func make_client_peer(port: int,
		fail_msg: String = "  [FAIL] create_client returned %d") -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client("127.0.0.1", port)
	if err != OK:
		if fail_msg.find("%d") >= 0:
			print(fail_msg % err)
		else:
			print(fail_msg)
		return null
	return peer


## Wraps `peer` in its own SceneMultiplayer, parented under a fresh subroot of
## `tree.root` named `subroot_name`. Returns {"mp": SceneMultiplayer, "root": Node}.
static func make_peer_subtree(tree: SceneTree, peer: MultiplayerPeer, subroot_name: String) -> Dictionary:
	var mp := SceneMultiplayer.new()
	var subroot := Node.new()
	subroot.name = subroot_name
	tree.root.add_child(subroot)
	tree.set_multiplayer(mp, subroot.get_path())
	mp.multiplayer_peer = peer
	return {"mp": mp, "root": subroot}


## Creates an ENet server peer + its SceneMultiplayer subtree in one step.
## Returns {} (after printing the failure) on error, else
## {"peer": ENetMultiplayerPeer, "mp": SceneMultiplayer, "root": Node}.
static func start_server(tree: SceneTree, port: int, max_peers: int, subroot_name: String = "SrvRoot",
		fail_msg: String = "  [FAIL] create_server returned %d (loopback sockets may be blocked)") -> Dictionary:
	var peer: ENetMultiplayerPeer = make_server_peer(port, max_peers, fail_msg)
	if peer == null:
		return {}
	var sub: Dictionary = make_peer_subtree(tree, peer, subroot_name)
	sub["peer"] = peer
	return sub


## Creates an ENet client peer + its SceneMultiplayer subtree in one step.
## Returns {} (after printing the failure) on error, else
## {"peer": ENetMultiplayerPeer, "mp": SceneMultiplayer, "root": Node}.
static func start_client(tree: SceneTree, port: int, subroot_name: String = "CliRoot",
		fail_msg: String = "  [FAIL] create_client returned %d") -> Dictionary:
	var peer: ENetMultiplayerPeer = make_client_peer(port, fail_msg)
	if peer == null:
		return {}
	var sub: Dictionary = make_peer_subtree(tree, peer, subroot_name)
	sub["peer"] = peer
	return sub


## Generic poll loop: calls .poll() on every entry of `mps`, then checks
## `until`, returning true the moment it holds. Sleeps `delay_ms` between
## iterations otherwise. Returns false once `iterations` is exhausted.
static func pump(mps: Array, iterations: int, delay_ms: int, until: Callable) -> bool:
	for _i in range(iterations):
		for mp in mps:
			(mp as MultiplayerAPI).poll()
		if bool(until.call()):
			return true
		OS.delay_msec(delay_ms)
	return false


## Common two-peer connect-wait: polls both APIs until the server sees at
## least `min_peers` peers (or `iterations` is exhausted).
static func wait_connected(mp_server: SceneMultiplayer, mp_client: SceneMultiplayer,
		min_peers: int = 1, iterations: int = 400, delay_ms: int = 10) -> bool:
	return pump([mp_server, mp_client], iterations, delay_ms,
		func() -> bool: return mp_server.get_peers().size() >= min_peers)


## Closes every peer in `peers` (in order), then queue_frees every root in
## `roots` (in order) that is still valid. Mirrors the net_*_smoke.gd teardown
## pattern of closing all sockets before freeing subtrees.
static func teardown(peers: Array, roots: Array) -> void:
	for p in peers:
		if p != null:
			(p as MultiplayerPeer).close()
	for r in roots:
		if is_instance_valid(r):
			(r as Node).queue_free()
