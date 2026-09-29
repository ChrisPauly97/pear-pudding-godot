# TID-605: Graveyard Dressing

**Goal:** GID-143
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-066: graveyard is town brick walls + mounds.

## Research Notes

- Generate headstone variants, low iron fence segment, crypt facade props with generate_sprites.py conventions.
- Place as props (see how `NamedMapProps` / prop instancing places static sprites; `docs/agent/visual-polish.md` GPU-instanced props).
- Replace the graveyard fence wall tiles in `madrian.tres` (local 8..18, 47..56) with fence props + keep collision (tiles as WALL but render low? check TerrainMath wall rendering); sealed crypt keeps real walls (Phase needs them).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
