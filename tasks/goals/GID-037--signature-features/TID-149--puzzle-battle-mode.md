# TID-149: Puzzle Battle Mode (Preset Board States, Solve-the-Lethal Win Check)

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Puzzle battles are "win this turn" board states that teach keyword interactions and reward rare cards. Unlike a normal battle, the player is handed a fixed board and must find a sequence of plays that kills the enemy hero. This task implements the game-logic layer: seeding GameState from a puzzle definition, and the win-check that detects the lethal solution.

## Research Notes

- **PuzzleData resource:** New `data/puzzles/PuzzleData.gd` (extends Resource). Fields:
  - `puzzle_id: String`
  - `player_hand: Array[String]` (card IDs)
  - `player_board: Array[String]` (card IDs already in play, positional)
  - `player_mana: int`
  - `player_hero_hp: int`
  - `enemy_board: Array[String]`
  - `enemy_hero_hp: int`
  - `reward_card_id: String`
  - `hint_text: String`
- **PuzzleRegistry autoload (new):** Similar to CardRegistry. Preloads all `data/puzzles/*.tres` files. Exposes `get_puzzle(id: String) -> PuzzleData`.
- **GameState seeding:** Add `GameState.load_puzzle(puzzle: PuzzleData)` static method that constructs a fully configured GameState from a PuzzleData without starting a normal battle flow.
- **Win check:** In puzzle mode, after each player action, check if enemy hero HP ≤ 0. If so, emit `GameBus.puzzle_solved(puzzle_id)`. No "enemy turn" runs in puzzle mode.
- **Failure check:** If the player ends their turn without killing the enemy, show "Not quite — try again" and reset the board to initial state (reload from PuzzleData).
- `game_logic/battle/GameState.gd` — primary file to modify.
- `game_logic/battle/PlayerState.gd` — check `build_deck` flow; puzzle mode bypasses this.
- `autoloads/GameBus.gd` — add `puzzle_solved(puzzle_id: String)` signal.
- `autoloads/SaveManager.gd` — add `solved_puzzles: Array[String]` field for tracking which puzzles the player has solved (prevents duplicate rewards).
- `docs/agent/battle-system.md` — document puzzle mode flag.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
