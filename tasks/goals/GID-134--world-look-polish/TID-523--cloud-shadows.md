# TID-523: Cloud Shadows

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Big open fields look static.

## Research Notes

Terrain shader global uniform approach (like `terrain_wetness`); wind from WeatherParticles.

## Plan

Shared cloud_shadow() in contact_shadow include (terrain + grass); DayNightCycle accumulates a wind-driven offset and writes strength from AtmosphereMath.

## Changes Made

contact_shadow.gdshaderinc cloud_shadow(); terrain/grass multiply it; project.godot cloud_shadow_strength + cloud_offset globals; DayNightCycle._tick_clouds; AtmosphereMath.cloud_shadow_strength (+test).

## Documentation Updates

visual-polish.md (at goal end).
