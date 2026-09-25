# TID-514: Rain Splashes & Ripples

**Goal:** GID-133
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rain has no ground impact.

## Research Notes

`AmbientTouches` + `AmbientParticles` own weather-driven ambient emitters (shared static meshes/materials, amount_ratio fades). WeatherLook `wetness` (rain 0.6, heavy 1.0).

## Plan

RainParticles factories (flat ring quads + bouncing drops, shared resources) and splash_level rule; AmbientTouches spawns/follows/fades them under ambient_particles.

## Changes Made

- New `game_logic/RainParticles.gd`; `AmbientTouches`: rings/drops emitters, `splash_level()`.
- Tests: new `test_rain_particles.gd`. Visual check in heavy rain.

## Documentation Updates

visual-polish.md Rain Splashes section.
