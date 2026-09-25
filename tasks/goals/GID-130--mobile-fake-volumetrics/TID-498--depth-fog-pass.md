# TID-498: Depth-Fog Post Pass

**Goal:** GID-130
**Type:** agent
**Status:** done
**Depends On:** TID-495

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A camera-attached full-screen spatial pass that reads depth and adds noise-scrolled ground fog lit toward the sun/moon — looks volumetric, costs one pass.

## Research Notes

- Depth reconstruct pattern: `night_light_pool.gdshader` (handles Compatibility NDC).
- Lives in `FakeVolumetrics`; full-screen via `POSITION` in vertex shader, `custom_aabb` to avoid culling.
- Knob `depth_fog` (off/off/on); clamped off when real `volumetric_fog` runs.

## Plan

Clip-space full-screen quad in FakeVolumetrics; depth reconstruct + height/noise fog lit by sun or moon; density from the height-fog curve; knob High only, clamped off with real volumetric fog.

## Changes Made

- New `assets/shaders/depth_fog.gdshader` (+ .uid).
- `FakeVolumetrics`: `_update_fog`/`_make_fog`, `fog_density()`, `is_fog_visible()`; shaft size tuned (width 2.0–3.6, length 10) after visual check.
- `AtmosphereMath`: `depth_fog_density`, `DEPTH_FOG_*`.
- `GraphicsQuality`: `depth_fog` (off/off/on), added to `FAKE_VOLUMETRIC`.
- Tests: depth-fog curve; GQ clamp asserts. Rendered dawn/night/rain frames on gl_compatibility under xvfb to verify all GID-130 effects draw.

## Documentation Updates

visual-polish.md: knob row, clamp note, Depth fog + visual-check bullets.
