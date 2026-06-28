# TID-352: Make avatar sync map-aware (no cross-map ghosts)

**Goal:** GID-096
**Type:** agent
**Status:** pending
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

_To be written during /work-task. Sketch:_

1. Add a map field to the avatar wire format (`AvatarSync.encode`/`decode`) — keep
   it backward/garbage tolerant like the existing helpers, and update
   `tests/unit/test_coop_sync.gd`.
2. `_broadcast_local_avatar` includes the local `map_name`; `_on_avatar_received`
   drops (or hides the avatar for) any packet whose map != the local `map_name`.
3. Hide / free a remote avatar when its peer's last-known map diverges from the
   local map, and re-show it when they converge again.
4. Decide and document the chosen behavior for the roster when peers are on
   different maps (e.g. still listed but greyed / "elsewhere"), consistent with the
   GID-096 acceptance-criteria style of documenting the rule.

## Changes Made

_TBD._

## Documentation Updates

_TBD — update `docs/agent/multiplayer-coop.md` (avatar sync is map-scoped) and add
a Bug Fix Learnings entry to `CLAUDE.md` (avatar sync was map-blind → cross-map
ghosts)._
