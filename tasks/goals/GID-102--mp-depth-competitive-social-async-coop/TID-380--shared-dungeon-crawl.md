# TID-380: Shared procedural dungeon crawl (synced seed)

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op runs on **named maps only** — `docs/agent/multiplayer-coop.md` lists *"Infinite chunk
world not supported"* and the procedural **dungeons** (DungeonGen, entered via doors) are
likewise outside co-op. This task lets a party enter a procedural dungeon **together** by
syncing the generation seed so every member generates the identical dungeon, then reuses the
GID-096 shared enemy/chest sync. This is the largest world-layer task and the most valuable
content unlock (it gives BID-024 — "co-op map has no enemies/chests" — a real answer).

## Research Notes

- **Why it's tractable.** DungeonGen is **deterministic from a seed** (see
  `docs/agent/named-maps-and-dungeons.md` — "procedural dungeons generated from a seed when
  entering dungeon doors"). If every peer uses the **same seed**, geometry, enemy placement,
  and chest placement are identical *by construction* — exactly the property GID-096's
  deterministic-spawn + discrete-sync model already relies on for named maps. So the new work
  is mostly **transition + seed propagation**, not a new sync system.
- **Seed propagation.** Co-op multi-map transitions already exist (GID-098 / TID-355):
  `NetSync.recv_map_transition(target_map, door_id)` makes all peers follow through a door.
  Dungeons aren't a named map though — they're generated. Extend the transition message (or
  add `recv_dungeon_transition(seed, door_id, depth)`) so the initiating peer's dungeon
  **seed** is broadcast and all peers call the dungeon entry with that explicit seed instead
  of rolling their own. Find the dungeon entry point in `SceneManager` (grep `dungeon` /
  `DungeonGen`) and add a seed override parameter if one isn't already threadable.
- **Authority owns the seed.** To avoid races (two peers entering different doors at once), the
  **authority** picks/blesses the dungeon seed and fans it out, same arbitration shape as the
  story-flag authority path (GID-098 / TID-356). The session's `world_seed` +
  door id + depth can derive a stable per-dungeon seed deterministically.
- **Reuse GID-096.** Once all peers are in the same generated dungeon, enemy engage-locks
  (first-engager-takes, defeat persists) and chest first-opener-takes already work — they are
  **map-agnostic** (`multiplayer-coop.md` → "Shared World-Object Sync", noted dormant only
  because madrian has none). The dungeon's enemies/chests get ids; confirm the id scheme is
  deterministic across peers (position-derived or generation-index — must match on all peers).
- **Persistence.** Dungeon progress is transient by single-player design (dungeons regenerate);
  for co-op, decide whether a cleared dungeon persists in the session or resets — recommend
  **transient** (matches single-player; don't bloat the session file). The shared seed lives
  only while the party is in the dungeon.
- **Map-scoped avatar sync (TID-352)** already filters cross-map avatars; a dungeon is a
  distinct `map_name`, so avatars converge correctly once all peers are inside. Verify the
  dungeon map name is identical on all peers (derive from the seed/door id, not a local
  counter).
- **Scope guard.** Still **not** the infinite chunk world (that needs chunk streaming sync —
  separate, out of scope). This is finite generated dungeons only.
- **Tests:** a unit test that the seed→dungeon generation is deterministic (same seed ⇒ same
  tile grid + entity ids) — likely already covered by DungeonGen tests; extend if needed. A
  loopback smoke that a `recv_dungeon_transition` lands both peers on the same generated map
  with matching entity ids (mirror `net_world_sync_smoke.gd`).
- **Docs:** update `docs/agent/multiplayer-coop.md` (lift the dungeon exclusion; document the
  shared-seed transition) and cross-reference `named-maps-and-dungeons.md`. Update BID-024.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
