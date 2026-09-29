# GID-143: First-Session Art Pass

## Objective

The first 30 minutes look finished: original undead enemies and named-NPC sprites, a dressed graveyard, and key art
behind the main menu — and a roadmap to replace every third-party sprite with generated originals.

## Context

GID-141 / TID-593 audit logged BID-065 (undead enemies are a 16 px skull icon; townsfolk share three tiny
sprites), BID-066 (graveyard has no dressing), BID-067 (menu has no key art). User (2026-09-29): go ahead with a live
menu view (static fallback on low graphics), and "long term generate sprites for everything that's currently 3rd
party too". Existing precedent: `tools/generate_sprites.py` generates props/landmarks in the pack style
(`tools/pixel_palette.py`, 1 px outline, top-left light); characters are still 0x72 pack art (CC0) — see
`docs/agent/art-sprites.md`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-603 | Generated Undead Enemy Sprites | agent | done | — |
| TID-604 | Generated Named-NPC Sprites | agent | done | TID-603 |
| TID-605 | Graveyard Dressing | agent | pending | — |
| TID-606 | Main Menu Key Art (live view + static fallback) | agent | pending | — |
| TID-607 | Third-Party Art Inventory & Generation Roadmap | agent | pending | TID-603 |
| TID-608 | Before/After Captures & Docs | agent | pending | TID-603, TID-604, TID-605, TID-606, TID-607 |

## Acceptance Criteria

- [ ] Undead Wanderer / Horde Shambler use original generated sprites (idle + walk) at the character target heights.
- [ ] Every named quest giver / trainer has a distinct generated sprite.
- [ ] The graveyard reads as a graveyard (headstones, low fence, crypt facade).
- [ ] The main menu shows Madrian at dusk behind the buttons (static image on Low graphics).
- [ ] A complete list of third-party art with a generation plan per asset.
- [ ] BID-065/066/067 resolved; tests, lint, unsafe-hits, smokes pass.
