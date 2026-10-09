# TID-750: Enemy school profiles + guardrail test

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-748

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Gives every enemy type a lore/biome-themed resist/weak profile so different matchups call for different decks.

## Research Notes

- Data lives only in `autoloads/EnemyRegistry.gd` `_ensure_loaded()` dict (no .tres enemies — CLAUDE.md). Add keys `resist`, `weak`, optional `immune` (boss phase 2 only, alongside `phase2_deck`). Accessor `get_school_profile(type_id, phase := 1) -> Dictionary`, mirroring `get_traits` (L632).
- Themes: undead (undead_basic/horde/elite…) weak light, resist dark; forest/bog creatures (bog hags, GID-174) resist verdant; rift beings resist rift, weak light; golems/armoured resist physical; desert/scorched creatures weak verdant(?) — define a full table in Plan; biome lists via `type_for_biome` (L760) / `get_all_enemy_ids` (L766).
- Traits (armored, regenerating, swarm, caster, flying): existing `EnemyTraits.gd` handles howl/brood/frenzy/mirror; `armored` overlaps with physical resist — prefer school profile; new mechanical traits are out of scope unless trivial.
- Guardrail test `tests/test_enemy_school_profiles.gd`: every id has a profile; no profile resists/immunes all schools; per biome, each school has ≥1 weak target and no school is resisted by every enemy; schools come from MagicTypes + physical.
- Chunk gen threads read EnemyRegistry (CLAUDE.md → TerrainMath threading): keep it pure static data.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
