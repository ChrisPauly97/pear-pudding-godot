# TID-681: Bake static battle backdrop once

**Goal:** GID-164
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
