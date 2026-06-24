# TID-335: Co-op session loads a usable deck

**Goal:** GID-092
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Launching co-op from the main menu drops the player into madrian with an empty deck, so
the PvP challenge flow refuses to start. Co-op is reachable without ever starting or
loading a single-player game, and the co-op entry path never seeds a deck.

## Research Notes

- `SceneManager.enter_map_coop(map_name)` (autoloads/SceneManager.gd:237) calls
  `_exit_world_cleanup()` then `enter_map(map_name)`. It deliberately does **not** call
  `new_game()` or `load_save()` — the comment notes `save()` is a no-op when no game is
  loaded. As a result `SaveManager` keeps whatever default state it had; if the app was
  just launched and the player went straight to Co-op, `player_deck` / deck instances are
  empty.
- The challenge flow reads the deck via `WorldScene._local_deck_for_net()`
  (scenes/world/WorldScene.gd:549) → `SceneManager.save_manager.get_deck_instances()`.
  Both `_request_challenge` (line 559) and `_accept_challenge` (line 635) hard-block when
  `my_deck.size() < IsoConst.DECK_MIN` with "deck too small to duel."
- The host-side battle builder `BattleScene._build_pvp_decks()` (scenes/battle/BattleScene.gd:1876)
  already has a `fallback` basic deck when instances are empty — but the WorldScene-level
  `DECK_MIN` guard fires first, so the battle is never reached.
- `SaveManager.new_game()` (autoloads/SaveManager.gd:294) seeds the starter deck. Look at
  what it sets for `player_deck` / card instances and reuse that seeding.
- `game_logic/DeckAutoFill.gd` exists and may already produce a valid default/auto-filled
  deck — prefer reusing it over hand-rolling a list.
- Constraint: co-op must remain **additive** and not clobber a real save. If the player
  *does* have a loaded game, use their real deck; only seed a default when the deck is
  empty. Do not write to disk for a cold co-op session (single JSON save at
  `user://save.json` must not be overwritten by a throwaway co-op session — see
  docs/agent/save-system.md).

## Plan

Add `SaveManager.ensure_coop_deck()`: a no-op when a real game is loaded (`_loaded`),
or when the current deck already meets `IsoConst.DECK_MIN`; otherwise it seeds the same
12-card starter `new_game()` uses, in-memory only. Because `_loaded` stays `false` for a
cold co-op session, `save()`/`_flush_if_dirty()` remain no-ops, so the on-disk save is
never touched. Call it from `SceneManager.enter_map_coop()` (covers both host
`_on_host` and client `_on_connection_succeeded`, which both route through it).

Verified `player_deck` defaults to `[]` and `get_deck_instances()` returns `[]` for a cold
session, so the `WorldScene` `DECK_MIN` challenge gate currently fires. Seeding clears the
gate for both peers without a disk write.

## Changes Made

- `autoloads/SaveManager.gd`: added `ensure_coop_deck()`. No-op when `_loaded` (a real game
  is in play) or when the current deck already meets `IsoConst.DECK_MIN`; otherwise seeds the
  same 12-card starter (`ghost/skeleton/zombie/ghoul` ×3) that `new_game()` uses, via
  `add_card_instance()`, in-memory only. `_loaded` stays false so `save()`/`_flush_if_dirty()`
  never write — the on-disk save is never clobbered.
- `autoloads/SceneManager.gd`: `enter_map_coop()` now calls
  `save_manager.ensure_coop_deck()` before `enter_map()`, covering both host
  (`MultiplayerLobbyScene._on_host`) and client (`_on_connection_succeeded`) entry paths.
- `tests/unit/test_save_manager.gd`: 3 new tests — seeds ≥ `DECK_MIN` when empty + not
  loaded; never sets `_loaded`; no-op when a game is loaded.

Verified: full unit suite 1557 passed / 0 failed; headless import clean; all co-op/PvP smoke
tests green.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: documented cold-session deck seeding under "Session
  entry" and added the new test rows.
- `CLAUDE.md`: added a Bug Fix Learnings entry (cold co-op has no save-backed deck).
