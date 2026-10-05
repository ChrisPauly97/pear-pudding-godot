# TID-672: Medium tier: one AA, deband off, cheaper sun rays

**Goal:** GID-164
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Medium is the mobile default and stacks MSAA 4x + FXAA + debanding + glow + 6 fake shafts + halos + a full-screen sun-rays pass. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `game_logic/GraphicsQuality.gd:102-118` — Medium tier settings.
- `assets/shaders/sun_rays.gdshader:19,69` — `hint_screen_texture` forces a full-screen copy; 10 dependent taps/pixel.
- Fix: Medium = one AA (MSAA 2x *or* FXAA), deband off; sun rays to 4-6 taps or a half-res pass; consider glow off on Medium.
- Depth fog is already High-only (turns MSAA off). Check tests asserting tier values (grep `GraphicsQuality` in tests/).

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
