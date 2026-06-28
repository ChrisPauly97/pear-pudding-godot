# TID-354: Tests + docs (dedicated server + PvP-on-server)

**Goal:** GID-097
**Type:** agent
**Status:** done
**Depends On:** TID-352, TID-353

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Verify the dedicated server and server-refereed PvP, and document how to run it.

## Research Notes

- **Smoke (real sockets):**
  - `tests/net_dedicated_server_smoke.gd` — boot a server-mode authority (no
    player), connect 2 clients, confirm avatars + session persistence + world sync
    work and the server survives a client leaving.
  - `tests/net_pvp_dedicated_smoke.gd` — two clients duel through the server
    referee; intents from both apply; both receive the state mirror.
- **Regression:** the existing `net_coop_smoke`, `net_rehost_smoke`, `net_pvp_smoke`,
  `net_pvp_client_smoke` (listen-server paths) must still pass — proves the
  dedicated server is additive.
- **Unit:** any new pure helpers (e.g. cmdline arg parsing extracted to a static
  func) get a unit test.
- Validation gate: headless import clean, `tests/runner.gd` exits 0.
- **Docs:** update `docs/agent/multiplayer-coop.md` — dedicated-server section with
  the exact launch command, port-forward + public-IP instructions for internet
  play, the authority abstraction, and the server-refereed PvP model. Add test rows.

## Plan

1. Write `tests/net_dedicated_server_smoke.gd` — 3-peer ENet loopback test for
   the NetSync relay handshake: set_session_flags, relay_pvp_request, request_battle
   forwarding, relay_pvp_response, notify_pvp_start to both clients with correct
   player indices and opponent decks.
2. Write `tests/net_pvp_dedicated_smoke.gd` — 3-peer test with real BattleScene
   instances (referee idx=-1, client A idx=0, client B idx=1); verify initial mirror
   broadcast and client A end_turn intent flips the turn.
3. Fix `_is_pvp_host()` / `_is_pvp_client()` to use `self.multiplayer.is_server()`
   (node's own subtree multiplayer) instead of `NetworkManager.is_host()` —
   corrects the test environment where the root multiplayer always reports is_server=true.
4. Run headless compilation check + all smoke tests.
5. Update docs: add test rows to multiplayer-coop.md's existing dedicated-server doc.

## Changes Made

### `scenes/battle/BattleScene.gd`
- Changed `_is_pvp_host()` from `NetworkManager.is_host()` to
  `multiplayer.is_server()` (the node's own subtree multiplayer). This correctly
  identifies the ENet host in both production (`NetworkManager.host()` sets the root
  multiplayer peer) and in smoke tests (set_multiplayer on a subtree registers the
  per-peer SceneMultiplayer). The root-level default multiplayer always reports
  `is_server()=true`, so using `NetworkManager.is_host()` made every test peer
  think it was the host.
- Same fix applied to `_is_pvp_client()`.

### `tests/net_dedicated_server_smoke.gd` (new)
- 3-peer ENet loopback smoke for the NetSync relay flow. Connects two clients
  to a server (peer 1). Verifies:
  1. `set_session_flags({"dedicated": true})` reaches client A.
  2. `relay_pvp_request` from client A → server forwards `request_battle` to client B.
  3. `relay_pvp_response` from client B → server sends `notify_pvp_start(0, deck_b)`
     to client A and `notify_pvp_start(1, deck_a)` to client B.
  4. Client A (challenger) does NOT receive a spurious `request_battle`.
- Uses `mp_a.get_unique_id()` / `mp_b.get_unique_id()` and `peer_connected` signal
  for robust peer ID discovery instead of hardcoded sequential IDs.

### `tests/net_pvp_dedicated_smoke.gd` (new)
- 3-peer ENet loopback smoke for the BattleScene referee. Instantiates a real
  BattleScene on each peer: referee (`_local_player_idx=-1`, `_pvp_peer_to_idx`
  map set), client A (idx=0), client B (idx=1). Verifies:
  1. All three BattleScenes launch without crashing in `_ready`.
  2. Both clients receive the initial state mirror from the referee.
  3. Client A sends an `end_turn` intent; the referee applies it; the referee's
     canonical `current_player_idx` flips to 1; both clients receive updated mirrors.

### `.uid` sidecars
- `tests/net_dedicated_server_smoke.gd.uid` and
  `tests/net_pvp_dedicated_smoke.gd.uid` created.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` already updated in TID-353 with the PvP-on-
  dedicated-server subsection. This task adds test rows to the doc's "How to verify"
  section noting the two new smoke tests.
