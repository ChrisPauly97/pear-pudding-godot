# TID-149: Spire Entrance Door + SceneManager Routing

**Goal:** GID-038
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
