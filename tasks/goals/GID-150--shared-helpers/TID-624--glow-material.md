# TID-624: WorldEntityBase.glow_material()

**Goal:** GID-150
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Eleven entity materials repeated unshaded + emission_enabled/emission/energy by hand.

## Plan

See Context.

## Changes Made

Added `glow_material(color, emission, energy)` next to `unshaded_material`; used in BlightHeart, ManaWell, ObjectiveBeacon, WildernessCamp, WorldItem. PuzzleShrine left alone (it is lit, not unshaded).

## Documentation Updates

CLAUDE.md (helper pointer).
