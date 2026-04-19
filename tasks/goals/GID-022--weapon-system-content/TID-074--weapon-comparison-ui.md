# TID-074: Weapon Comparison UI in InventoryScene

**Goal:** GID-022
**Type:** agent
**Status:** pending
**Depends On:** TID-073

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

InventoryScene shows cards and deck, but has no weapon management UI. Players need to see their equipped weapon and compare it against other weapons they own before equipping.

## Research Notes

- `scenes/ui/InventoryScene.gd` — add a third panel or tab for weapons alongside the collection and deck panels
- `autoloads/SaveManager.gd` — `SaveManager.equipped_weapon: String` stores the ID of the equipped weapon; `SaveManager.owned_weapons: Array[String]` should store weapon IDs the player has found (add this field if it doesn't exist; check SaveManager for existing weapon tracking)
- Weapon panel layout:
  - Left: list of owned weapons (VBoxContainer of weapon buttons)
  - Right: comparison pane — two columns: "Equipped" vs "Selected" showing display_name, description, effect_type, effect_value side by side
  - Equip button becomes active when a non-equipped weapon is selected
- Follow CLAUDE.md UI sizing (viewport-relative) and mobile parity rules (tap = click)
- `WeaponRegistry.get_weapon(id)` loads weapon data — use it to populate the panel
- On equip: update `SaveManager.equipped_weapon` and call `SaveManager.mark_dirty()`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
