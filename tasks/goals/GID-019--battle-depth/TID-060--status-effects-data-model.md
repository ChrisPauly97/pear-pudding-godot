# TID-060: Status Effects Data Model

**Goal:** GID-019
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No status effect system exists. This task defines the data model for poison, armor, freeze, and stun — stored on minions (ZoneState) and heroes (HeroState) — and plumbs the application side (spell effects that set statuses). Turn processing (TID-061) and UI indicators (TID-062) build on this model.

## Research Notes

- `game_logic/battle/ZoneState.gd` represents one board slot; add a `status_effects: Dictionary` field (key: effect_id String, value: duration int or stacks int)
- `game_logic/battle/HeroState.gd` represents a player hero; add the same `status_effects: Dictionary`
- Status effects and semantics:
  - `poison`: deals N damage at start of each turn; value = damage per turn; duration counts down each turn
  - `armor`: reduces incoming damage by N; value = armor points remaining; consumed on damage
  - `freeze`: target cannot play cards (if on hero) or cannot attack (if on minion) for N turns
  - `stun`: target skips its attack phase entirely for N turns (stronger than freeze)
- Helper methods to add on ZoneState / HeroState: `apply_status(effect_id, value)`, `has_status(effect_id) -> bool`, `get_status_value(effect_id) -> int`, `clear_status(effect_id)`
- Spell effect handlers added in TID-054 will call these helpers when resolving status-applying spells
- Strict mode: Dictionary values are Variant — use explicit `int` casts when reading
- Do NOT implement turn processing here (TID-061) — only the data model and apply helpers

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
