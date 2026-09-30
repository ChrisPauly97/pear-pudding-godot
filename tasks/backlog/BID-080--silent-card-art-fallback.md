# BID-080: Missing card art falls back silently

**Category:** code-smell
**Discovered During:** GID-151 research

## Description

`CardRegistry._ensure_loaded()` falls back to `TextureGen.card_illustration()` whenever `SpriteRegistry` has no
art for a card, with no warning or test. Most minions and all Verdant/Rift spells silently render procedural art.

## Evidence

`autoloads/CardRegistry.gd` ~l.200–213; `SpriteRegistry.card_illustration_texture` only matches four ids.

## Suggested Resolution

Covered by GID-151 TID-639/TID-640, which add a coverage test.
