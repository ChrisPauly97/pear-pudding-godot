# TID-058: Spell Targeting UI

**Goal:** GID-019
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Currently all spell cards resolve immediately on drop with auto-targeting. Single-target spells (deal_damage_single, heal_single, shield_minion, buff_attack, lifesteal_hit, curse_minion) should require the player to pick a target. This task adds a target-selection overlay that activates after a targeted spell is dragged to the play zone.

## Research Notes

- `scenes/battle/BattleScene.gd` handles card drag-and-drop; look for `_on_card_dropped` or similar
- `CardData.spell_effect` determines if targeting is needed; add a `targets: String` field to CardData (values: `"none"`, `"friendly_minion"`, `"enemy_minion"`, `"any_minion"`) or derive from spell_effect type
- When a targeted spell is played: pause resolution, highlight valid targets on the board, wait for player tap/click, then resolve with the chosen target
- On mobile: valid targets need a clearly tappable hitbox — use a semi-transparent highlight overlay Panel on each valid slot
- Cancel flow: player should be able to drag the card back to cancel targeting (return card to hand)
- Spells with `targets: "none"` (deal_damage_all, heal_all, mana_drain, draw_card) continue to auto-resolve immediately
- Follow CLAUDE.md UI sizing rules: all overlay controls sized relative to viewport

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
