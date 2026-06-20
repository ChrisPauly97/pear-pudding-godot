# TID-274: SaveManager simplification

**Goal:** GID-074
**Type:** agent
**Status:** done
**Depends On:** —

## Context

SaveManager.gd (autoloads/SaveManager.gd, 903 lines) is the second-largest file in the project; ~240 lines are collapsible boilerplate.

## Research Notes

- **Migration boilerplate:** lines 186–360 — 15 functions all shaped `if not data.has("field"): data["field"] = default; data["version"] = N+1`. Replace with a table/Array of migration Callables or (field, default) descriptors applied in a loop (~160 → ~40 lines). MUST preserve exact semantics: old saves at any version still load to current
- **Equipment-slot duplication:** fields at lines 55–67 (equipped_weapon/owned_weapons, equipped_armor/owned_armor, ring, trinket) plus 4-branch match statements in add_equipment (720–734), equip_item (737–743), get_owned_by_slot (746–752), get_equipped_by_slot (755–761). Consolidate to one `equipment: Dictionary` keyed by slot with generic accessors. NOTE: this changes the save schema → requires a new save version + migration converting the old 8 fields into the structure (eat your own dog food with the new migration table)
- **Dead code to delete:** get_owned_counts (515–521), get_deck_instances (625–631), find_available_uid_for_template (635–640) — zero call sites
- **SUSPICIOUS, do not silently delete:** add_corruption_points (line 800) and add_redemption_points (805) are never called — the skill-tree corruption/redemption currencies may never accrue. Backlog item BID-017 tracks this as a possible functional gap; leave these two functions in place and reference BID-017
- **CRITICAL coordination:** GID-064 TID-226 (unify split-brain SaveManager instances) and TID-227 (Android save robustness) touch this file and take precedence. If they are pending when this task starts, do them first or re-scope; if done, re-verify all line numbers above

## Plan

Replace 40 individual migration functions + flat if-chain in `_apply_migrations` with a single table-driven `_apply_migrations`. Delete confirmed dead code. Skip equipment consolidation (too many external callers across production and test code).

## Changes Made

- **Replaced** `_migrate_v0_to_v1` … `_migrate_v39_to_v40` (40 static functions) + old `_apply_migrations` (~430 lines) with a single table-driven `_apply_migrations` (~110 lines). Simple backfill migrations become `[target_version, {field: default}]` dict entries; complex ones (v1, v10, v30, v34, v35) become inline Callables.
- **Deleted** `get_owned_counts()` — confirmed zero call sites.
- **Deleted** `find_available_uid_for_template()` — confirmed zero call sites.
- **Kept** `get_deck_instances()` — active, called at `scenes/battle/BattleScene.gd:183`.
- **Kept** `add_corruption_points()` and `add_redemption_points()` — suspected gap tracked in BID-017.
- **Skipped** equipment-slot consolidation — 25+ direct field mutations in test files and 10+ in production scenes would require a risky wide refactor outside this task's scope.

## Documentation Updates

`docs/agent/save-system.md` already covers the migration pattern at a conceptual level; no structural change needed.
