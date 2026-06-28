# TID-352: Make avatar sync map-aware (no cross-map ghosts)

**Goal:** GID-096
**Type:** agent
**Status:** done
**Depends On:** GID-094

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op is *intended* to live on a single shared named map (madrian) — that is the
only sanctioned entry point and the deterministic-geometry assumption the design
relies on. But that limitation is enforced **only at the entry point**, never in
the avatar sync layer, so the sync is effectively map-blind. The observed symptom:
when one player walks into `main` (or any other map) while the other stays behind,
both players still "see" each other — the remote avatar keeps rendering on the
local player's map at coordinates that actually belong to a different map. That is
a correctness bug, not multi-map co-op working.

This task makes the avatar layer honor the single-map contract: a peer's avatar is
only rendered for players who are on the **same map**, and avatars are hidden /
not updated when peers diverge onto different maps. (Genuine multi-map co-op —
syncing map transitions and supporting differing geometry — is a larger feature
and explicitly out of scope here.)

## Research Notes

- **Entry is pinned to madrian, but only there.** `MultiplayerLobbyScene.gd`
  `const _COOP_MAP := "madrian"` (line 10) routes both host (`:234`) and client
  (`:361`) through `SceneManager.enter_map_coop("madrian")`. The map name is not
  threaded into the sync layer at all.
- **The RPC path is map-independent.** `NetSync` is a fixed-name `Node` child named
  `"NetSync"` and every map loads as a `WorldScene` root, so the RPC path
  `/root/WorldScene/NetSync` resolves identically on **any** map
  (`WorldScene.gd:460-466`). Packets keep being delivered after a door transition.
- **`_setup_coop` re-runs on every map load**, gated only by
  `NetworkManager.is_active()` — never by map name (`WorldScene.gd:438`, `:454`).
  Walking into `main` re-wires co-op on the new WorldScene.
- **The avatar broadcast/receive has no map filter.**
  `_broadcast_local_avatar` (`WorldScene.gd:758`) and `_on_avatar_received` (`:747`)
  are guarded only by `_coop_active` / `_net_sync` / `_player`.
- **The payload carries no map field.** `AvatarSync.encode(x, z, flip_h, moving)`
  (`game_logic/net/AvatarSync.gd`) has no map id, so a receiver literally cannot
  tell which map the sender is on. This is the root cause — even a receive-side
  filter needs the sender's map in the payload.
- Single-player must stay byte-for-byte unchanged (everything guarded by
  `_coop_active`). Keep the change additive, in the same spirit as the rest of
  `docs/agent/multiplayer-coop.md`.

## Plan

**Chosen behavior:** a remote avatar renders **only** for peers on the same `map_name`.
A peer on a different map is **hidden** in the 3D world (not freed — its node persists so
re-convergence is instant) and shown in the roster as greyed **"(elsewhere)"**. Genuine
multi-map co-op (syncing transitions / differing geometry) stays out of scope.

1. **Wire format** — `AvatarSync.encode(x, z, flip_h, moving, map_name := "")` appends the
   sender's map; `decode` returns `map` (defaulting to `""` for short/garbage/old payloads,
   matching the helper's tolerance style). Add round-trip + default cases to
   `tests/unit/test_coop_sync.gd`.
2. **Broadcast** — `_broadcast_local_avatar` passes the local `map_name`.
3. **Receive filter** — `_on_avatar_received` records the sender's last-known map
   (`_remote_player_maps[sender]`); the avatar is shown + `set_net_state` fed **only** when
   `sender_map == map_name` (empty map = legacy/garbage → treat as same map, no regression).
   On a different map the node is hidden and not updated (keeps its last same-map position,
   so re-convergence resumes cleanly). Roster refreshed only when a peer's map actually changes.
4. **No spawn flash** — newly spawned `RemotePlayer`s start `visible = false`; the first
   same-map packet (≤66 ms at 15 Hz, broadcast unconditionally) reveals them. This kills the
   cross-map ghost on a fresh map load too.
5. **Roster** — peers on another map render greyed with an " (elsewhere)" suffix.
6. **State hygiene** — `_remote_player_maps` cleared on disconnect / session end.
7. Docs: `multiplayer-coop.md` (avatar sync is map-scoped) + a CLAUDE.md Bug Fix Learnings entry.

Single-player untouched — all paths guarded by `_coop_active`.

## Changes Made

- **`game_logic/net/AvatarSync.gd`**: `encode` gains an optional `map := ""` 5th element;
  `decode` returns `map` (defaulted to `""` for short/legacy 4-element payloads).
- **`scenes/world/WorldScene.gd`** (all guarded by `_coop_active`):
  - `_broadcast_local_avatar` now sends the local `map_name`.
  - `_on_avatar_received` records `_remote_player_maps[sender]` and shows + feeds
    `set_net_state` **only** when the sender's map equals the local `map_name`; otherwise the
    avatar is hidden (node kept, holding its last same-map position). Roster refreshed only
    when a peer's map changes.
  - `_spawn_remote_player` spawns avatars `visible = false` (revealed by the first same-map
    packet) — no cross-map ghost flash on map load.
  - Roster (`_refresh_coop_roster`) greys off-map peers with an " (elsewhere)" suffix.
  - `_remote_player_maps` declared + cleared on peer disconnect / session end.
- **`tests/unit/test_coop_sync.gd`**: +3 cases — map round-trip, default-empty, legacy
  4-element payload tolerance (now 21 cases); renamed the element-count test to 5.
- Chosen rule documented: avatar renders only for same-map peers; off-map peers are
  hidden + listed as "(elsewhere)"; empty map = same-map (no regression).
- Validation: headless import clean; `tests/runner.gd` 1606 pass; `net_coop_smoke`,
  `net_coop_npeer_smoke`, `net_world_sync_smoke`, `net_session_smoke` all PASS.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: new *Map-scoped avatar sync (TID-352)* subsection, updated
  AvatarSync wire-format block + Tests row.
- `CLAUDE.md`: Bug Fix Learnings entry — "Co-op avatar sync was map-blind — cross-map ghosts"
  (invariant: enforce shared-map/world/seed contracts in the sync layer, not just at entry).
