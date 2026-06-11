# TID-248: Ley Line Rendering — Terrain Shader Overlay + Minimap Hint

**Goal:** GID-068
**Type:** agent
**Status:** pending
**Depends On:** TID-247

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Ley lines must read clearly in the pixel-art isometric view without cluttering the terrain: a thin emissive band (cyan or gold) that pulses slowly, plus a faint trace on the minimap so players can follow a line beyond the screen edge.

## Research Notes

**Shader approach (preferred — like the grass FBM pattern):**
- The terrain is drawn by `assets/shaders/terrain.gdshader`, applied per chunk by `scenes/world/ChunkRenderer.gd`, which already passes per-biome tint uniforms. Extend the fragment stage: recompute the ley intensity from the fragment's world position and add emissive glow where intensity > 0.
- **The shader must mirror TID-247's GDScript math exactly** — same noise type, frequency, threshold. FastNoiseLite isn't available in shader language, so either:
  - (a) implement the same simplex noise in shader code and accept close-but-not-identical fields (NOT acceptable — gameplay checks would disagree with visuals), or
  - (b) **bake per-chunk ley data on the CPU**: when ChunkRenderer builds a chunk, sample `TerrainMath.ley_intensity` on a per-tile (or 2× per-tile) grid into a small `ImageTexture` and pass it as a uniform sampler; the shader just reads the texture and applies smoothstepped glow. Option (b) guarantees gameplay/visual agreement and is the recommended path — document this in the Plan.
- World position in fragment: pass chunk origin as a uniform or use `world_vertex_coords` / VERTEX in world space — check how terrain.gdshader currently handles coordinates for its biome tinting.
- Pulse: modulate emission with `0.8 + 0.2 * sin(TIME * 0.8)` — slow, subtle.
- If a separate overlay shader/material file is created instead of editing terrain.gdshader: new `.gdshader` files need a `.uid` sidecar (`uid://` + 12 lowercase alphanumerics, generate via the python one-liner in CLAUDE.md) and must be referenced with `preload()`, never runtime `load()` (Android export scanner rule). No geometry shaders in Godot 4.

**Per-chunk texture cost:**
- A 16×16 or 32×32 single-channel image per loaded chunk (load radius 6 ≈ ~170 chunks) is trivial memory. Build it in the same WorkerThreadPool task that builds chunk meshes to avoid main-thread stalls; `ImageTexture.create_from_image` must run on the main thread in Godot 4 — follow how chunk meshes hand results back.

**Minimap:**
- `scenes/world/Minimap.gd` draws the area around the player. For each minimap texel/cell, sample `TerrainMath.ley_intensity` (cheap; cache per redraw) and blend a faint cyan pixel where on-line. Keep sampling resolution coarse (per tile, not per pixel) to bound cost.

**Visual tuning targets:**
- Band reads at a glance but doesn't fight with grass/path tiles; emission visible at night (day/night tint shader multiplies scene color — emissive should punch through, verify against the time-of-day tinting path in WorldScene).

**Testing:**
- Headless: the CPU-side per-chunk ley texture bake (function returning Image) — determinism and value agreement with `TerrainMath.ley_intensity`. Visual confirmation manual; full test suite must stay green.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
