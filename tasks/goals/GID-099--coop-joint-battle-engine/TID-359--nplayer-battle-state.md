# TID-359: N-player co-op battle state model

**Goal:** GID-099
**Type:** agent
**Status:** pending
**Depends On:** TID-355

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The engine foundation: a battle state that holds a **party of N allies vs one shared
boss**, with a coherent turn structure and win/loss conditions. Everything else in
GID-099/GID-100 builds on this.

## Research Notes

- **Current state (2-player only):** `game_logic/battle/GameState.gd`
  - `var players: Array[PlayerState] = []` seeded with **2** in `new()`-equivalent
    setup; `current_player_idx`; `player_turn_numbers: Array[int] = [1, 0]`.
  - `enemy()` returns `players[1 - current_player_idx]` — **hard 2-player assumption**;
    grep every `1 - ` / `players[1]` / `players[0]` usage in `game_logic/battle/` and
    `scenes/battle/` before changing.
  - `is_game_over()` loops `players` checking `hero.is_alive()`.
  - `from_dict`/`to_dict` round-trip the whole state (used by the PvP mirror).
  - `PlayerState.gd` = one side: `hero` (hp/mana), `board` (5 slots), `hand`,
    `draw_deck`. Reusable as-is per ally and for the boss.
- **Design decision — extend vs new type:**
  - *Recommended:* keep `GameState` for 2-player (PvP/NPC/puzzle/Spire untouched) and
    add a co-op mode flag + a clear **ally-set vs enemy-set** distinction, rather than
    overloading `players[0]`/`players[1]`. Concretely: index 0..N-1 = allies, last
    index = boss; replace `enemy()`/`opponent` accessors with role-aware helpers
    (`allies()`, `boss()`, `is_ally(idx)`) that reduce to the existing behavior when
    N == 2 and not co-op. Guard with `coop_battle: bool`.
- **Turn structure (decide + unit-test):** typical model — each ally takes their turn
  (own mana ramp via `player_turn_numbers`, extend the array to N+1), then the **boss
  takes one turn, attacking/targeting across all ally boards/heroes**. Boss AI reuses
  `BasicAI` but must pick targets across multiple enemy boards. Define target-selection
  rules.
- **Win/loss:** party wins when boss hero dead; party loses when **all** ally heroes
  dead (a downed ally could be "out" but battle continues — decide; simplest: lose when
  all allies down, an ally whose hero dies is spectating).
- **RNG/authority:** no shared deterministic RNG (same as PvP) — the authority owns the
  one state and mirrors it. Keep `GameState` pure/scene-free; `gamebus_emitter`
  Callable pattern stays.
- **Tests:** add `tests/unit/test_coop_battle_state.gd` mirroring
  `test_pvp_protocol`/`test_session_state`: N-player setup, turn rotation incl. boss
  turn, win/loss, `to_dict`/`from_dict` round-trip with N participants.
- This task may split (state model vs boss-AI targeting) — flag during Plan if it grows.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
