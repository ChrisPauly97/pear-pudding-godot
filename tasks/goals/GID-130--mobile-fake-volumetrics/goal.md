# GID-130: Mobile Fake Volumetrics

## Objective

Give Android (Mobile renderer) atmospheric depth — mist, light shafts, halos, fog — without Forward+ volumetric fog, plus an opt-in real Forward+ path.

## Context

Raised by the user (2026-09-25): *"what can we do to extend the lighting and fog volumetric for mobile android"* → *"do all of these please"*.

Android runs the Mobile renderer, so `GraphicsQuality.clamp_to_renderer()` turns off `volumetric_fog`/`ssao` and demotes `SUN_RAYS_VOLUMETRIC` to the screen pass. Phones default to Medium. Each task adds one GraphicsQuality knob (all three tiers, cost non-decreasing) and a stand-in that works on every renderer. Stand-ins that duplicate a real Forward+ effect are clamped off when that effect runs.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-494 | Height Fog (valley mist) | agent | done | — |
| TID-495 | Fake Light Shafts & Night-Light Halos | agent | done | — |
| TID-496 | HQ Screen Rays & Moon Rays | agent | done | — |
| TID-497 | Ground Mist Particles | agent | done | — |
| TID-498 | Depth-Fog Post Pass | agent | done | — |
| TID-499 | Opt-in Forward+ Renderer on Android | agent | done | — |
| TID-500 | Fix Wavy Lines in Fake Light Shafts | agent | done | TID-495 |

## Acceptance Criteria

- [x] Every new effect is a GraphicsQuality knob; Low stays cheap; cost never drops as tier rises
- [x] All stand-ins run on Mobile and Compatibility renderers; none double up with real Forward+ volumetrics
- [x] Opt-in Forward+ on Android takes effect after restart and self-reverts after a crashed boot
- [x] Tests, gdlint and unsafe-hits clean
