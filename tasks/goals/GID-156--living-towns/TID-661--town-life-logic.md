# TID-661: TownLife Pure Logic — Street Routes & Deterministic Walkers

**Goal:** GID-156
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Foundation for walking townsfolk. A pure static (no scene tree) planner that, per stitched town, decides which
townsfolk walk, which street "stops" they visit, and where each walker is at a given clock time. Determinism is the
point: co-op peers share the synced clock and world seed, so every peer computes identical positions with no RPCs.

## Research Notes

- New file: `game_logic/world/TownLife.gd` (+ `.uid` not needed for .gd). Pattern to copy: `TownStreets.gd` /
  `TownBuildings.gd` — pure static, take a `_WorldMap` + crop, return plain dicts; tests check the plan directly.
- `TownStreets.plan(wm, crop, hub, gates, buildings)` → `{"tiles": {Vector2i local → true}, "lamps": [...]}`
  (town-local tiles). Stops = hub (square), lamp-adjacent street tiles, street tiles next to doors.
- Town lookups in `game_logic/world/RealmLayout.gd`: `town_names()`, `town_map(town)`,
  `to_world_tile(town, local)`, `town_at_tile/world`. Stitched NPC ids are `npc_1, npc_2…` per town (line ~338).
  Check how RealmLayout already calls TownStreets.plan (hub/gates/crop) and reuse those inputs — don't re-derive.
- Walker eligibility: only plain townsfolk — `MapNpc.npc_type` empty (`game_logic/world/resources/MapNpc.gd`).
  Exclude merchant, bounty_board, trainer, quest-givers (anything with a quest in `game_logic/quests/SideQuests.gd`
  or `StoryQuests`), named story NPCs (`SpriteRegistry.named_npc_texture(id) != null`). Cap walkers per town
  (e.g. ~40% of eligible, max 6) — mobile budget.
- Routes: precompute street-only paths between stops once per town with BFS over the `tiles` set (no per-frame
  A*; `game_logic/Pathfinder.gd` exists but works on tile lookups, BFS on the street set is simpler).
- Position: `walker_state(town_plan, walker_idx, t_seconds) -> {pos: Vector2 (local tiles, float), facing,
  moving: bool, stop_idx}`. Loop = walk leg → pause at stop (seeded duration) → next leg. Seed each walker from
  `hash(world_seed, town, npc_id)`. Use `IsoConst.tile_center` when converting (never hand-roll).
- Time source: a monotonically increasing synced value. Check `WorldScene` / `CoopSession` "synced clock" —
  DayNightCycle `get_time_of_day()` wraps 0..1 (day length `_day_duration` 600 s) plus a day counter; expose a
  helper taking total seconds so TID-663 can map it to time-of-day.
- Tests: new `tests/test_town_life.gd` (register in `tests/runner.gd`): same inputs → same positions; walkers
  only ever on street tiles; ineligible NPCs never walk; leg continuity (no teleport between consecutive t).
- GDScript rules: explicit types on Variant RHS, typed arrays, no class_name lookups (preload), lines ≤120, file
  <500 lines.

## Plan

Pure static `TownLife.gd`: candidate filter, seeded walker pick (cap 6 / 70 %), per-walker loop home → 2–3 stops
(hub + street tile beside each lamp) → home over BFS street paths, keyframed with pauses stretched so whole loops fit
one day; `sample(walker, t)` interpolates. Share the hub with TownStreets via a new `RealmLayout.hub_of`.

## Changes Made

- `game_logic/world/TownLife.gd` (new): `is_candidate`, `is_out` + `ROLE_HOURS` (used by TID-663), `plan`, `sample`.
- `game_logic/world/RealmLayout.gd`: `hub_of(town)` extracted from `street_plan` (behaviour unchanged).
- `tests/unit/test_town_life.gd` (new): candidates, determinism + cap, streets-only / no teleport / seamless day wrap,
  indoor folk stay, role hours, real towns have walkers.
- Seed is `hash(town)` (not the world seed): towns are fixed, and every peer derives it without any sync.

## Documentation Updates

`docs/agent/enemies-and-npcs.md` → *Walking Townsfolk & Daily Schedules*; `named-maps-and-dungeons.md` notes `hub_of`.
