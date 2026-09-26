# TID-528: Fight In Place — Camera Zoom Into Battle

**Goal:** GID-135
**Type:** agent
**Status:** done
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

Real-time solo battles only (the setting the user plays with); networked battles keep detach + wipe.
Freeze the world in place, hide its CanvasLayers, push the camera in, fade the battle overlay in over it;
route every exit through one `reattach_world()` helper.

## Changes Made

- `SceneManager`: `_in_world_battle_eligible`, `_enter_battle_in_world`, `_freeze_world` / `_thaw_world`,
  `reattach_world()`; `_restore_world` skips the wipe for an in-place world; `_exit_tree` orphan check is now
  "no parent" (freeing a still-parented world during teardown segfaulted).
- `BattleDefeat` (2 sites) and `NetBattles` (1) use `reattach_world()`.
- Follow-up (user: "the enemy disappeared when the battle started"): `SceneManager.fights_in_world()` /
  `free_after_battle(node)`; EnemyNPC and BlightHeart keep standing during an in-world fight and are freed when
  the scene returns to WORLD. Smoke asserts both.
- Follow-up 2 (user: "where is the enemy?"): with gambits auto-skipped the battle starts inside the engage
  emit, so `fights_in_world()` saw the battle overlay as current and freed the enemy at once. It now also
  returns true while a world is held in place; the smoke uses the real call order (fails without the fix).
- Follow-up 3 (user: "fight with two monsters, beat both but can't go back to main world"): a second engage
  during the gambit picker stacked a second battle that parked the first overlay as the world. Fixed with
  `SceneManager.accepts_engage()` + `_engage_pending`, enemy stand-down after the alert beat, and a no-stacking
  guard in `_enter_battle`. In-world smoke reproduces it (2 pickers) without the guard.
- `BattleScene.in_world`: skips the arena backdrop and dims the Background so the world shows through.
- `tests/in_world_battle_smoke.gd` (in CI): world stays in tree + frozen, HUD hidden, camera pushed in; after
  the battle it is current, thawed, HUD back, camera restored, state WORLD. Verified in an xvfb capture.

## Documentation Updates

`docs/agent/combat-model.md` → Fighting in place; CLAUDE.md SceneManager note on `reattach_world()`.
