# TID-503: Blob Shadows Under Characters

**Goal:** GID-131
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No character shadows on Medium (phone default); sprites float.

## Research Notes

Billboards come from `SpriteRegistry.make_billboard()`; player in `scenes/world/Player.gd`. Shared static soft-disc mesh/material, decal-like quad flat on the ground; knob `blob_shadows`.

## Plan

Mesh blob tried first (hidden by terrain jitter/grass); switched to shader contact shadows: casters register, module writes 6 globals, terrain + grass shaders darken.

## Changes Made

- New `game_logic/ContactShadow.gd`, `scenes/world/modules/ContactShadows.gd`, `assets/shaders/contact_shadow.gdshaderinc` (+ .uid).
- `project.godot`: 7 new `[shader_globals]`.
- `terrain.gdshader`, `grass_blade.gdshader`, `grass_cluster.gdshader`: include + ALBEDO multiply.
- 7 character scripts register as casters; WorldScene module wiring + `apply_knobs` in `apply_graphics_quality`.
- Tests: new `test_contact_shadow.gd`. Visual check on gl_compatibility.

## Documentation Updates

visual-polish.md: Contact Shadows section. CLAUDE.md module table row.
