# TID-677: Minimap redraw throttle; NightLights flicker in shader; HeroHealth on change

**Goal:** GID-164
**Type:** agent
**Status:** done
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

- Minimap: dot layer redraws every 2nd frame (~30 Hz); terrain view already 15 Hz.
- QuestTracker.quest_pos memoised per quest id + map, cleared on each 250 ms re-read (targets are static tiles; nearest-target choice refreshes with the read).
- NightLights: StringName `ENERGY_PARAM`; `_apply_flicker` skips rigs whose flicker value and night factor are unchanged (`configure` forces). Moving flicker into the shader skipped: the OmniLight energy needs the CPU anyway.
- HeroHealth: **no change** — profiled at 0.3 µs/frame; `set_hero_hp` / `set_action_visible` setters are no-ops on equal values, and `_can_use` short-circuits at full HP before the inventory scan.

## Changes Made

- `scenes/world/Minimap.gd`, `scenes/world/modules/QuestTracker.gd`, `scenes/world/modules/NightLights.gd`.
- Validation: import, gdlint, unsafe-hits, 3022 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md` (minimap), `docs/agent/story-implementation.md` (quest_pos cache), `docs/agent/visual-polish.md` (night light writes).
