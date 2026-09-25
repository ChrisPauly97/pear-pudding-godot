# GID-131: Visual Smoothing & Polish

## Objective

Make the game look less jagged, blocky and flat: edge smoothing, debanding, grounded characters, stable pixel art, softer terrain and grass, a real UI theme, and lit grass/props.

## Context

Raised by the user (2026-09-25): *"what would also make the game look nicer? like more polished less jagged and blocky and bad"* → *"let's work our way through these"*. Only MSAA is on (misses alpha-cut sprites and shader edges); no debanding; no character shadows on Medium; nearest-filtered sprites shimmer; terrain shows a hard tile grid; grass reads as dark spikes; UI is the default Godot theme; grass/props are unshaded (BID-060).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-501 | FXAA / TAA Edge Smoothing | agent | done | — |
| TID-502 | Debanding | agent | done | — |
| TID-503 | Blob Shadows Under Characters | agent | done | — |
| TID-504 | Smooth Pixel-Art Sprite Filtering | agent | done | — |
| TID-505 | Softer Terrain Tile Blending | agent | done | — |
| TID-506 | Grass Shading Pass | agent | pending | — |
| TID-507 | Custom UI Theme | agent | pending | — |
| TID-508 | Lit Grass & Props (BID-060) | agent | pending | TID-506 |

## Acceptance Criteria

- [ ] Each effect is a GraphicsQuality knob where it costs GPU time; Low stays cheap
- [ ] Visual before/after checked on gl_compatibility under xvfb
- [ ] Tests, gdlint, unsafe-hits clean
