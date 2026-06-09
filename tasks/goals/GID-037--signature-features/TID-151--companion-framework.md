# TID-151: Battle Companion Framework (Passive/Hero-Power Slot)

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A companion slot on PlayerState lets the story's characters meaningfully participate in battles. This task builds the data schema and battle integration; TID-152 adds Maiteln as the first companion. The framework must be minimal — one passive effect per companion, visible in the battle UI, no complex interactions.

## Research Notes

- **CompanionData resource:** New `data/companions/CompanionData.gd` (extends Resource). Fields:
  - `companion_id: String`
  - `display_name: String`
  - `portrait_texture: Texture2D`
  - `passive_type: String` (e.g. `"extra_mana"`, `"draw_card"`, `"shield_hero"`)
  - `passive_value: int`
  - `unlock_story_flag: String` (if empty, always available)
- **CompanionRegistry autoload (new):** Preloads all `data/companions/*.tres`. Exposes `get_companion(id) -> CompanionData`.
- **PlayerState integration:** `game_logic/battle/PlayerState.gd` — add `companion_id: String`. In `_apply_companion_passive()` called at battle start (and on specific triggers like turn start), switch on `passive_type` and apply the effect.
  - `extra_mana`: +1 starting mana
  - `draw_card`: draw an extra card at the start of each turn
  - `shield_hero`: hero starts with 2 Armor points (reduce incoming damage until depleted)
- **Save field:** `SaveManager.active_companion: String` (default empty = no companion). Set from CharacterScene or a new "Companions" button in CharacterScene.
- `scenes/ui/CharacterScene.gd` — add companion slot display (portrait + passive description). Tap to open companion picker.
- **Battle UI:** In `scenes/battle/BattleScene.gd`, show a small companion portrait in the HUD corner with a tooltip of the passive effect. No new scene required — a `TextureRect` + `Label` in the existing layout.
- `docs/agent/battle-system.md` — document companion slot.
- `docs/agent/inventory-and-deck.md` — document companion equip flow from CharacterScene.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
