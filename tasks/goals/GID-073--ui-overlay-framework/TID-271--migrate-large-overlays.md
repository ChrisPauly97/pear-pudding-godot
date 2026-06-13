# TID-271: Migrate the four largest overlays

**Goal:** GID-073
**Type:** agent
**Status:** pending
**Depends On:** TID-270

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

InventoryScene (705 lines, ~60 override calls), SkillTreeScene (442 lines, ~37), ShopScene (340 lines, ~27), CharacterScene (289 lines, ~26) carry the bulk of the duplication and the worst Android frame spikes (InventoryScene rebuilds its whole collection list). This task converts these four scenes to use BaseOverlay and UiUtil, eliminating hundreds of per-node theme allocation calls and consolidating shared layout patterns.

## Research Notes

**Row-builder duplication to consolidate:**
- ShopScene._make_weapon_row (254–281) and _make_equipment_row (164–188) are identical layouts — merge
- InventoryScene rows (_make_collection_row 329–452, _make_deck_row 454–525, _make_craft_row 531–575) and CharacterScene._make_picker_row (215–254) share swatch+name+badge+button shape — share sub-builders via UiUtil but don't force-merge genuinely different layouts

**Helper consolidation:**
- Replace _effect_summary / _weapon_effect_summary / _rarity_color call sites with the UiUtil versions
- Delete the local copies after migration

**Close/cleanup patterns to standardize:**
- InventoryScene 697–705
- ShopScene 334–340
- SkillTreeScene 439–442
- CharacterScene 283–289

**Behavioral constraints (must not change):**
- Tab system in Inventory (switching between Collection, Deck, Crafting)
- Long-press detectors
- Deck min/max validation
- Skill tree split layout (left nav, right details)
- Weapon/equipment sorting in Shop

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
