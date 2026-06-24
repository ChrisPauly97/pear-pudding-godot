# TID-335: Co-op session loads a usable deck

**Goal:** GID-092
**Type:** agent
**Status:** pending
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

_Written during Plan phase._ Likely: in `enter_map_coop` (or a small helper invoked by it),
ensure `save_manager` has a usable deck — if `get_deck_instances()` is empty, seed an
in-memory starter/auto-filled deck (DeckAutoFill or the `new_game` starter) **without**
persisting, so both peers can build decks and pass the `DECK_MIN` gate. Confirm both host
and client paths (`_on_host`, `_on_connection_succeeded` in MultiplayerLobbyScene.gd) are
covered since both call `enter_map_coop`.

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._ Update `docs/agent/multiplayer-coop.md` (deck seeding for
cold co-op sessions) if behaviour changes.
