# TID-341: Raise player cap to 4 + generalize avatar sync to N peers

**Goal:** GID-094
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op is hard-capped at 2 players. To support persistent 4-player sessions
(GID-095) and world sync (GID-096), the transport and WorldScene avatar plumbing
must handle up to 4 peers (1 host + 3 clients, or — later — a dedicated server +
4 clients). This task lifts the cap and removes the single-remote-peer
assumptions, with no change to single-player.

## Research Notes

**Cap constant:** `autoloads/NetworkManager.gd:15` — `const MAX_PEERS: int = 1`
(comment "2-player slice: host + 1 client"). ENet `create_server(port, MAX_PEERS)`
treats `MAX_PEERS` as max *clients*, so host-is-player wants `MAX_PEERS = 3` for
4 total. A future dedicated server (GID-097) hosts without being a player, so it
will want `4`; consider exposing the desired client count as a `host()` parameter
defaulting to 3 rather than baking it, so GID-097 doesn't re-edit the constant.

**Avatar registry is already N-safe:** `scenes/world/WorldScene.gd` keeps
`_remote_player_nodes: Dictionary` (peer_id → RemotePlayer) and
spawns/frees per-peer in `_spawn_remote_player` / `_on_coop_peer_connected` /
`_on_coop_peer_disconnected` / `_on_coop_session_ended` (lines ~490–516). The
15 Hz broadcast (`_broadcast_local_avatar`, ~530) uses `rpc(...)` which already
fans out to all peers, and `_on_avatar_received(sender, payload)` (~519) keys by
`sender`. So the receive/broadcast path needs **no change** for N peers.

**The single-peer assumption to fix — spawn offset:** the doc notes "the non-host
avatar spawns +2 tiles over so the two don't overlap at the shared madrian spawn
marker." Current `_spawn_remote_player` (WorldScene.gd:490) seeds the remote at
the *local* player's position; with 4 players at one SPAWN marker they stack.
Replace the fixed nudge with a deterministic fan-out keyed by `peer_id` (e.g. a
small ring/grid offset `f(peer_id)`), so each avatar lands on a distinct tile
regardless of join order. Keep it terrain-safe (Y recomputed by RemotePlayer).

**Setup already iterates existing peers:** `_setup_coop()` spawns RemotePlayers
for `multiplayer.get_peers()` already (covers the join-ordering race) — confirm it
still works for >1 existing peer (it iterates, so it should).

**Discovery payload `players` count:** `NetworkManager._serve_discovery()`
computes `players = multiplayer.get_peers().size() + 1` — already correct for N.
The lobby reply/label shows the count; verify it reads sensibly at 3–4.

**CLAUDE.md conventions:** guard all co-op code by `NetworkManager.is_active()` /
`_coop_active`; explicit type annotations; `preload` not `class_name`.

## Plan

Complexity is low and the research notes are sufficient — proceeding directly to Build.

1. **NetworkManager.gd — lift the 2-player cap.**
   - Replace `const MAX_PEERS: int = 1` with `const DEFAULT_MAX_CLIENTS: int = 3`
     (host-is-player ⇒ 4 total) and add a `max_clients` parameter to
     `host(port, max_clients = DEFAULT_MAX_CLIENTS)` so GID-097's dedicated server
     (host not a player ⇒ wants 4) does not have to re-edit the constant.
   - Pass `max_clients` to `enet.create_server(port, max_clients)`.

2. **AvatarSync.gd — deterministic spawn fan-out (pure, testable).**
   - Add `static func spawn_offset(peer_id: int, tile_size: float) -> Vector2`:
     a ring offset keyed by `peer_id` so up to 4 avatars don't stack at a shared
     SPAWN marker, stable across join order and frames. 12 ring slots at a
     2-tile radius; slot = `abs(peer_id) % 12`.

3. **WorldScene._spawn_remote_player — apply the fan-out.**
   - Offset the seeded spawn position by `_AvatarSync.spawn_offset(pid, IsoConst.TILE_SIZE)`
     instead of seeding exactly at the local player's position. Y stays terrain-recomputed
     by RemotePlayer.

4. **Tests** — add spawn-fan-out cases to `tests/unit/test_coop_sync.gd`
   (determinism, distinct slots ⇒ distinct offsets, ring radius magnitude).

5. **Validate** — headless editor import clean; `tests/runner.gd` exits 0.

6. **Docs** — update `docs/agent/multiplayer-coop.md` (cap, host() signature, fan-out)
   and the GID-094 Limitations note.

## Changes Made

**Player cap lifted to 4 (`autoloads/NetworkManager.gd`):**
- Replaced `const MAX_PEERS: int = 1` with `const DEFAULT_MAX_CLIENTS: int = 3`
  (3 clients + host = 4 players).
- Added a `max_clients` parameter to `host(port, max_clients = DEFAULT_MAX_CLIENTS)`
  and passed it to `create_server(port, max_clients)`, so GID-097's dedicated
  server (host not a player ⇒ wants 4) won't have to re-edit the constant.

**Deterministic N-peer spawn fan-out (`game_logic/net/AvatarSync.gd`):**
- Added pure, testable `spawn_offset(peer_id, tile_size) -> Vector2` + the
  `SPAWN_RING_SLOTS = 12` constant — a ring slot (`abs(peer_id) % 12`) at a 2-tile
  radius, stable across join order and frames, never the centre.

**Applied the fan-out (`scenes/world/WorldScene.gd`):**
- `_spawn_remote_player` now seeds the avatar at the local player's position **plus**
  `_AvatarSync.spawn_offset(pid, IsoConst.TILE_SIZE)` so up to 4 avatars no longer
  stack on the shared SPAWN tile. Y stays terrain-recomputed by RemotePlayer.
- The receive/broadcast path was already N-safe (`_remote_player_nodes` dict keyed
  by peer_id, `rpc(...)` fan-out, `_setup_coop` iterating `multiplayer.get_peers()`),
  so no change there — confirmed by the smoke tests.

**Tests (`tests/unit/test_coop_sync.gd`):** +5 cases for `spawn_offset`
(determinism, distinct-slot non-collision, 2-tile ring radius, never-at-centre,
large peer-id handling). Full suite: 1562 pass / 0 fail, exit 0. `net_coop_smoke`
and `net_rehost_smoke` still PASS.

**Opportunistic fix — branch HEAD did not compile under Godot 4.6 (BID-023):**
The mandated headless import surfaced three pre-existing parse errors that blocked
*all* compilation (cascading through preload chains into SaveManager / Player /
WorldScene), unrelated to this task:
- `game_logic/TextureGen.gd:177,178,202` — Python-style `//` integer division
  (`i//2`, `sx*sx//3`); GDScript has no `//`, replaced with `/` (same int semantics).
- `autoloads/CardRegistry.gd:165,166` — 2-arg `res.get("card_class", "")` on a
  Resource; `Object.get()` takes one arg. Replaced with 1-arg lookups + null guards
  mirroring the adjacent `id` handling.
Logged and resolved as BID-023; flagged a CI gap (import grep should fail the build).

## Documentation Updates

`docs/agent/multiplayer-coop.md`:
- Status banner now says up to **4 players**.
- `host()` API row documents the `max_clients` parameter and dedicated-server intent.
- AvatarSync section lists `spawn_offset`; the spawn paragraph describes the
  deterministic per-peer ring fan-out (replacing the old "+2 tiles over" note).
- Tests row updated (18 cases); Limitations updated from "2 players max" to "up to 4".
