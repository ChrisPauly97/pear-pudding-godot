# TID-271: Migrate the four largest overlays

**Goal:** GID-073
**Type:** agent
**Status:** done
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

Extend all 4 scenes from `"res://scenes/ui/BaseOverlay.gd"`. Call `super._ready()`, remove `signal closed`/`_vh`/`_vw` declarations, replace backdrop+panel+margin+vbox blocks with BaseOverlay helpers, route duplicate helpers through UiUtil.

## Changes Made

- **InventoryScene.gd**: extends BaseOverlay; removed `signal closed`, `_vh`, `_vw`; replaced 15-line backdrop+panel+margin+vbox block with 4-line BaseOverlay calls; replaced `_rarity_color`/`_rarity_badge` with `_UiUtil.rarity_color`/`_UiUtil.rarity_badge` (9 call sites); deleted both local methods; trimmed `_input` to only handle `inventory` action (BaseOverlay handles `ui_cancel`).
- **ShopScene.gd**: same base changes; replaced `_weapon_effect_summary` with `_UiUtil.effect_summary` at 2 call sites; deleted local method; removed `_unhandled_input` (BaseOverlay handles `ui_cancel`).
- **CharacterScene.gd**: same base changes; deleted dead `_effect_summary` method; trimmed `_input` to only handle `character` action.
- **SkillTreeScene.gd**: same base changes; replaced backdrop+panel+margin+vbox in both `_build_magic_choice()` and `_build_ui()`; removed `ui_cancel` from `_unhandled_input`.

## Documentation Updates

Updated in docs/agent/ui-and-scene-management.md.
