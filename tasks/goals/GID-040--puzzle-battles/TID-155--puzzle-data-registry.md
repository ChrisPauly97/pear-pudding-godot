# TID-155: PuzzleData Resource + PuzzleRegistry Autoload

**Goal:** GID-040
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The data layer for puzzle battles: a Resource schema describing a frozen board state, and a registry that preloads all puzzle files (Android preload rule). Pure data — no battle logic yet.

## Research Notes

- **PuzzleData resource:** New `game_logic/battle/PuzzleData.gd` (extends Resource, `class_name PuzzleData` — but always preload it per the CLAUDE.md class_name rule). Exported fields:
  - `puzzle_id: String`
  - `title: String`, `hint_text: String` (shown at the shrine)
  - `player_hand: Array[String]` (card IDs)
  - `player_board: Array[String]` (card IDs, positional, max 5 — ZoneState slots)
  - `player_mana: int`, `player_hero_hp: int`
  - `enemy_board: Array[String]`, `enemy_hero_hp: int`
  - `enemy_board_buffs: Array[String]` (optional keyword/status overrides, e.g. give slot 0 Ward — check how Keywords.gd and the GID-019 status effects attach to CardInstance to pick a representation)
  - `reward_card_id: String`
- **Validation:** A `validate() -> Array[String]` method returning problems (unknown card IDs, board > 5, enemy HP ≤ 0) — used by tests and the registry at load.
- **PuzzleRegistry autoload:** New `autoloads/PuzzleRegistry.gd` registered in `project.godot`. Follow `ScrollRegistry.gd` / `SkillRegistry.gd` exactly: `const _P_X := preload(...)` per puzzle file, `_ensure_loaded()` filling an `id → PuzzleData` dict, `get_puzzle(id)`, `all_ids()`. CLAUDE.md has a worked example of this pattern.
- **Directory:** `data/puzzles/` — empty until TID-158 authors content, but create one `puzzle_test.tres` + `.uid` sidecar now so the registry and tests have a fixture (use existing card IDs from `data/cards/`).
- **Tests:** Headless test: registry loads the fixture, `validate()` passes for it and catches a deliberately broken PuzzleData constructed in-test.
- `docs/agent/battle-system.md` — document the schema.

## Plan

1. Create `game_logic/battle/PuzzleData.gd` with @export fields and `validate()`.
2. Create `data/puzzles/` directory and `puzzle_test.tres` + `.uid`.
3. Create `autoloads/PuzzleRegistry.gd` with static preloads and lookup methods.
4. Register in `project.godot` autoloads section.
5. Add `puzzle_requested`/`puzzle_solved` signals to `GameBus.gd`.
6. Add `solved_puzzles` field + migration to `SaveManager.gd`.
7. Write `tests/unit/test_puzzle_registry.gd`.

## Changes Made

- Created `game_logic/battle/PuzzleData.gd` — Resource with all fields + `validate()` method.
- Created `data/puzzles/puzzle_test.tres` + `.uid` (uid://se32kv8oqk8n) — test fixture with ghost/surge_spirit cards.
- Created `autoloads/PuzzleRegistry.gd` — static preloads for all 6 puzzle files, `get_puzzle()`, `all_ids()`.
- Modified `project.godot` — added `PuzzleRegistry="*res://autoloads/PuzzleRegistry.gd"` to [autoload].
- Modified `autoloads/GameBus.gd` — added `puzzle_requested(puzzle_id: String)` and `puzzle_solved(puzzle_id: String)` signals.
- Modified `autoloads/SaveManager.gd` — added `solved_puzzles: Array[String]`, v17→v18 migration, `mark_puzzle_solved()`, `is_puzzle_solved()` methods.
- Created `tests/unit/test_puzzle_registry.gd` + `.uid` — 14 tests for registry lookups and PuzzleData field validation.

## Documentation Updates

- `docs/agent/battle-system.md` — added Puzzle Battle Mode section with schema table, puzzle catalogue, state flow, and SaveManager fields.
