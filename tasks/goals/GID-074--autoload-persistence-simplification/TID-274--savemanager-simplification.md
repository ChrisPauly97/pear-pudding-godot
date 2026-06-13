# TID-274: SaveManager simplification

**Goal:** GID-074
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

SaveManager.gd (autoloads/SaveManager.gd, 903 lines) is the second-largest file in the project; ~240 lines are collapsible boilerplate.

## Research Notes

- **Migration boilerplate:** lines 186–360 — 15 functions all shaped `if not data.has("field"): data["field"] = default; data["version"] = N+1`. Replace with a table/Array of migration Callables or (field, default) descriptors applied in a loop (~160 → ~40 lines). MUST preserve exact semantics: old saves at any version still load to current
- **Equipment-slot duplication:** fields at lines 55–67 (equipped_weapon/owned_weapons, equipped_armor/owned_armor, ring, trinket) plus 4-branch match statements in add_equipment (720–734), equip_item (737–743), get_owned_by_slot (746–752), get_equipped_by_slot (755–761). Consolidate to one `equipment: Dictionary` keyed by slot with generic accessors. NOTE: this changes the save schema → requires a new save version + migration converting the old 8 fields into the structure (eat your own dog food with the new migration table)
- **Dead code to delete:** get_owned_counts (515–521), get_deck_instances (625–631), find_available_uid_for_template (635–640) — zero call sites
- **SUSPICIOUS, do not silently delete:** add_corruption_points (line 800) and add_redemption_points (805) are never called — the skill-tree corruption/redemption currencies may never accrue. Backlog item BID-017 tracks this as a possible functional gap; leave these two functions in place and reference BID-017
- **CRITICAL coordination:** GID-064 TID-226 (unify split-brain SaveManager instances) and TID-227 (Android save robustness) touch this file and take precedence. If they are pending when this task starts, do them first or re-scope; if done, re-verify all line numbers above

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
