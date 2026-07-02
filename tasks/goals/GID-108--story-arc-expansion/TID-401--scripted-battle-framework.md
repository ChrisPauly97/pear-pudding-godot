# TID-401: Scripted Battle Framework — Fixed Deck, Deterministic Draw, Tutorial Prompts

**Goal:** GID-108
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Story-driven tutorial battles need full determinism: a fixed player deck (ignoring the player's collection), a scripted draw order so cards are introduced one at a time, a reduced opening hand, a fixed weak enemy, and per-turn guidance popups. First consumer: the rabbit-hunt battle (TID-402); second: the Chapter 2 ambush (TID-407).

## Research Notes

- **Deck/draw internals:** game_logic/battle/PlayerState.gd — `draw_deck: Array[CardInstance]`, `build_deck()` fills then calls `draw_deck.shuffle()` (~line 59), `draw_card()` does `draw_deck.pop_back()` (~line 96–102), `draw_opening_hand(count: int = 4)` (~line 114). A scripted battle needs an ordered deck with NO shuffle — note pop_back means the array must be reverse-ordered relative to the desired draw sequence — and an opening hand count of 1.
- **Precedent for seeded battles:** game_logic/battle/PuzzleData.gd is an @export Resource describing a frozen board state, consumed by `GameState.load_puzzle` (game_logic/battle/GameState.gd ~line 227, preloads PuzzleData via `const PD = preload(...)`). Model `ScriptedBattleData` on it: fields for `battle_id`, `player_deck_order: Array[String]` (draw order, first-drawn first), `opening_hand_count: int`, `enemy_deck: Array[String]`, `enemy_hero_hp: int`, `enemy_plays_scripted: bool` / per-turn enemy plays, `tutorial_steps` (e.g. Array of "turn:trigger:text" strings), `reward_card_id`, `completion_flag`.
- **Tutorial popups:** GID-031 popup tutorial guide system — scenes/ui/TutorialPopup.gd; check how existing popups are triggered (SceneManager/GameBus have tutorial references). Reuse for Maiteln's per-turn lines; key steps to turn number and simple board-state triggers (e.g. first summon, first attack available).
- **Resource sidecars:** any new .tres needs a .uid sidecar (CLAUDE.md "Godot Resource .uid Files"); new .tres must be preload()ed, never ResourceLoader.load() (Android rule). Registry pattern: preload consts iterated in `_ensure_loaded()` (see autoloads/CardRegistry.gd / EnemyRegistry.gd).
- **Battle entry:** SceneManager routes battles; enemy battles carry `enemy_deck`/`enemy_type` dictionaries (see WorldScene `_spawn_rival_at` for the edata shape and SceneManager battle-finish handling ~line 990–1020). A scripted battle should enter through the same overlay flow with a `scripted_battle_id` marker so completion sets the right flag and awards nothing from the normal drop path unless specified.
- **Validation rule:** run `godot --headless --editor --quit` after any .gd edit (CLAUDE.md); GDScript strict typing pitfalls (`:=` Variant inference) documented in CLAUDE.md.
- Add pure-logic tests in tests/ (GUT): deterministic draw order, opening hand count, no shuffle, completion flag set.

- **Co-op (up to 4 players):** this feature must follow the TID-408 design rules (shared-flag arbitration via SessionState, exactly-once beat effects, authority-broadcast narration, single synced Maiteln, no write-through to solo saves). Read TID-408--coop-story-compatibility.md before Plan.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
