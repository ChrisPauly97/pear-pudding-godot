# TID-620: Enemy Registry Entries & World Placement

**Goal:** GID-149
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

EnemyRegistry entries (deck, drop pool, tier, persona, lore, signature, capture), packs for wolf_pack / scarab_swarm, biome pools (BiomeDef.ENEMY_POOLS), ley-line echo in desert/scorched (InfiniteWorldGen.enemy_type_at), Wendigo as a mountain night spawn (NocturnalSpawner), Barrow King as a quest-gated unique StarterZone camp at the sealed crypt.

## Plan

See Context.

## Changes Made

8 EnemyRegistry rows (+ get_traits), is_tracking additions, BiomeDef pools + LEY_ECHO_BIOMES, InfiniteWorldGen.enemy_type_at echoes, NocturnalSpawner wendigo_or on mountains, StarterZone.BARROW_KING + StarterCamps._update_barrow_king (quest-gated, saved defeat).

## Documentation Updates

docs/agent/enemies-and-npcs.md (GID-149 section).
