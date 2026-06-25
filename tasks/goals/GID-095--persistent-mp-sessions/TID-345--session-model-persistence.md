# TID-345: Session model + persistence file (SessionState pure logic + authority-side save/load)

**Goal:** GID-095
**Type:** agent
**Status:** pending
**Depends On:** GID-094

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Define the data model and on-disk format for a persistent multiplayer session,
owned by the authority (host). Splits pure serialization from the
authority-side file I/O, mirroring how `SaveManager` + `GameState.to_dict/from_dict`
are structured.

## Research Notes

_To be expanded when GID-094 lands (identity token shape finalized there)._

- Add pure `game_logic/net/SessionState.gd` (RefCounted/static, `to_dict`/`from_dict`,
  unit-testable like `GameState`). Holds: session id + display name, world progress
  (map name, world seed, defeated enemies, opened chests, day/night, story flags if
  shared), and `members: { token -> character_record }`.
- A **character record** = the per-player slice that is session-scoped: deck
  (card instances), owned cards/inventory, coins, level/XP, skills, last position.
  Reuse `SaveManager`'s existing field serializers where possible — factor shared
  card-instance (de)serialization so the session file and `save.json` don't diverge.
- Authority-side store: a `SaveManager`-style dirty-flag batched writer to
  `user://sessions/<session_id>.json` (one file per session so a device can host
  several). **Must never touch `save.json`** — keep it a separate code path; respect
  the `ensure_coop_deck` no-op-when-cold pattern so single-player is untouched.
- Decide session id: stable per host (e.g. generated on first host, stored in the
  recent-servers/host profile) so re-hosting reuses the same file.
- CLAUDE.md: explicit typing, `preload`, JSON via dicts of primitives, version +
  migration scaffold like `SaveManager.CURRENT_SAVE_VERSION`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
