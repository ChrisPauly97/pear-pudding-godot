# TID-345: Session model + persistence file (SessionState pure logic + authority-side save/load)

**Goal:** GID-095
**Type:** agent
**Status:** done
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

1. **`game_logic/CardInstanceUtil.gd`** — extract the canonical owned-card instance
   dict (uid/template_id/rarity/attack/health/cost/kills/battles_survived/custom_name)
   into one shared builder so `save.json` and the session file never diverge.
   Refactor `SaveManager.add_card_instance` to call it.
2. **`game_logic/net/SessionState.gd`** — pure RefCounted model. Holds session id +
   display name, shared world progress (map, seed, time_of_day, days_elapsed,
   defeated_enemies, opened_chests, story_flags) and `members: {token -> record}`.
   `to_dict`/`from_dict` round-trip, `CURRENT_SESSION_VERSION` + migration scaffold,
   `make_starter_character(token, name)`, `ensure_member`, `get_member`, `has_member`.
   Character record = deck (owned_cards + player_deck uids), coins, essence, xp,
   level, skill_points, unlocked_skills, magic_type, corruption/redemption, position.
3. **`autoloads/SessionStore.gd`** (new autoload) — authority-side dirty-flag batched
   writer to `user://sessions/<session_id>.json`, one file per session. Mirrors
   `SaveManager`'s 2 s timer + close-notification flush, but a wholly separate code
   path that NEVER touches `save_slot_*.json`. `open()/close()/mark_dirty()`,
   member convenience methods.
4. **`MpProfile.get_host_session_id()`** — stable per-host id generated + persisted
   once in `mp_profile.json`, so re-hosting reuses the same session file.
5. Register `SessionStore` autoload; add `.uid` sidecars; headless-import gate.

## Changes Made

- **`game_logic/CardInstanceUtil.gd`** (new) — single canonical owned-card instance
  dict builder (`make(uid, template_id, rarity, attack, health, cost)`). Refactored
  `SaveManager.add_card_instance` to use it so `save.json` and the session files share
  one instance shape and never diverge.
- **`game_logic/net/SessionState.gd`** (new) — pure `RefCounted` model
  (`class_name SessionState` for self-typed `from_dict`/`new`). Holds session id +
  display name, shared world progress (map/seed/time_of_day/days_elapsed/
  defeated_enemies/opened_chests/story_flags) and `members: {token -> record}`.
  `to_dict`/`from_dict` round-trip, `CURRENT_SESSION_VERSION = 1` + `_apply_migrations`
  scaffold, `make_starter_character` (12-card starter mirroring `new_game`, token-salted
  UIDs, 200-coin float), `ensure_member`/`get_member`/`has_member`/`update_member`.
- **`autoloads/SessionStore.gd`** (new autoload) — authority-side dirty-flag batched
  writer to `user://sessions/<session_id>.json`. Mirrors SaveManager's 2 s timer +
  close-notification flush via a wholly separate code path that NEVER touches
  `save_slot_*.json`. `open`/`close`/`mark_dirty`/`flush_now`, plus `ensure_member`/
  `update_member` convenience that delegate to the open state and mark dirty.
  Atomic write via `.tmp` + rename.
- **`autoloads/MpProfile.gd`** — added `get_host_session_id()`: a stable per-host id
  generated + persisted once in `mp_profile.json` (new `host_session_id` field) so
  re-hosting reuses the same session file. Distinct from the per-player token.
- **`project.godot`** — registered `SessionStore` autoload (after `MpProfile`).
- `.uid` sidecars added for all three new scripts.
- Validation: headless editor import clean; `tests/runner.gd` exits 0.

## Documentation Updates

Deferred to TID-348 (the goal's docs task), which adds the persistent-sessions
section to `docs/agent/multiplayer-coop.md` covering all of GID-095.
