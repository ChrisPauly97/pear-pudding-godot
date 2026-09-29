# BID-069: Replace third-party world characters with generated sprites

**Category:** design-inconsistency
**Discovered During:** GID-143 / TID-607

## Description

Enemies (undead elite, ghoul, raider, warleader, duelist, rival, terror, spectre) and NPCs (townsfolk ×3, merchant ×2, Maiteln) are still 0x72 / Kenney pack art.

## Evidence

`docs/agent/art-sprites.md` → "Third-party art inventory & generation roadmap", batch B1.

## Suggested Resolution

Extend tools/generate_characters.py (skeleton/zombie/person rigs + a large rig + a floating ghost rig); swap SpriteRegistry preloads; walk frames where used.
