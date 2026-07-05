# TID-406: Chapter 2 Named Maps Skeleton — larik, marsax_hold, War-Camp Dungeon Entry

**Goal:** GID-108
**Type:** agent
**Status:** done
**Depends On:** TID-400

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chapter 2 ("The Road to Larik", docs/human/story.md) needs two new small named maps — larik (Saimtar's home village) and marsax_hold (Lord Marsax's besieged hold) — plus a door/entry for the Martarquas war-camp dungeon (a procedural dungeon reskin). This task builds the map skeletons with SPAWN/NPC/DOOR/SCROLL entities so TID-407 can wire beats onto them.

## Research Notes

- **Story specs:** docs/human/story.md Chapter 2 section — beat 2 (Return to Larik: cold frightened villagers, Saimtar's empty house, hidden letter scroll), beat 4 (Marsax hold under siege), beat 6 (war-camp dungeon with boss). Keep maps small (Larik is "a collection of houses with aspirations of township" per the intro).
- **Map creation workflow (CLAUDE.md "Map Storage"):** maps are .tres resources in assets/maps/. Steps: (1) create assets/maps/larik.tres and assets/maps/marsax_hold.tres (+ .uid sidecars, 12-char lowercase uid://); (2) add `const _LARIK := preload("res://assets/maps/larik.tres")` etc. to autoloads/MapRegistry.gd; (3) add entries to the `_BUNDLED` dictionary. Study an existing small map .tres (e.g. farsyth_mansion.tres) for the exact resource format — tile grid string + entity lines.
- **Map format:** docs/agent/named-maps-and-dungeons.md — tile chars 0=grass, 1=wall, 2=hill; entities SPAWN x z / NPC x z text / ENEMY x z [type] / CHEST x z cards / DOOR x z target_map [door_id] / SCROLL directives (see ScrollRegistry usage in existing maps).
- **Connectivity:** Chapter 2 route is west from Blancogov: larik reachable from the open world (same DOOR-from-overworld mechanism as madrian/maykalene — check how existing towns are entered: SceneManager.enter_map / waystone placement in docs/agent/waystone-fast-travel.md), marsax_hold beyond it; war-camp dungeon door placed in the open world or off marsax_hold (decide in Plan; procedural dungeons enter via DOOR with dungeon target — see docs/agent/named-maps-and-dungeons.md DungeonGen section).
- **NPC dialogue:** placeholder static lines from story.md Chapter 2 NPC table (villagers afraid, hold garrison); flag-gated variants belong to TID-407.
- **Scrolls:** larik hidden-letter scroll + marsax traitor's-seal scroll — register in autoloads/ScrollRegistry.gd (preload consts) with narration text from story.md; needs .uid sidecars.
- Headless import validation after MapRegistry edits (CLAUDE.md); tests: extend the map-loading test (tests/ has named-map tests — verify larik/marsax_hold parse and expose SPAWN).

- **Co-op (up to 4 players):** this feature must follow the TID-408 design rules (shared-flag arbitration via SessionState, exactly-once beat effects, authority-broadcast narration, single synced Maiteln, no write-through to solo saves). Read TID-408--coop-story-compatibility.md before Plan.

## Plan

**Format discovery (research notes' "FLAG map entity syntax" is obsolete):** maps are `.tres`
`MapData` resources (GID-017); the old `.txt` `FLAG:`/`SPAWN`/`NPC` line syntax no longer exists.
Studied `farsyth_mansion.tres` in full to confirm the exact resource format: a `[gd_resource]`
header (uid, `load_steps` = ext_resource count + 1 — a soft loader hint, not validated at
runtime), 4 shared `ext_resource` script refs (`MapData`/`MapDoor`/`MapNpc`/`MapScroll`, same UIDs
every map reuses), one `[sub_resource]` block per entity, and a `[resource]` tail with
`tiles`/`heights` as flat 10000-int `PackedInt32Array` literals (row-major, `idx = tz*100+tx`;
farsyth's tiles are ~97.5% grass(0) with scattered wall(1) clusters at height 2 — no map has a
perimeter wall) plus `doors`/`npcs`/`scrolls` as `[SubResource("id"), ...]` arrays.

1. **Generate `assets/maps/larik.tres` / `marsax_hold.tres`** (+ `.uid` sidecars) via a one-off
   Python script (in the scratchpad, not committed) that emits the exact format above — hand-
   authoring two 10000-int literals is impractical. Layout, both maps mostly grass:
   - **larik** — 4 small hollow-rectangle wall outlines ("a collection of houses"); one has a
     south-wall door gap and holds `scroll_larik_letter` inside ("hidden in Saimtar's empty
     house"). Two NPCs (Villager, Old neighbour) with story.md's exact placeholder lines
     (`flag_key` left empty — **flag-gated variants are explicitly TID-407's job** per this
     task's own research notes). Two doors: `""` (pop stack, matches every other named map's
     "back" door convention) and `"marsax_hold"` (west-road continuation).
   - **marsax_hold** — a large hollow-rectangle hold wall with one breach gap on the west side
     (already under attack on arrival, per story.md beat 4) plus two interior structures
     (garrison hall, keep — keep has a door gap; Lord Marsax and the traitor's-seal scroll sit
     inside it). Two NPCs (Garrison sergeant, Lord Marsax). Two doors: `""` (pop stack — returns
     to larik via the map-stack mechanism, no explicit "back to larik" door needed) and the
     war-camp dungeon entry.
   - **War-camp dungeon entry — key engine constraint found:** `WorldScene._ready()` detects any
     `target_map` beginning with `"dungeon_"` and parses everything after those 8 characters as
     an **integer seed** (`int(map_name.substr(8))`) to call `DungeonGen.generate()` — so the
     door's `target_map` must be exactly `"dungeon_<integer>"`, not an arbitrary reskin string.
     Used a fixed literal seed (`"dungeon_731906"`) so every entry regenerates the identical
     procedural dungeon deterministically — reuses the existing GID-102/TID-380 shared-dungeon
     machinery outright rather than building new "reskin" infrastructure the research notes'
     phrasing might otherwise suggest. Placed just outside the hold's west breach (no separate
     open-world door — keeps this task self-contained instead of touching infinite-world chunk
     generation for a special door, which would be much larger/riskier). **Not flag-gated yet**
     (`MapDoor.flag_key` left empty) — noted for TID-407 to lock behind the appropriate Chapter 2
     progress flag (e.g. `chapter2_traitor_seal`) once that task owns the full beat sequencing.
2. **`autoloads/MapRegistry.gd`**: two new const preloads + `_BUNDLED` entries (alphabetical,
   matching the file's existing convention).
3. **`autoloads/ScrollRegistry.gd`**: two new scroll entries (`scroll_larik_letter`,
   `scroll_traitor_seal`, text verbatim from story.md's Chapter 2 Scrolls table);
   `SCROLL_COUNT` 9 → 11. Updated `tests/unit/test_rival_finale.gd`'s matching assertion.
4. **Tests**: `test_all_named_maps_load_npcs()` (existing, generic over `WorldMapScript.list_map_names()`)
   already covers both new maps for free. Added explicit tests in `test_named_map_npcs.gd`:
   not-fallback, `has_player_spawn()` + coordinates, door/npc/scroll counts, the larik→marsax_hold
   door, the scroll ids, and the dungeon door's `dungeon_<int>` format constraint.

**Not done in this task (explicitly TID-407's scope, per the goal's task table):** no story flags
are set or checked anywhere in these two maps yet (no `flag_key` on any entity); no scripted
ambush battle; no siege/boss wiring inside the war-camp dungeon; the dungeon door is physically
reachable without first clearing the hold (acceptable for a skeleton — TID-407 should gate it).

**Co-op note (per TID-408):** no co-op-specific code — these are plain named maps using the same
loading path every other named map already uses; TID-408 covers the shared-spine rules for
Chapter 2 content built on top of this skeleton.

**Validation:** same sandbox constraint as TID-401–405 (no Godot binary, network egress
blocked). Verified the generated `.tres` files structurally (exact tile/height array lengths,
resource block shapes) against `farsyth_mansion.tres`'s format via script — a full headless
import to catch anything a structural diff can't (e.g. actual in-editor parse) is still
recommended before merge.

## Changes Made

- **`assets/maps/larik.tres`** (+ `.uid`): new named map — 2 NPCs, 1 scroll
  (`scroll_larik_letter`), 2 doors (exit + onward to marsax_hold), SPAWN (50,90).
- **`assets/maps/marsax_hold.tres`** (+ `.uid`): new named map — 2 NPCs, 1 scroll
  (`scroll_traitor_seal`), 2 doors (exit + war-camp dungeon entry `dungeon_731906`), SPAWN (50,90).
- **`autoloads/MapRegistry.gd`**: registered both maps (const preload + `_BUNDLED` entry).
- **`autoloads/ScrollRegistry.gd`**: registered both new scrolls; `SCROLL_COUNT` 9 → 11.
- **`tests/unit/test_rival_finale.gd`**: updated `SCROLL_COUNT` assertion to 11.
- **`tests/unit/test_named_map_npcs.gd`**: 10 new tests covering both maps' load success, spawn,
  entity counts, scroll ids, the inter-map door, and the dungeon door's seed-format constraint.

**Validation:** same sandbox constraint as TID-401–405. Structural verification (tile/height
array sizes, resource shapes) done via script against the `farsyth_mansion.tres` reference
format; a full headless import is still recommended before merge — this is the task most worth
double-checking that way, since a hand-generated `.tres` resource file is exactly the kind of
thing that looks right but could have a subtle format mistake invisible without the actual
Godot parser.

## Documentation Updates

None in `docs/agent/` — `docs/agent/named-maps-and-dungeons.md` already documents the `.tres`
map format and `DungeonGen`/dungeon-door-prefix convention generally; these are two ordinary new
maps using existing, already-documented mechanisms, not a new pattern.
