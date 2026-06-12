# TID-156: Puzzle Mode in GameState + BattleScene (Seeding, Win/Fail/Reset)

**Goal:** GID-040
**Type:** agent
**Status:** done
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

1. Add `puzzle_mode: bool` and `puzzle_data_id: String` to `GameState`.
2. Implement `GameState.load_puzzle(p: Resource) -> GameState`.
3. Update `GameState.to_dict()`/`from_dict()` for the new fields.
4. Modify `BattleScene._ready()` to check `puzzle_data` var and call `load_puzzle`.
5. Add "Check" label and "Give Up" button in puzzle mode.
6. Gate AI turn in `_on_turn_ended()`.
7. Add fail path in `_on_end_turn()`.
8. Add victory path in `_check_game_over()`.
9. Guard save hooks with `not _state.puzzle_mode`.
10. Implement `_show_puzzle_fail()`, `_show_puzzle_victory()`, `_on_puzzle_give_up()`.
11. Wire `SceneManager` handlers for `puzzle_requested`/`puzzle_solved`/`return_from_puzzle`.
12. Write `tests/unit/test_puzzle_mode.gd`.

## Changes Made

- Modified `game_logic/battle/GameState.gd` — added `puzzle_mode`, `puzzle_data_id`, `load_puzzle()` static constructor, updated `to_dict()`/`from_dict()`.
- Modified `scenes/battle/BattleScene.gd`:
  - Added `puzzle_data: Resource`, `_puzzle_data_ref`, `_give_up_btn` vars.
  - `_ready()`: if puzzle_data set → call `GameState.load_puzzle(puzzle_data)`.
  - Renamed "End Turn" to "Check" in puzzle mode; added "Give Up" button.
  - `_on_end_turn()`: fail path if puzzle_mode and not game over.
  - `_on_turn_ended()`: skip AI turn in puzzle_mode.
  - `_check_game_over()`: `_show_puzzle_victory()` path for puzzle_mode win.
  - Save hooks guarded with `not _state.puzzle_mode`.
  - Added `_show_puzzle_fail()`, `_show_puzzle_victory()`, `_on_puzzle_give_up()`.
- Modified `autoloads/SceneManager.gd` — added `_on_puzzle_requested()`, `_on_puzzle_solved()`, `return_from_puzzle()`.
- Created `tests/unit/test_puzzle_mode.gd` + `.uid` — 14 tests covering load_puzzle, board setup, buffs, and dict round-trip.

## Documentation Updates

- `docs/agent/battle-system.md` — Puzzle Battle Mode state flow, `load_puzzle()` description, BattleScene modifications, puzzle-mode save/restore note.
