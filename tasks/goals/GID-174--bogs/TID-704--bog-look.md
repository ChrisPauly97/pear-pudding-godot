# TID-704: Bog terrain look + props

**Goal:** GID-174
**Type:** agent
**Status:** pending
**Depends On:** TID-703

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Bogs should be visibly distinct.

## Research Notes

- Terrain shader: murky green-brown water band + peat tint (bake bog intensity into a vertex channel alongside UV2 water in `ChunkRenderer`).
- Props: dead trees (TreeScatter variant), reeds, mist (AmbientTouches ground mist), will-o'-wisp lights at night (`NightLights`).

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
