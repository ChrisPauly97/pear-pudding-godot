# TID-612: B3 — Generated Chest, Door, Mimic & Horse

**Goal:** GID-144
**Type:** agent
**Status:** done
**Depends On:** TID-610

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-071. `props/chest_{closed,open}.png`, `props/door.png`, `characters/enemy_mimic.png`, `characters/mount_horse.png`.

## Research Notes

Chest/door in `generate_sprites.py` (door shares crypt-door drawing); mimic from the chest; horse is a quadruped rig.

## Plan

Chest/door in `generate_sprites.py` at the old pixel sizes (entities use a fixed pixel size); mimic built on the chest drawing, horse rig at 32×32 facing right; same file names.

## Changes Made

New generators `chest_body`, `chest`, `door`, `pad`, `mimic`, `horse`; regenerated 5 PNGs. CREDITS: 0x72 and Tiny Creatures now unused.

## Documentation Updates

`art-sprites.md` (B3 ✓), CREDITS.
