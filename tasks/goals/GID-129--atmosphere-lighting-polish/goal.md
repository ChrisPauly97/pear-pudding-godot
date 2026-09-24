# GID-129: Atmosphere & Lighting Polish

## Objective

Make existing weather, lighting, shadows and sound feel good, without adding gameplay features.

## Context

Raised by the user (2026-09-24): *"what can we do to polish the game, don't want new features I just want the existing ones to feel good. weather, atmospheric sound effects, lighting with rays and sun, shadows etc"*, then *"create the goal with quality tiers first"*.

Findings: desktop runs Forward+, Android runs Mobile (no volumetric fog/SSAO/GI). The agreed approach is a Graphics Quality setting: real effects on High/Forward+, cheap shader stand-ins on Mobile. Weather is currently particles plus a tint; all audio is synthesised by `SfxGen` (asset folders hold only READMEs); grass, props and many sprites are unshaded (BID-060).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-484 | Graphics Quality Tiers | agent | done | — |
| TID-485 | Sun Shadows & Golden-Hour Sun | agent | done | TID-484 |
| TID-486 | Weather Drives Fog, Sun & Grass Wind | agent | done | — |
| TID-487 | Rain Wetness & Lightning | agent | done | TID-486 |
| TID-488 | Sun Rays (Volumetric on High, Post-Process Fallback) | agent | done | TID-484 |
| TID-489 | Night Point Lights with Flicker | agent | pending | TID-484 |
| TID-490 | Weather & Time-of-Day Ambience Layers, Music Ducking | agent | done | — |
| TID-491 | Terrain-Aware Footsteps | agent | done | — |
| TID-492 | Source Real CC0 Audio Files | human-action | pending | — |
| TID-493 | Small Ambient Touches (Dust, Fireflies, Leaves) | agent | pending | TID-484 |

## Acceptance Criteria

- [x] Graphics Quality setting (Low/Medium/High) with platform defaults; Forward+-only effects never enabled on Mobile renderer
- [ ] Softer, better-resolved sun shadows and angled, warm dawn/dusk light
- [x] Each weather type changes fog, sun and grass wind; rain wets terrain; storms flash with thunder
- [x] Visible sun rays on Medium and High
- [ ] Night light sources glow and flicker
- [ ] Weather and day/night ambience layers, terrain footsteps, music ducking under dialogue/narration
- [ ] No frame-rate regression on Medium vs. before the goal; all tests, gdlint and unsafe-hits clean
