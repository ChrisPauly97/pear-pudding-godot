# TID-768: Verdant Allies: cards, registry, art

**Goal:** GID-183
**Type:** agent
**Status:** done
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

Take the eight verdant rows of the TID-767 roster as written (no stat or ability changes). No new
mechanics: every ability is an existing keyword (`ward`) or emergence key (`emergence_heal_hero`,
`emergence_buff_friendly`, `emergence_apply_poison`, `emergence_deal_damage`). Art families reuse
existing preloads only.

## Changes Made

Eight verdant Allies, all `magic_type = "verdant"`, `card_class = "minion"`, `color` from the existing bloom
(0.45, 0.9, 0.5) / thorn (0.75, 0.85, 0.3) cards:

| ID | Branch | Cost | ATK/HP | Ability | Art family |
|---|---|---|---|---|---|
| `bloom_sprout` | bloom | 1 | 1/2 | emergence_heal_hero 1 | herbalist |
| `bloom_grove_mother` | bloom | 3 | 1/5 | emergence_heal_hero 3 | stag |
| `bloom_rootweaver` | bloom | 4 | 2/5 | emergence_buff_friendly 1 | treant |
| `bloom_elder_root` | bloom | 5 | 2/6 | ward; emergence_heal_hero 3 | treant |
| `thorn_briar_sprite` | thorn | 2 | 1/3 | emergence_apply_poison 1 | worm |
| `thorn_bramble_warden` | thorn | 3 | 1/4 | ward | treant |
| `thorn_thornback` | thorn | 4 | 2/4 | ward; emergence_apply_poison 1 | wolf_pack |
| `thorn_briarwall` | thorn | 5 | 2/6 | emergence_deal_damage 2 | terror |

Files:
- `data/cards/<id>.tres` x8 and `data/cards/<id>.tres.uid` x8 (fresh uids, checked against the tree).
- `autoloads/CardRegistry.gd`: eight `_C_BLOOM_*` / `_C_THORN_*` preload consts after `_C_THORN_WILD_GROWTH`,
  and one contiguous list line block after the existing `_C_THORN_*` line in `_ensure_loaded()`.
- `game_logic/CardArtRegistry.gd`: eight rows appended at the end of `_CARD_ART`.
- `tests/unit/test_card_registry.gd`: `get_all_ids().size()` bumped 128 -> 136 (the test's own comment
  says to bump it when cards are added; TID-769 will bump it again).

Validation (worktree at 212550b + this change):
- Compile check (`godot --editor` parse/compile grep): clean.
- `scripts/unsafe-hits.sh`: no hits. gdlint on the two changed `.gd` files: clean.
- `tests/runner.gd`: exit 0, 3446 passed, 0 failed, 0 `SCRIPT ERROR`. Includes test_magic_types and the card-art tests.
- `tests/balance_bands.gd`: RESULT: PASS.

Art families were not changed: the TID-767 family picks all exist in `CardArtRegistry` preloads and
the portraits have not been visually checked in-game.

## Documentation Updates

- `docs/agent/magic-system.md`: no change. The final numbers and abilities match the TID-767 roster
  table exactly, so the roster section is still accurate.
