# TID-750: Enemy school profiles + guardrail test

**Goal:** GID-181
**Type:** agent
**Status:** done
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

- Per-enemy `schools` entry (`resist`, `weak` lists) in `EnemyRegistry._ensure_loaded()`; bosses with a phase 2 deck may add `schools_phase2` (full replacement, the only place `immune` appears).
- `get_school_profile(type_id, phase := 1)` builds the `{"resist", "weak", "immune"}` dict `DamageSchools` reads. Pure, no state.
- Themes by lore/biome: undead resist dark / weak light; forest and bog resist verdant; living beasts weak dark; rift-touched resist rift; armoured or spectral resist physical. Biome rosters checked per school.
- Guardrail test in `tests/unit/test_enemy_school_profiles.gd`.

## Changes Made

- `autoloads/EnemyRegistry.gd`: `schools` on all 39 enemy types; `schools_phase2` on `barrow_king` (immune dark); new `get_school_profile()`.
- `tests/unit/test_enemy_school_profiles.gd`: new guardrail suite (profile per enemy, valid school names, no all-school block, immunity only in boss phase 2, non-boss phase 2 unchanged, per-biome and whole-roster weak/resist coverage, theme spot checks).
- No damage resolution code touched; nothing consumes the profiles yet.

## Documentation Updates

- `docs/agent/damage-schools.md`: enemy profile theme list, accessor, guardrail summary, full profile table, tests section.
- `docs/agent/enemies-and-npcs.md`: "Damage School Profiles" section linking to the above.
