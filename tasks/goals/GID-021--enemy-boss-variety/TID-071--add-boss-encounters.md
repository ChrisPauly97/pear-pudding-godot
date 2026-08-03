# TID-071: Add 2 Boss Encounters to Named Maps

**Goal:** GID-021
**Type:** agent
**Status:** done
**Depends On:** TID-068, TID-070

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Using the boss framework (TID-070) and the human-authored boss data (TID-068), this task creates the boss EnemyData .tres files and places them in the correct named maps.

## Research Notes

- Boss placements from story.md (TID-068 output): one mid-story boss and one Chapter 1 end boss
- Create .tres files for each boss in `data/enemies/` with `is_boss = true`; give them higher HP (e.g. 40–50), strong decks, and guaranteed drop pools
- Place bosses in named maps as ENEMY directives in the appropriate .tres MapData:
  - Mid-story boss: likely `farsyth_mansion.tres` or `blancogov.tres` — check story.md for intended placement
  - Chapter 1 end boss: `blancogov_temple.tres`
- Boss enemies in named maps should be flagged so they only spawn once (use `SaveManager.defeated_enemies` — same pattern as regular enemies)
- The boss enemy NPC in the world scene should use `is_boss=true` EnemyData to trigger the boss battle framework in BattleScene
- Add `.uid` sidecars for boss .tres files

## Plan

**Architecture correction (same as TID-069):** no `.tres`/`.uid` boss files —
`hollow_steward` and `martarquas_vanguard` become `EnemyRegistry._enemies`
entries (`is_boss = true`, `boss_hp` 35/40, each with a `phase2_deck`),
placed from `docs/human/story.md`'s "Boss Enemy Types" table (TID-068).

**Placement mechanism:** named-map `ENEMY` placement is a `MapEnemy`
resource (`entity_id`, `tile_x`, `tile_z`, `enemy_type`) referenced from
`MapData.enemies`, loaded by `WorldMap.load_from_resource()` — confirmed by
reading that function directly (`tracking` is derived at load time via
`EnemyRegistry.is_tracking(enemy_type)`, `enemy_deck` via `get_deck()`).
`hollow_steward` → `farsyth_mansion.tres` at tile (66, 55) (clear of the
existing door/NPCs/scroll/shrine tiles, off the main guard-to-Farsyth path —
a side chamber). `martarquas_vanguard` → `blancogov_temple.tres` at tile
(55, 60) (mid-corridor between the entrance door and the throne room,
clear of existing entities) — an interceptable scout on the way to the
council. Both get `is_tracking() == true` (added to `EnemyRegistry.
is_tracking()`'s whitelist) so they're proactive, unavoidable encounters
like `roaming_terror`, not passive wanderers — fits "boss fight," and this
is exactly the once-only persistence path every named-map enemy already
gets for free via `WorldScene`'s `SaveManager.defeated_enemies` spawn-skip
check (no bespoke flag needed, per the task's own research note).

**Bundled in (same function touched, same tier logic already decided in
TID-069's Plan but never implemented there):** also added `scorched_revenant`,
`mountain_troll`, and `stone_golem` to `is_tracking()` — TID-069's Plan
described a tier-3+-is-tracking rule but the actual `is_tracking()` edit was
never made, leaving those three as passive wanderers by omission. Fixed here
since it's the same one-line whitelist function.

**Bug found and fixed while restructuring these 2 files:** loading
`farsyth_mansion.tres`/`blancogov_temple.tres` directly and inspecting the
result showed `scrolls.size() == 0`, `shrines.size() == 0`, and
`music_track == ""` despite both files clearly authoring 1-2 scrolls and a
puzzle shrine each. Root cause: `MapData.gd`'s `scrolls`/`shrines`/
`triggers`/`regions`/`music_track`/`difficulty`/`author`/`version` fields
were written as dangling `key = value` lines positioned *after the last
`[sub_resource]` block but before `[resource]`* — Godot's `.tres` parser
attaches trailing assignments to the most recently opened section, so they
silently landed on the last sub-resource (which doesn't declare those
properties) and were dropped on load with no error. Since I was already
restructuring both files to add the boss `MapEnemy` sub-resource, moved
those 8 lines into the `[resource]` section where they belong — verified
scrolls/shrines/music now load correctly (see Changes Made). The same bug
exists in `madrian.tres`, `maykalene.tres`, and `blancogov.tres`, which
this task doesn't otherwise touch — filed as **BID-059** rather than
expanding scope to all 5.

## Changes Made

- `autoloads/EnemyRegistry.gd`:
  - Added `hollow_steward` (boss_hp 35) and `martarquas_vanguard` (boss_hp
    40) entries to `_enemies`, both `is_boss = true` with a `phase2_deck`.
  - `is_tracking()`: added `hollow_steward`, `martarquas_vanguard`, plus
    `scorched_revenant`/`mountain_troll`/`stone_golem` (TID-069's tier-3+
    enemies, whose tracking flag was planned but never actually wired).
- `assets/maps/farsyth_mansion.tres`: added `MapEnemy` ext_resource +
  sub-resource (`hollow_steward_1` at tile 66,55), referenced from
  `enemies = [...]`; `load_steps` 6 → 7.
- `assets/maps/blancogov_temple.tres`: same for `martarquas_vanguard_1` at
  tile 55,60; `load_steps` 6 → 7.
- **Bug fix (both files):** moved the dangling `scrolls`/`shrines`/
  `triggers`/`regions`/`music_track`/`difficulty`/`author`/`version`
  properties (previously silently attached to the last `[sub_resource]`
  block instead of `[resource]` — Godot drops unknown properties with no
  error) into the correct `[resource]` section. Verified via a throwaway
  `load()` + inspect script:
  - `farsyth_mansion`: scrolls 0→2, shrines 0→1, music_track ""→populated.
  - `blancogov_temple`: scrolls 0→1, shrines 0→1, music_track ""→populated.
  - Filed **BID-059** for the same bug in `madrian.tres`/`maykalene.tres`/
    `blancogov.tres`, not otherwise touched by this task.
- Verified: headless editor import clean; `tests/runner.gd` — 2355 passed
  (unchanged), 0 failed, 1 pending (pre-existing).

## Documentation Updates

- `docs/agent/enemies-and-npcs.md`: new "Chapter 1 Story Bosses" subsection
  (placement table, mechanic summary) between "Roaming Boss" and "EnemyNPC
  Scene".
- `docs/agent/named-maps-and-dungeons.md`: added `shrines`/`waystones` to
  the `MapData` fields example (were missing — a separate minor drift, same
  block being touched anyway); added a "hand-editing/generating `.tres` map
  files" pitfall callout documenting the dangling-property bug (BID-059) so
  it can't silently reappear, including how to actually verify (load +
  inspect, since headless import doesn't catch this class of bug).
