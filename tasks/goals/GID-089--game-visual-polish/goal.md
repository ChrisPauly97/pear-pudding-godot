# GID-089: Visual Polish — World Art, Atmosphere & Props

## Objective

Replace colored-box enemies with pixel-art billboard sprites, add atmospheric fog and sky, scatter biome props, add per-biome color grading, add interactable highlights, and complete card illustration art.

## Context

The game has solid terrain shaders, a day/night cycle, and filmic tonemapping, but the most visible visual weaknesses remain: enemies and NPCs are flat colored `BoxMesh` blocks (the player sprite is a proper pixel-art wizard), the sky is a hard flat-color backdrop with no depth or fog, terrain between entities is empty, cards mostly use color fills despite `CardData.illustration` existing, and there is no visual language for "this thing is interactable." This goal addresses all six in one pass. All work must stay Android-safe (no SSAO/SDFGI, GPU-instanced capped props, procedural textures cached).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-314 | Pixel-art enemy & NPC billboard sprites | agent | done | — |
| TID-315 | Atmospheric sky gradient & distance fog | agent | done | — |
| TID-316 | Environmental prop scatter per biome | agent | done | — |
| TID-317 | Per-biome color grading & vignette | agent | done | TID-315 |
| TID-318 | Interactable highlight & selection outline | agent | done | — |
| TID-319 | Per-card illustration art | agent | done | — |

## Acceptance Criteria

- [ ] Enemies and NPCs render as pixel-art billboard sprites, not solid colored boxes
- [ ] The sky shows a procedural gradient that shifts with day/night; horizon has distance fog
- [ ] Each biome has scatter props (rocks, flowers, mushrooms) on grass tiles, GPU-instanced and density-capped for Android
- [ ] Each biome has a subtle `Environment.adjustment` color grade; a mild vignette is present; no SSAO/SDFGI
- [ ] The nearest interactable entity (chest, NPC, door) glows or has a visible selection outline
- [ ] All 4 card types have procedural pixel-art illustration textures via `CardData.illustration`
