# TID-519: Grass Palette

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Flat grass is very saturated and uniform, so everything reads as one green.

## Research Notes

`terrain.gdshader` flat-grass branch (`grass_tint`, macro `v_d0/v_d1`), ChunkRenderer biome tints, grass blade shaders.

## Plan

Mute/warm grassland + hill tints; stronger macro variation incl. cool lush hollows.

## Changes Made

BiomeDef GRASS_TINT[0] 0.70,0.80,0.30 and HILL_TINT[0] 0.58,0.66,0.26; terrain.gdshader macro variation widened + cool patches.

## Documentation Updates

visual-polish.md (at goal end).
