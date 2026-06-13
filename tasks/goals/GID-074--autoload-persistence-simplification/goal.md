# GID-074: Autoload & Persistence Simplification

## Objective

Collapse the repeated boilerplate in the registry layer, SaveManager, and SceneManager into shared patterns, removing ~300 lines without behavior change.

## Context

The June 2026 simplification audit found three boilerplate clusters in autoloads/:

1. Five registries re-implement the same lazy-load pattern, two of them via DirAccess scans that are an Android export hazard per CLAUDE.md
2. SaveManager.gd (903 lines) has 15 copy-paste migration functions (~160 lines), 4× duplicated equipment-slot accessors, and dead functions
3. SceneManager.gd duplicates overlay open/close plumbing 5×

All three tasks are independent of each other.

**CRITICAL coordination:** GID-064 has pending tasks TID-226/227 (SaveManager unification & Android robustness) and TID-228 (EnemyRegistry/WeaponRegistry preload conversion) that touch the same files — those bug fixes take precedence; whichever runs second re-verifies line numbers, and TID-273 must NOT duplicate TID-228's preload conversion (check its status first; fold it in only if still pending).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-273 | Registry pattern consolidation | agent | pending | — |
| TID-274 | SaveManager simplification | agent | pending | — |
| TID-275 | SceneManager overlay plumbing dedup | agent | pending | — |

## Acceptance Criteria

- [ ] One shared lazy-load mechanism backs all static registries
- [ ] No DirAccess/dynamic ResourceLoader.load() of .tres remains in registries
- [ ] SaveManager migrations are table-driven and equipment slots use one structure with generic accessors
- [ ] SceneManager overlays open/close through one helper
- [ ] Save files written by the old code still load (migration compatibility preserved)
- [ ] All tests pass headless (`godot --headless --path . -s tests/runner.gd`)
