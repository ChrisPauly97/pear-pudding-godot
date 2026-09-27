# TID-565: Smooth Walk, Swing & Jump Animations

**Goal:** GID-137
**Type:** agent
**Status:** done
**Depends On:** TID-564

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User asked for smooth walking, a swing when engaging an enemy, and a jump animation.

## Research Notes

- `EnemyNPC.engage()` waits a 0.4 s alert beat before `enemy_engaged`, and the
  battle can start synchronously inside that emit — so the swing starts at the
  beginning of the beat (`GameBus.player_attack_started`), not on engage.
- Player.gd is at the 500-line gdlint cap: animation choice lives in the pure
  `game_logic/character/HeroAnim.gd` (unit-tested).
- `IdleLife.hero_bob` lifted on odd frames of the old 4-frame walk; now passing
  frames 2–3 / 6–7. Footsteps on frames 0 and 4.

## Plan / Changes Made

- PaperDoll: `ANIMS` pose table (idle, walk×8, swing×4, jump×2, fall, land×2),
  line-drawn limbs, rotated weapons (scratch image + nearest rotation),
  `wpn_behind` for the backswing; frame widened to 32×28 (body centred, `OX` 8).
- Split for the 500-line cap: `PaperDollPixels.gd` ← `PaperDollGear.gd` ← `PaperDoll.gd`.
- `HeroAnim.pick()` + `HeroAnim.wear()`; Player wiring (jump/fall/land/swing).
- `GameBus.player_attack_started`, emitted in `EnemyNPC.engage()`.
- Tests: distinct walk frames, all animations + loop flags, forward strike
  reach, unarmed swing, jump/fall/land poses, HeroAnim priorities, hero_bob.

## Documentation Updates

- `camera-and-player.md` Paper-doll section rewritten.
