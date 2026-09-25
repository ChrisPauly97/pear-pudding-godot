# GID-132: Feel & Finish

## Objective

Make the game read as finished: a real font, icon HUD buttons, living world sprites and punchy battles.

## Context

Raised by the user (2026-09-25) after GID-131: *"next improvements"* → *"ok, do 1-4"*. No font file in the project (engine default everywhere); HUD buttons are text ("[D] Dig", "Menu"); world NPC/enemy sprites are static; only 3 battle scripts use tweens.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-509 | Project Fonts (Nunito body, Cinzel titles) | agent | done | — |
| TID-510 | HUD Button Icons | agent | done | — |
| TID-511 | Idle Life for World Sprites | agent | pending | — |
| TID-512 | Battle Juice | agent | pending | — |

## Acceptance Criteria

- [ ] Fonts bundled with OFL licence + CREDITS entry; fallback to the engine font for missing glyphs
- [ ] HUD actions show icons on touch and desktop (key hints kept on desktop)
- [ ] NPCs/enemies idle-bob, cheap (shader or shared tween), off-screen cost ~0
- [ ] Battle attacks/damage/hover have motion; respects Reduce Flashing / Screen Shake settings
- [ ] Tests, gdlint, unsafe-hits, smoke tests clean
