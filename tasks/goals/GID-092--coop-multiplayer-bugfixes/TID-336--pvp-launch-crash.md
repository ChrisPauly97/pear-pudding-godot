# TID-336: Fix client crash when a co-op PvP battle launches

**Goal:** GID-092
**Type:** agent
**Status:** pending
**Depends On:** —

## Context

When a co-op PvP battle is launched (challenge accepted), the **other player** (the one
who did not initiate) crashes. The host appears to enter the battle; the client dies.
Likely the same surface that depends on TID-335 in practice (you can't reach a battle
without a deck), but this is a distinct fault in the PvP launch/mirror path.

## Research Notes

- Challenge flow (scenes/world/WorldScene.gd):
  - `_request_challenge` (556) / `_accept_challenge` (633) → both call `_enter_pvp` (658).
  - `_enter_pvp` sets `local_idx = 0 if NetworkManager.is_host() else 1` and calls
    `SceneManager.enter_pvp_battle(local_idx, opponent_deck)`.
- `SceneManager.enter_pvp_battle` (autoloads/SceneManager.gd:389): detaches the WorldScene
  (kept alive), instantiates BattleScene named `"BattleScene"` (fixed RPC path
  `/root/BattleScene/BattleNetSync`), sets `_pvp`, `_local_player_idx`, `pvp_opponent_deck`,
  and a stub `enemy_data`.
- `BattleScene._ready` (scenes/battle/BattleScene.gd:131) → `_setup_pvp_battle` (1843):
  - Host builds decks (`_build_pvp_decks`, 1876), `start_turn(1)`, broadcasts initial state.
  - Client does **not** simulate; it retries `request_sync` in `_process` (1861) until the
    first mirror lands (`_last_applied_seq >= 0`), then `_on_pvp_state` (1924) rebuilds
    `_state` from the mirror.
- Suspect crash surfaces on the client:
  1. Rendering/`_ready` code that assumes a populated `_state` (e.g. board/hero views,
     `_apply_ui_sizes`, perspective accessors `_my_idx`/`_opp_idx` at 1817/1821) running
     before the first mirror arrives, while `_state` is a bare `GameState.new()` with no
     players/hand built.
  2. `enemy_data` stub missing a key that some `_ready` branch reads.
  3. `pvp_opponent_deck` shape mismatch (Array of Dictionaries vs. expected) when the
     client builds nothing but some code still dereferences it.
  4. A `class_name`/preload load-order issue along the BattleScene preload chain (see
     CLAUDE.md "Parse Errors Cascade" — a crash that looks like a render bug).
- Reproduce headlessly with the PvP smoke test: `godot --headless --path . -s
  tests/net_pvp_smoke.gd` (real ENet loopback: client intent → host apply → mirror). Also
  `tests/unit/test_pvp_protocol.gd` for encode/decode. Extend the smoke test to cover the
  client *scene* launch if the crash is in `_ready`, not just the protocol.
- Always run the headless import after edits (CLAUDE.md rule):
  `godot --headless --editor --quit 2>&1 | grep -iE "Parse Error|Compile Error|Failed to load script"`.

## Plan

_Written during Plan phase._ Reproduce the client crash (headless smoke + reading the
client `_ready` path), get the exact error, then guard the client launch so nothing
dereferences an unbuilt `_state` before the first mirror (or build a minimal placeholder
state on the client). Keep all changes under `_pvp` / `_is_pvp_client()` guards so
single-player is untouched.

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._ Add a Bug Fix Learnings entry (CLAUDE.md) for the root
cause; update `docs/agent/multiplayer-coop.md` if the client launch contract changes.
