# TID-525: Per-Biome Colour Grade

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Biomes share one light/fog look.

## Research Notes

Existing biome color grade (visual-polish.md), DayNightCycle fog colour, ChunkRenderer tints.

## Plan

Per-biome mood colour (ambient, fog, sun) + existing grade, eased over ~3 s in DayNightCycle instead of snapping.

## Changes Made

BiomeDef.ADJ_PARAMS mood + BIOME_BLEND_SECONDS; DayNightCycle set_biome_grade/_tick_grade/_apply_grade/mood(), applied to sun, ambient, fog; WorldScene._apply_biome_color_grade delegates (+test in test_atmosphere_math).

## Documentation Updates

visual-polish.md (at goal end).
