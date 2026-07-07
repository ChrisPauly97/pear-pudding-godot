# TID-415: AI Persona Framework + Shared Lethal Check in BasicAI

**Goal:** GID-112
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`ai/BasicAI.gd` has exactly one strategy today. This task adds the plumbing for
per-enemy personas and a shared "check for lethal first" step, without changing
observable behavior for the default persona yet (that preserves puzzle mode and
existing tests as a safety net — TID-416 adds the actually-different personas on
top of this scaffold).

## Research Notes

- Full current logic, `ai/BasicAI.gd`:
  - `decide_turn(state: GameState) -> Array[Callable]` (lines 12-61): builds one
    deferred Callable per playable hand card (cheapest-cost order comes from hand
    order, not an explicit sort despite the doc-comment claiming "sort by cost
    ascending" — verify against `describe_turn`'s early-return-on-first-playable
    logic, lines 68-71, which iterates `ai.hand` in raw order too) — Read the file
    directly, don't trust doc paraphrase, before changing anything, then one
    Callable per board slot that attacks the first Ward-filtered target or, if
    none, the hero directly (lines 28-59). The doc-comment at the top (lines 9-11)
    explains *why* decisions are deferred to execution time: earlier plays/attacks
    in the same turn can kill the very card a later Callable would have targeted,
    so re-checking `can_play`/`can_attack` and re-resolving targets at execution
    time (not planning time) avoids double-discard corruption. **Any new persona
    logic must preserve this deferred-Callable shape** — do not switch to eager
    evaluation.
  - `describe_turn(state: GameState) -> String` (lines 64-91): mirrors the first
    action `decide_turn` would take, for the Enemy Intent banner. Must stay in
    sync with whatever `decide_turn` would actually do first.
- Only one call site for both: `BattleScene._run_ai_turn()`,
  `scenes/battle/BattleScene.gd:1869-1875`:
  ```gdscript
  var actions := BasicAI.decide_turn(_state)
  _fx.show_intent_banner(BasicAI.describe_turn(_state))
  ```
  `BattleScene` already holds `enemy_data: Dictionary` (set in `_ready()` per
  `docs/agent/battle-system.md` "Data Model" section) — this is where
  `enemy_data.get("ai_persona", "basic")` and `enemy_data.get("difficulty_tier", 1)`
  (also already present in every `EnemyRegistry` entry, see
  `autoloads/EnemyRegistry.gd`) should be read and threaded into the two calls.
- `GameState` (`game_logic/battle/GameState.gd`) API available for lethal
  computation: `current_player()` (line 75), `opponent()` (line 85),
  `battlefield_biome` (line 34, -1 for dungeons/named maps, 0-4 for biome —
  affects damage via `BattlefieldRules.modify_damage(atk, biome)`).
- `CardInstance` fields needed for lethal math (`game_logic/battle/CardInstance.gd`
  lines 9-33): `attack`, `health`, `keywords: Array[String]`,
  `can_attack() -> bool` (line 66), `is_alive() -> bool` (line 63). `HeroState`
  (co-located battle/ dir) exposes `health`/`attack`/status like `armor`.
- PvP (`_pvp` guarded in `BattleScene`) disables `_run_ai_turn` entirely — it
  early-returns in `_on_turn_ended` before calling it. Puzzle mode
  (`_state.puzzle_mode`) also skips the AI turn. Neither path needs touching or
  testing here, but confirm during Plan that the persona/tier params default
  safely (`"basic"`, `1`) if somehow reached with an empty `enemy_data`.
- Existing test file to keep green: `tests/unit/test_basic_ai.gd` (265 lines) —
  run it (or trace by hand if Godot is unavailable in-sandbox, per this repo's
  established convention — see recent task Changes Made sections for the
  documented pattern of manual verification + explicit "not run headless" note)
  to confirm the `basic`/default persona produces byte-identical decisions to
  today's `decide_turn`/`describe_turn` before moving to TID-416.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
