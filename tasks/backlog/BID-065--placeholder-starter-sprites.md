# BID-065: Starter enemies and townsfolk use placeholder-grade sprites

**Category:** design-inconsistency
**Discovered During:** GID-141 / TID-593

## Description

The two enemy types a new player fights most (undead_basic, undead_horde) render as a 16 px skull icon (`enemy_undead.png`), and townsfolk share three tiny tinted sprites, while ghouls, raiders and bosses have proper pack art. The first 30 minutes therefore look the least finished (game-appeal weakness #4).

## Evidence

GID-141 / TID-593 capture (starter camps, Madrian). `SpriteRegistry.enemy_texture` maps undead_basic/undead_horde → `_ENEMY_UNDEAD`.

## Suggested Resolution

Source or generate proper skeleton/zombie sprites (see `docs/agent/art-sprites.md` manifest + `tools/generate_sprites.py`) and distinct townsfolk sprites for the named quest givers.
