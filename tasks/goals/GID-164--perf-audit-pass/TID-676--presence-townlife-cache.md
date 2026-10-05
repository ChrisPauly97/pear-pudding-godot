# TID-676: CharacterPresence + TownLife cached records; WalkCycle manager; faces_left error

**Goal:** GID-164
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Top per-frame `_process` costs in profile_world: CharacterPresence 167 µs, WalkCycle 122 µs (×103 nodes), TownLife 116 µs. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `scenes/world/modules/CharacterPresence.gd:46-63, 77-99` — `get_nodes_in_group` ×2/frame (fresh arrays), 3-5 `get_meta` + `is_visible_in_tree` per node, `PARAM_PREFIX + str(i)`.
  Fix: cached member lists (tree `node_added/node_removed` or 4 Hz rebuild), distance cull at 4 Hz, per-node record instead of meta, `const PARAM_NAMES: Array[StringName]`.
- `scenes/world/modules/TownLife.gd:81-131` — per NPC per frame: `str(nid)`, `walker(id)` (get_slice/contains/is_stitched/dict), `_skipped` erase/set, `_siege_town()` SaveManager read, `RealmLayout.world_shift`, `get_node_or_null(WALK_NODE)`, `_sprite_of()`.
  Fix: build `{node, walker, shift, sprite, walk}` record at spawn; iterate only those; siege town at 1 Hz.
- `TownLife.gd:128` adds one WalkCycle node per NPC → one manager ticking all.
- Profiler logged "Nonexistent function 'faces_left'" at `TownLife.gd:130,133` though `game_logic/world/CritterDef.gd:139` defines it — investigate (likely receiver type / `-s` mode); fix so profiler numbers are clean.
- Keep `test_interact_priority` / module guardrails green (no bare add_child in modules).

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

- CharacterPresence: gather both groups every 0.25 s into records (radius / style / phase / base read once), shadow candidates pre-culled to 60 u, idle sprites to MAX_DISTANCE + 4; per frame touch only the records (freed-node safe). StringName param names built once.
- TownLife: per-NPC record cached per spawned node (`is_same` on the raw dict value), siege town and record pruning at 1 Hz.
- WalkCycle: `tick(delta)` extracted; TownLife turns the walker's cycle's processing off and ticks it from `_drive` (far walkers tick with the summed skipped time). Found while testing: townsfolk art has **no walk frames**, so their 100 cycles were empty per-frame callbacks — WalkCycle now disables processing when it has no tracks. (The remaining ~99 processing cycles are enemies', which do animate.)
- `faces_left` error: did not reproduce in the baseline or later profiles (`CritterDef.faces_left` is a static and resolves); nothing to fix.

## Changes Made

- `scenes/world/modules/CharacterPresence.gd`, `scenes/world/modules/TownLife.gd`, `scenes/world/entities/WalkCycle.gd`.
- Tests: `test_walk_cycle::test_trackless_cycle_does_not_process`; `town_life_smoke` asserts walkers' cycles don't self-process.
- Profile (_process µs/frame): CharacterPresence 267 → 18, TownLife 126 → 77, AmbientTouches 211 → 7 (from the TID-674 probe cache).
- Validation: import, gdlint, unsafe-hits, 3022 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests.

## Documentation Updates

- `docs/agent/visual-polish.md` (contact shadows, idle life), `docs/agent/enemies-and-npcs.md` (TownLife walk cycle).
