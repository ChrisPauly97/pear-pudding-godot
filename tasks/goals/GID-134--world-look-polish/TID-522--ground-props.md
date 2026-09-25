# TID-522: Scattered Ground Props

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Empty grass between points of interest.

## Research Notes

GPU-instanced props already exist (visual-polish.md); ChunkRenderer entity/prop spawning.

## Plan

More prop types per biome with weighting, per-type sizes, ground-anchored quads, size/mirror variety, clumps; fix placement.

## Changes Made

BiomeDef PROP_SETS/PROP_SIZES/PROP_CLUMPS; ChunkRenderer: prop positions chunk-local (pre-existing bug drew every non-origin chunk's props a second origin away, so only chunk 0,0 had any), clumps, keep_scale + per-instance scale/flip, padded visibility range.

## Documentation Updates

visual-polish.md (at goal end).
