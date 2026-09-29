# BID-070: Replace third-party card art and spell runes

**Category:** design-inconsistency
**Discovered During:** GID-143 / TID-607

## Description

Card portraits (ghost/skeleton/zombie/ghoul) are pack art; the four spell runes are game-icons.net (CC BY 3.0, attribution required).

## Evidence

`docs/agent/art-sprites.md` → "Third-party art inventory & generation roadmap", batch B2.

## Suggested Resolution

Card portraits from the generated characters; a rune glyph drawer in generate_sprites.py.
