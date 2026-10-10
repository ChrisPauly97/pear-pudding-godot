# TID-769: Rift Allies: cards, registry, art

**Goal:** GID-183
**Type:** agent
**Status:** done
**Depends On:** TID-767

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Build the rift half of the TID-767 roster.

## Research Notes

- Card format: `data/cards/<id>.tres` (CardData: id, card_name, cost, attack, health, card_class = "minion", description, color, magic_type, magic_branch, optional keywords/spell_effect) — copy `data/cards/dawn_acolyte.tres`. Every `.tres` needs a `.uid` sidecar (CLAUDE.md).
- Register: `autoloads/CardRegistry.gd` one `const _C_X := preload(...)` per card + add to the `_ensure_loaded()` list (Android preload rule).
- Branches (MagicTypes, source of truth): verdant = bloom, thorn; rift = flux, fracture. `test_magic_types` fails if a card's magic_type doesn't own its branch.
- Keywords: `game_logic/battle/Keywords.gd` (ward, surge, shroud); existing minion abilities — read docs/agent/battle-system.md and combat-model.md (Allies) before inventing new effects; prefer existing effects.
- Art (docs/agent/card-visuals.md): `tools/generate_cards.py` FAMILIES crops creature portraits from `assets/textures/characters/`; `game_logic/CardArtRegistry.gd` `_CARD_ART` maps every minion id to a family. `test_every_creature_card_has_generated_art` fails without a row. Reuse existing families (forest/bog creatures for verdant, rift/void creatures for rift) unless a new family is cheap.
- Damage schools: a minion hits as its card's magic_type (DamageSchools.school_of) — docs/agent/damage-schools.md.
- Take the roster from TID-767's task file. Runs in parallel with TID-768: both touch CardRegistry.gd and CardArtRegistry.gd — keep additions in contiguous blocks to ease merging.

## Plan

- Eight rift Allies from the TID-767 roster: flux (Skitterwisp, Blinkfox, Warp Adept, Temporal Rider)
  and fracture (Shardling, Mirror Wight, Displacer, Unmaker). Stats, costs and keywords as in the roster.
- Only new mechanic: `emergence_freeze_random` (Displacer), one `match` arm in `resolve_emergence`
  reusing the `"freeze"` status. Real-time and AI placements already route through `resolve_emergence`.
- Art rows reuse existing families (scout, rift_echo, duelist, rival, scarab, ghost, warden, undead_elite).

## Changes Made

- `data/cards/{flux_skitter,flux_blinkfox,flux_warp_adept,flux_temporal_rider,fracture_shardling,fracture_mirror_wight,fracture_displacer,fracture_unmaker}.tres` + `.tres.uid` sidecars.
- `autoloads/CardRegistry.gd`: 8 `_C_*` preloads (end of preload block) and 8 list entries (end of `_ensure_loaded()` list).
- `game_logic/CardArtRegistry.gd`: 8 `_CARD_ART` rows (end of dict).
- `scenes/battle/SpellEffectResolver.gd`: `"emergence_freeze_random"` arm in `resolve_emergence` (picks one opponent minion, `apply_status("freeze", power)`).
- `game_logic/battle/SpellEffectLabels.gd`: `EMERGENCE` label for the new effect.
- `tests/unit/test_emergence_freeze_random.gd`: freezes exactly one enemy, duration = power, never friendly, empty board no-op, rift cards registered with correct branches.
- `tests/unit/test_card_registry.gd`: total card count 128 -> 136.

## Documentation Updates

- `docs/agent/magic-system.md`: roster section marked as built for the rift half; `fracture_displacer` noted as the new-effect card.
- `docs/agent/battle-system.md`: `emergence_freeze_random` added to the emergence effect list (two places).
