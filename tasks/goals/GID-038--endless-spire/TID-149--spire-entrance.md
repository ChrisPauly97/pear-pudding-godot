# TID-149: Spire Entrance Door + SceneManager Routing

**Goal:** GID-038
**Type:** agent
**Status:** done
**Depends On:** TID-148

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The Spire needs a front door in the world and clean routing: entering starts (or resumes) a run, and the map stack must return the player to the world when the run ends. Resume-on-restart is the key Android requirement.

## Research Notes

- **Entrance placement:** Add a Spire entrance to `assets/maps/madrian.tres` (the starting town) — a distinct Door entity. Check `scenes/world/entities/Door.gd` for the door-type schema (dungeon doors generate from a seed; map doors target named maps). Add a third door kind: `spire`.
- `autoloads/SceneManager.gd` — study the map stack (`docs/agent/named-maps-and-dungeons.md`). Add:
  - `enter_spire()` — if `spire_run.active`, resume at `spire_run.floor`; else `SaveManager.start_spire_run(randi())` and load floor 1. Push the spire floor map onto the map stack.
  - `advance_spire()` — regenerate next floor map and replace the top of the stack.
  - `exit_spire()` — pop back to the entrance map, restoring player position at the door (the stack already restores positions for dungeon exits — reuse that).
- **Resume on app restart:** When the game loads a save with `spire_run.active == true`, the player should spawn inside the current spire floor, not the overworld. Check how GID-034 (battle pause/resume) routes the entry scene on load — `docs/agent/story-implementation.md` mentions the SceneManager entry point; follow the same pattern.
- **Entrance dialogue:** First interaction shows a confirm popup ("Enter the Endless Spire? Your deck stays behind — you'll draft a new one as you climb. [Enter] [Leave]") — tappable buttons, viewport-relative sizing. If a run is active: "[Resume climb — Floor N]".
- **Tutorial hook:** Consider a TutorialRegistry popup (GID-031 pattern, `game_logic/TutorialRegistry.gd`) on first entry explaining the draft loop.
- `docs/agent/named-maps-and-dungeons.md` and `docs/agent/ui-and-scene-management.md` — update routing docs.

## Plan

1. Add `MapDoor_7` to `assets/maps/madrian.tres` at tile (70, 36) with `target_map = "spire"`.
2. Update `scenes/world/entities/Door.gd` — Spire door gets purple tint and "The Endless Spire" label.
3. Add `_show_spire_entrance_panel()` to `WorldScene`; intercept `target_map == "spire"` in `_handle_interact()`.
4. Add `enter_spire()` to `SceneManager` — starts new run or resumes active one.
5. Add `"spire_intro"` entry to `TutorialRegistry.gd`.
6. Update `docs/agent/ui-and-scene-management.md` with Spire routing.

## Changes Made

- **`assets/maps/madrian.tres`** — added `MapDoor_7` (`spire_entrance`) at tile (70, 36) with `target_map = "spire"`.
- **`scenes/world/entities/Door.gd`** — `init_from_data()` now shows "The Endless Spire" with purple color for Spire door; changes door mesh material to purple.
- **`scenes/world/WorldScene.gd`** — intercepts `target_map == "spire"` in `_handle_interact()` to show `_show_spire_entrance_panel()`; panel shows "Enter" (new run) or "Resume Floor N" (active run) with "Leave" button.
- **`autoloads/SceneManager.gd`** — added `enter_spire()`: if run active resumes current floor via `enter_map()`; else calls `start_spire_run(randi())` + `enter_map(spire_floor_1_<seed>)` and emits `spire_intro` tutorial.
- **`game_logic/TutorialRegistry.gd`** — added `"spire_intro"` popup entry.

## Documentation Updates

- **`docs/agent/ui-and-scene-management.md`** — added Spire routing to the state machine diagram and added "Spire routing" section documenting `enter_spire()`, `exit_map()` Spire branch, `_on_battle_won()` Spire branch, and the madrian entrance door.
