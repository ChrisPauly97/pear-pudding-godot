# TID-275: SceneManager overlay plumbing dedup

**Goal:** GID-074
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

SceneManager.gd (autoloads/SceneManager.gd, 492 lines) repeats identical overlay open/close handler pairs 5× plus a 6-overlay cleanup block.

## Research Notes

- **Open handlers** (state check + instantiate + add_child + connect closed + set state): _on_inventory_requested 386–392, shop 402–408, journal 418–424, character 434–440, skill_tree 450–456. Close handlers (state check + queue_free + reset state): 394–400, 410–416, 426–432, 442–448, 459–465. ~100 lines → generic _open_overlay(packed_scene, state) / _close_overlay() helpers + a small overlay table (~30 lines)
- **_exit_world_cleanup** (201–225): repeated `if _X_overlay != null: queue_free; null` for 6 overlays + saved_world_scene → track open overlays in an Array/Dictionary and loop
- **Keep the State enum gating semantics exactly:** overlays only open from State.WORLD, closing returns to WORLD
- **Coordination:** GID-073 (UI Overlay Framework) standardizes the scene-side closed-signal convention — this task only touches SceneManager's side; the contract (instantiate, add to current_scene, listen for `closed`) must stay compatible. GID-064 TID-229 (lambda signal-connection leaks & overlay ownership) also touches overlay lifecycle — re-verify if it landed

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
