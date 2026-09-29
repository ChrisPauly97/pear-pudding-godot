# TID-611: B2 — Generated Card Art & Spell Runes

**Goal:** GID-144
**Type:** agent
**Status:** done
**Depends On:** TID-610

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-070. `cards/card_{ghost,skeleton,zombie,ghoul}.png`, `cards/rune_{dawn,dusk,ember,ash}.png` (CC BY).

## Research Notes

`SpriteRegistry.card_illustration_texture`. Portraits = crops of generated characters; runes = glyph drawer.

## Plan

New `tools/generate_cards.py`: busts cropped from the generated characters (doubled to 32×32), rune glyphs drawn with the prop Canvas; same file names so no code change.

## Changes Made

`tools/generate_cards.py`; regenerated 8 card PNGs. CREDITS: dropped the game-icons.net rune and Danaida sections, updated 0x72/Kenney/Tiny Creatures usage.

Follow-up (user review): Polish pass: ember rune redrawn as a layered teardrop flame over coals.

## Documentation Updates

`art-sprites.md` (B2 ✓), `visual-polish.md` card-art note, CREDITS.
