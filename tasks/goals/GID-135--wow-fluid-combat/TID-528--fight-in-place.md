# TID-528: Fight In Place — Camera Zoom Into Battle

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-527

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User wants fights to zoom in on the main world, "like Pokémon almost but still in main world", instead of a fade to a separate battle screen.

## Research Notes

- Today `_enter_battle` detaches WorldScene (`_saved_world_scene`) and adds BattleScene as current scene; see CLAUDE.md
  learnings on `_restore_world(after)` deferral and the orphan-free at `_exit_tree`. Changing this touches pause,
  save-resume of battles (GID-034), PvP/co-op (`autoloads/scene_manager/NetBattles.gd`) — keep networked battles on
  the existing path at first; move solo PvE only behind `_enter_battle`.
- Approach sketch: keep WorldScene in tree but paused-for-gameplay (player input + enemy AI off, rendering on);
  tween the iso camera (`_camera.position` only, **never `look_at`**; orthographic `size` for zoom) toward the
  midpoint of player and enemy; render BattleScene as a CanvasLayer overlay with a transparent/partial backdrop
  (`BattleArena`/`BattleBackdrop.gd` currently draws an opaque backdrop).
- State machine: `game_logic/SceneFlow.gd` — may need a new state or reuse BATTLE; `test_scene_flow` enforces edges.
- Night lights / ambient modules keep running; `CharacterPresence` idle bob fine.
- Mobile perf: world render + battle UI together — check Compatibility renderer frame time.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
