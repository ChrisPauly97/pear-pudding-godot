# TID-681: Bake static battle backdrop once

**Goal:** GID-164
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battle backdrop shader computes ground/noise/props per pixel every frame. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `assets/shaders/battle_backdrop.gdshader:128-175` — 2 ground fetches, `fwidth`, value noise, hash prop-cell test, prop fetch, TIME-driven.
- Fix: when `anim == 0` or on Low/Medium, render once into a `SubViewport` (`UPDATE_ONCE`) and show via TextureRect; re-render on resize / biome change.
- Owner: `scenes/battle/modules/BattleArena.gd` (backdrop). Check the GraphicsQuality tier accessor.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

- `BattleBackdrop.bake(bg)`: SubViewport (UPDATE_ONCE, 2D only) renders the shader once into a texture shown by a TextureRect; re-rendered on resize so SCREEN_PIXEL_SIZE still matches; Background's material cleared.
- `BattleArena._setup_backdrop`: below High, apply with the clock frozen and bake. High (desktop default) unchanged. In-world fights already skip the backdrop.

## Changes Made

- `scenes/battle/BattleBackdrop.gd`, `scenes/battle/modules/BattleArena.gd`.
- `tests/unit/test_battle_backdrop.gd::test_bake_swaps_shader_for_a_one_shot_texture`.
- Validation: import, gdlint, unsafe-hits, 3026 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests.

## Documentation Updates

- `docs/agent/visual-polish.md` Battle Backdrop section.
