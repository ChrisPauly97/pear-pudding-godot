# TID-508: Lit Grass & Props (BID-060)

**Goal:** GID-131
**Type:** agent
**Status:** done
**Depends On:** TID-506

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Grass, props, landmarks and WorldItem are unshaded, ignoring sun/shadows/lights.

## Research Notes

`tasks/backlog/BID-060--unshaded-world-ignores-lights.md`. Night-light pools already fake point lights. Move props to shaded materials; grass: add light via global sun params.

## Plan

Split grass shaders into include + unshaded/lit headers; GrassBlades swaps variants; ChunkRenderer flips cached prop/landmark materials; knob lit_world on High.

## Changes Made

- New `grass_blade.gdshaderinc`, `grass_cluster.gdshaderinc`, `grass_blade_lit.gdshader`, `grass_cluster_lit.gdshader` (+ .uid); original shaders now header + include.
- `GrassBlades.set_lit`/`is_lit`; `ChunkRenderer.set_lit_world`/`_apply_lit`/`is_lit_world`.
- `GraphicsQuality`: `lit_world` (off/off/on); WorldScene forwards it.
- Brightness matched to terrain after a visual check (×1.3 albedo, 0.08 emission).
- Tests: new `test_lit_world.gd`. BID-060 resolved (archived).

## Documentation Updates

visual-polish.md knob row; terrain-rendering.md Lit grass variant subsection; BID-060 progress + archived.
