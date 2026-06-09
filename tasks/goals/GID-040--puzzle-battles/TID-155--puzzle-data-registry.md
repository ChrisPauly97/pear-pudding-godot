# TID-155: PuzzleData Resource + PuzzleRegistry Autoload

**Goal:** GID-040
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
