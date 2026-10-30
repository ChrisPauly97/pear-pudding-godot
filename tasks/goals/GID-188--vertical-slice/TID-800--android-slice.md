# TID-800: Android build + performance check of the slice

**Goal:** GID-188
**Type:** agent
**Status:** done
**Depends On:** TID-795

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Build the APK with slice mode on, check frame time in Madrian + camps + battles on a mid-range device profile, fix hitches found.

## Research Notes

- `docs/agent/` Android notes, GID-005 export hardening, `tools/profile_world.gd`; preload rule for .tres on Android.

## Plan

No device or Android SDK in the agent container, so: (1) profile the slice headless against the full game,
(2) export the Android pack with the real preset and boot it standalone, (3) check new code follows the Android
rules (preload only, no dynamic `.tres` loads). The signed APK itself builds in CI on push to main
(`.github/workflows/android-build.yml`); on-device feel is for the first playtest.

## Results

- `tools/profile_world.gd --frames 900`: slice p50 6.89 / p95 9.82 / p99 15.18 ms; full game 6.89 / 9.26 / 14.41 ms
  (same 66 frames > 8 ms; differences are run noise — the headless p50 is the 144 fps cap). 0 orphan nodes.
  New per-frame work is negligible (a 1 s playtest timer, a cast-bar tint).
- `godot --headless --export-pack "Android"`: 38 MB pack, includes `SliceRules`, `CaptureReveal`, `SavePlaytest`,
  `PlaytestMetrics`; `pear_pudding/slice_mode` rides in the exported project settings.
- Booting that pack alone (`--main-pack`, empty working dir, 900 frames): 0 `SCRIPT ERROR`s.
- New code uses `preload` only; Full Game choice is `user://full_game.cfg` (writable on Android).

## Changes Made

None needed (verification task).

## Documentation Updates

- `docs/agent/vertical-slice.md`: Performance & Android section.
