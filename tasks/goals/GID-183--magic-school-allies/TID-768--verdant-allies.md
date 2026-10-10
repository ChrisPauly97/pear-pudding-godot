# TID-768: Verdant Allies: cards, registry, art

**Goal:** GID-183
**Type:** agent
**Status:** pending
**Depends On:** TID-767

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Build the verdant half of the TID-767 roster.

## Research Notes

- Card format: `data/cards/<id>.tres` (CardData: id, card_name, cost, attack, health, card_class = "minion", description, color, magic_type, magic_branch, optional keywords/spell_effect) — copy `data/cards/dawn_acolyte.tres`. Every `.tres` needs a `.uid` sidecar (CLAUDE.md).
- Register: `autoloads/CardRegistry.gd` one `const _C_X := preload(...)` per card + add to the `_ensure_loaded()` list (Android preload rule).
- Branches (MagicTypes, source of truth): verdant = bloom, thorn; rift = flux, fracture. `test_magic_types` fails if a card's magic_type doesn't own its branch.
- Keywords: `game_logic/battle/Keywords.gd` (ward, surge, shroud); existing minion abilities — read docs/agent/battle-system.md and combat-model.md (Allies) before inventing new effects; prefer existing effects.
- Art (docs/agent/card-visuals.md): `tools/generate_cards.py` FAMILIES crops creature portraits from `assets/textures/characters/`; `game_logic/CardArtRegistry.gd` `_CARD_ART` maps every minion id to a family. `test_every_creature_card_has_generated_art` fails without a row. Reuse existing families (forest/bog creatures for verdant, rift/void creatures for rift) unless a new family is cheap.
- Damage schools: a minion hits as its card's magic_type (DamageSchools.school_of) — docs/agent/damage-schools.md.
- Take the roster from TID-767's task file. Add tests only where a new ability needs logic; registry/art tests already cover the rest.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
