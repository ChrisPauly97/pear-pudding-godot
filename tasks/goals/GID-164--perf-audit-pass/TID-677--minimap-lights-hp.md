# TID-677: Minimap redraw throttle; NightLights flicker in shader; HeroHealth on change

**Goal:** GID-164
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Unconditional per-frame redraws and material writes. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `scenes/world/Minimap.gd:199-200` unconditional `_dot_layer.queue_redraw()`; `_draw_quests` 264-285 calls `QuestLog.world_pos()` per quest per redraw; `_draw_group`/`_draw_enemy_nodes` 288-316 `str(id)` + `get_meta("is_nocturnal")` per entity.
  Fix: redraw ~15 Hz or on player-move epsilon / entity change; cache quest positions in `QuestTracker.refresh()` (250 ms); cache nocturnal flag.
- `scenes/world/modules/NightLights.gd:97-107, 245-256` — per rig per frame: 2× `set_shader_parameter("energy", …)` (String→StringName), new `albedo_color`, 4 dict lookups.
  Fix: `const ENERGY := &"energy"`; skip flicker==0 rigs when `_night` stable; move flicker to shader (TIME + `instance uniform` phase) so CPU writes only when `_night` changes.
- `scenes/world/modules/HeroHealth.gd:30-46, 90-92` — `set_hero_hp()` and `set_action_visible("eat", _can_use())` (runs `HeroVitality.best_world_item` over inventory) every frame even at full HP.
  Fix: write bar only when value changes; recompute `_can_use` on inventory/HP signals or 2 Hz.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
