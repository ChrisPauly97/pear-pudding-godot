# TID-610: B1 — Generated World Characters

**Goal:** GID-144
**Type:** agent
**Status:** done
**Depends On:** TID-609

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-069. Replace undead elite, ghoul, raider, warleader, duelist, rival, terror, spectre, townsfolk ×3, merchant ×2, Maiteln (+walk).

## Research Notes

Rigs in `tools/generate_characters.py` (skeleton, zombie, person(spec)). Only Maiteln's walk frames are loaded; other enemies need an idle frame only — delete their pack walk frames. Preloads in `game_logic/SpriteRegistry.gd`.

## Plan

Add rigs (elite, ghoul, spectre, warleader, terror) and `person()` extensions + `CAST` specs; write over the same file names so SpriteRegistry preloads are unchanged; verify with preview sheet + xvfb capture.

## Changes Made

`tools/generate_characters.py`: 5 new rigs, hats/helm/cloak/pack/pauldrons/axe/rapier/lantern, `CAST`, `WALKERS` (Maiteln only). Regenerated 17 sprites. Deleted every unused `enemy_*_walk_*.png`.

## Documentation Updates

`art-sprites.md` roadmap (B1 ✓), `enemies-and-npcs.md` sprite notes, CREDITS per-slot index + pack usage.
