# TID-610: B1 — Generated World Characters

**Goal:** GID-144
**Type:** agent
**Status:** todo
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

## Changes Made

## Documentation Updates
