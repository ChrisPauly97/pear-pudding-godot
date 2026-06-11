# TID-273: Registry pattern consolidation

**Goal:** GID-074
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Five static registries duplicate the same `_loaded` guard + `_ensure_loaded()` + Dictionary lookup boilerplate (~280 lines total, ~50% reducible); two use DirAccess scans that break in Android APKs.

## Research Notes

- **CardRegistry.gd** (autoloads/, 121 lines): explicit preload consts lines 3–50, loaded via Array loop 56–80 — the CORRECT pattern per CLAUDE.md
- **EnemyRegistry.gd** (128 lines): DirAccess scan lines 20–31 — Android hazard. NOTE: GID-064 TID-228 already covers converting EnemyRegistry & WeaponRegistry to preload consts. Check its status first: if done, just align with the shared pattern; if pending, this task supersedes/incorporates it (note that in both task files' Changes Made)
- **SkillRegistry.gd** (82 lines): preloads 6–29, loop 38–51
- **WeaponRegistry.gd** (52 lines): DirAccess scan 11–22
- **CraftingRegistry.gd** (45 lines): lazy-builds from CardRegistry 13–22
- **Inconsistency:** ScrollRegistry and MapRegistry are instance autoloads (registered in project.godot) while the five above are static-style classes — document the two categories; don't force-unify the autoloads
- **Consolidation approach:** a shared helper (e.g. game_logic/RegistryUtil.gd or a common base) handling the _loaded guard, id→resource dict build from an Array of preloaded resources, and common getters (get_by_id, get_all_ids). Registries keep their explicit preload const blocks (required for the Android export dependency chain — CLAUDE.md rule)
- **Watch for stale test counts:** tests/unit/test_card_registry.gd asserts 40 but registry has 47 — being fixed in GID-075 TID-278; don't double-fix, just don't break it further

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
