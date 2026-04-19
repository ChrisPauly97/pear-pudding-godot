# TID-059: Enemy Intent Display

**Goal:** GID-019
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Enemy actions are invisible until they execute, making it impossible to plan around them. This task adds an intent banner that shows what the AI intends to do at the start of the enemy's turn (or at end of player's turn) — standard in Slay the Spire and similar games.

## Research Notes

- `scenes/battle/BattleScene.gd` orchestrates turns; `game_logic/battle/` contains `GameState.gd` and the AI
- `BasicAI` in BattleScene.gd (or a separate file) decides what cards to play and which minions to attack — read its logic to understand what to expose
- Intent should be computed at the start of the enemy planning phase and displayed before any action executes
- Display as a label/panel in the battle HUD: "Enemy will summon [Card Name]" / "Enemy will attack with [Minion] → [Your Minion]"
- If the enemy has multiple planned actions, show the first one (or "Enemy plans X actions")
- Intent banner should animate in (slide/fade) and disappear when the enemy turn resolves
- Consider: intent prediction may become inaccurate if the player's actions change the board state. Accept this — show intent at turn boundary, not live-updated.
- Follow CLAUDE.md UI sizing rules; ensure label is readable at mobile viewport sizes

## Plan

- Added `BasicAI.describe_turn(state)` static method returning first planned action as string
- Added `_intent_panel` var to BattleScene
- Modified `_run_ai_turn()` to call `_show_intent_banner()` then await 1.5s before executing actions
- Modified `_execute_ai_actions()` to call `_hide_intent_banner()` when done
- Added `_show_intent_banner(text)` and `_hide_intent_banner()` helper functions

## Changes Made

- `ai/BasicAI.gd`: added `describe_turn(state: GameState) -> String` static method
- `scenes/battle/BattleScene.gd`: added `_intent_panel`, `_show_intent_banner()`, `_hide_intent_banner()`; modified `_run_ai_turn()` and `_execute_ai_actions()`

## Documentation Updates

- Updated `docs/agent/battle-system.md`
