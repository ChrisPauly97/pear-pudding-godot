# TID-317: Per-biome color grading & vignette

**Goal:** GID-089
**Type:** agent
**Status:** pending
**Depends On:** TID-315

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

All five biomes currently look similar at the `WorldEnvironment` level — only terrain tints differentiate them. This task adds a per-biome `Environment.adjustment` color grade (saturation, brightness, contrast curve) and a mild screen-space vignette via a full-screen `CanvasLayer` shader. The vignette is a single-pass 2D shader (no 3D post-process needed), so it is Android-safe. Explicitly excludes SSAO, SDFGI, and SSR — those are desktop-only effects. Depends on TID-303 because it builds on the `Environment` setup done there.

## Research Notes

**Environment.adjustment API (Godot 4):**
- `env.adjustment_enabled = true`
- `env.adjustment_brightness`, `env.adjustment_contrast`, `env.adjustment_saturation` — simple scalar uniforms
- `env.adjustment_color_correction` — optional `GradientTexture1D` for LUT-style grade; start with scalars
- These are cheap post-process passes, mobile-compatible

**Per-biome grades (approximate design intent):**
| Biome | Brightness | Contrast | Saturation | Character |
|---|---|---|---|---|
| Grasslands | 1.0 | 1.05 | 1.1 | Lush, vivid |
| Forest | 0.95 | 1.05 | 0.85 | Cool, desaturated |
| Desert | 1.1 | 1.1 | 0.9 | Harsh, bleached |
| Scorched | 0.9 | 1.15 | 0.7 | Dark, muted |
| Mountains | 1.05 | 1.0 | 0.8 | Cold, crisp |

**BiomeDef reference:**
`BiomeDef` is defined in `game_logic/world/` — add `adj_brightness`, `adj_contrast`, `adj_saturation` fields and apply them in `ChunkRenderer` or `WorldScene` when the active biome changes. `GameBus` already emits `biome_changed` on biome transitions.

**Vignette implementation:**
- `CanvasLayer` (layer 127, above all UI) with a `ColorRect` covering the viewport
- A custom 2D shader on the `ColorRect` that darkens corners: `float d = distance(UV, vec2(0.5)); COLOR.a = smoothstep(0.35, 0.75, d) * 0.35;`
- No `.tres`/`.uid` needed — attach the shader source inline via `ShaderMaterial` created at runtime
- `CanvasLayer` is always present; the vignette strength can be 0 in menus (alpha = 0)

**Android constraint:** `adjustment_*` uniforms and 2D shaders are trivially cheap. No SSAO/SDFGI/SSR.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
