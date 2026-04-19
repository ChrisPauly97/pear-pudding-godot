# TID-059: Enemy Intent Display

**Goal:** GID-019
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
