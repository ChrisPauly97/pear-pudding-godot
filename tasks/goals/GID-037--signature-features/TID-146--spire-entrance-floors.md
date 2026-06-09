# TID-146: Endless Spire Entrance, Floor Progression & Run Summary

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** TID-145

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-145 builds the run data model. This task places the Spire entrance in the world, wires floor-to-floor progression (battle → draft → next floor), and shows the run summary on death.

## Research Notes

- **Entrance:** A new named-map Door entity in `assets/maps/madrian.tres` (or blancogov) that triggers `SceneManager.enter_spire()` instead of a dungeon. Alternatively a standalone `SpireEntrance` entity scene derived from `Door.gd`.
- `scenes/world/entities/Door.gd` — review how dungeon entry works; Spire entry is the same but sets `SaveManager.spire_run.active = true` and transitions to `SpireFloorScene`.
- **Floor scene:** A minimal `SpireFloorScene.tscn` (reuse dungeon visuals from `DungeonGen`) that spawns one enemy per floor (enemy difficulty scales with floor number). After the enemy is defeated, show the draft UI (TID-145). After drafting, increment floor counter, generate the next floor.
- **Enemy scaling:** Use `EnemyRegistry` to pick enemies by difficulty tier: floors 1–3 = common enemies, 4–6 = uncommon, 7+ = boss-tier. Boss framework from GID-021 / TID-070 applies here.
- **Death / exit:** On hero death inside the Spire, set `spire_run.active = false`, clear `draft_deck`, and transition to `RunSummaryScene` with spire stats.
- `scenes/ui/RunSummaryScene.gd` — extend to accept `mode: String` ("normal" | "spire") and show floor count / cards drafted if spire mode.
- `autoloads/SceneManager.gd` — add `enter_spire()` and `exit_spire()` routing methods.
- `docs/agent/named-maps-and-dungeons.md` — dungeon door entry pattern for reference.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
