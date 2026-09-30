# TID-625: IsoConst.tile_center()

**Goal:** GID-150
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`float(t) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5` was written out ~48 times.

## Plan

See Context.

## Changes Made

Added static `IsoConst.tile_center(t)`; replaced every copy in InfiniteWorldGen, MapEditorScene, ChunkRenderer, MapViewOverlay, Minimap, SceneManager.

## Documentation Updates

CLAUDE.md (helper pointer).
