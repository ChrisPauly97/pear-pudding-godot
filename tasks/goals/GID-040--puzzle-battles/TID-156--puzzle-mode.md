# TID-156: Puzzle Mode in GameState + BattleScene (Seeding, Win/Fail/Reset)

**Goal:** GID-040
**Type:** agent
**Status:** pending
**Depends On:** TID-155

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The battle-logic half: seed a GameState from a PuzzleData, detect the lethal (win) or a failed turn-end (reset), and never run an enemy turn. The player gets unlimited retries — puzzles are teachers, not punishments.

## Research Notes

- `game_logic/battle/GameState.gd` — primary file. Add:
  - `puzzle_mode: bool` and `puzzle: PuzzleData`
  - A static/instance `load_puzzle(p: PuzzleData)` constructor: build both PlayerStates, place `player_board`/`enemy_board` CardInstances directly into ZoneStates (bypassing summon costs and **summoning sickness** — board minions must be able to attack immediately), set mana and hero HPs from the puzzle. Check `CardInstance.gd` for the sickness flag and `ZoneState.gd` for slot placement.
  - Apply `enemy_board_buffs` (keyword grants) per the GID-025 Keywords.gd attachment mechanism.
- **Win check:** Enemy hero HP ≤ 0 after any player action → emit `GameBus.puzzle_solved(puzzle_id)`. Hook wherever hero damage is applied (HeroState or GameState damage routine).
- **Fail/reset:** If the player ends their turn (or runs out of possible actions) without lethal → show "Not quite — try again" and rebuild the GameState from the same PuzzleData. No enemy turn ever executes — check how turn handoff to BasicAI happens and gate it on `puzzle_mode`.
- `scenes/battle/BattleScene.gd` — entry: listen for `GameBus.puzzle_requested(puzzle_id)` (new signal), load via PuzzleRegistry, call `load_puzzle`. Exit paths:
  - Solved → award `reward_card_id` once (guard with `SaveManager.solved_puzzles`), show it via the GID-002 card-reward presentation, return to world.
  - Player taps a "Give up" button (mobile-parity: visible button, not a key) → return to world, no penalty.
- **Battle-state persistence interaction:** GID-034 persists mid-battle state. Simplest correct behaviour: puzzle battles are NOT persisted — on app kill, the puzzle just restarts from the shrine. Make sure the GID-034 save hook skips `puzzle_mode` states.
- `autoloads/GameBus.gd` — add `puzzle_requested(puzzle_id)` and `puzzle_solved(puzzle_id)`; update `docs/agent/signals-and-constants.md`.
- `autoloads/SaveManager.gd` — add `solved_puzzles: Array` with migration.
- **Tests:** Headless: load fixture puzzle → simulate the solving actions → assert `puzzle_solved`; simulate wrong line + turn end → assert state reset to initial.
- `docs/agent/battle-system.md` — document puzzle mode flow.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
