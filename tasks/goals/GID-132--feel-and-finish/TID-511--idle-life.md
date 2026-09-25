# TID-511: Idle Life for World Sprites

**Goal:** GID-132
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

World NPC/enemy billboards are completely still.

## Research Notes

Billboards from `SpriteRegistry.make_billboard()` (EnemyNPC, MerchantNPC, TownspersonNPC). Prefer a per-node phase-offset bob in a shared cheap update, or Sprite3D offset animation.

## Plan

Pure IdleLife pose rules + registration; posing loop folded into the contact-shadow module (renamed CharacterPresence) to stay under the WorldScene line ceiling; enemy chase speed-up and alert hop.

## Changes Made

- New `game_logic/IdleLife.gd`.
- `ContactShadows.gd` → `CharacterPresence.gd` (+ idle-life loop, `animated_count()`); WorldScene field/const renamed.
- Townsperson/Merchant (breathe), EnemyNPC (bob / float for spectres, fast while chasing, hop on alert) register.
- Tests: new `test_idle_life.gd`. Runtime check: 4 in-range sprites animated, far ones skipped.

## Documentation Updates

visual-polish.md Idle Life section + module rename; CLAUDE.md module table row.
