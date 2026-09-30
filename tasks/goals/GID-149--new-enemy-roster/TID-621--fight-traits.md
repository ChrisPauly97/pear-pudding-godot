# TID-621: Fight Traits (howl, swarm, frenzy, mirror)

**Goal:** GID-149
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Pure EnemyTraits table applied by BattleModifiers: wolf howl (extra wolf on enemy turn 3), scarab queen (refill a scarab each enemy turn while alive), wendigo frenzy (+1 attack per enemy turn after 6), riftborn echo (deck mirrors the player's spells), Barrow King phase 2 via the existing boss framework.

## Plan

See Context.

## Changes Made

game_logic/battle/EnemyTraits.gd (howl, brood, frenzy, mirror); BattleModifiers.apply_enemy_traits/trait_deck; hooks in BattleScene enemy-turn start and BattleRealtime round events. Ember braziers scope-cut.

## Documentation Updates

docs/agent/enemies-and-npcs.md (GID-149 section).
