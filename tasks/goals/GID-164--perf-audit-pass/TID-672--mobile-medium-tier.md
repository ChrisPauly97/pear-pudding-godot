# TID-672: Medium tier: one AA, deband off, cheaper sun rays

**Goal:** GID-164
**Type:** agent
**Status:** done
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

- Medium: drop MSAA (keep FXAA — it also covers the alpha-cut sprite edges MSAA misses, per TID-501), so one AA pass.
- Keep debanding: it is a dither inside the tonemap pass that already runs, ~free; removing it re-adds visible banding on 8-bit phone panels.
- Sun rays occlusion taps 10 → 6 on Medium. Half-res pass not done: would need a SubViewport restructure of SunRaysFx; the pass is already hidden whenever strength ~0 (midday/night/storm).
- Glow kept (core look; single bloom pass on Mobile renderer).

## Changes Made

- `game_logic/GraphicsQuality.gd`: Medium `msaa_3d` 4x → disabled, `ray_samples` 10 → 6; comment explaining the one-AA choice.
- `assets/shaders/sun_rays.gdshader`: comment updated (6 taps on Medium).
- `tests/unit/test_graphics_quality.gd`: asserts Medium runs no MSAA on top of FXAA.
- Validation: headless import clean, gdlint clean, unsafe-hits clean, runner 3018 passed / 0 failed, 0 SCRIPT ERROR.

## Documentation Updates

- `docs/agent/visual-polish.md`: knob table rows for `msaa_3d` and `ray_samples`, sun-rays tap note.
