# TID-767: Verdant + rift Ally roster design

**Goal:** GID-183
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Design 6–8 Allies per school before building, so verdant and rift get board presence with a distinct identity (verdant: sustain/ward/growth; rift: tempo/shroud/displacement).

## Research Notes

- Card format: `data/cards/<id>.tres` (CardData: id, card_name, cost, attack, health, card_class = "minion", description, color, magic_type, magic_branch, optional keywords/spell_effect) — copy `data/cards/dawn_acolyte.tres`. Every `.tres` needs a `.uid` sidecar (CLAUDE.md).
- Register: `autoloads/CardRegistry.gd` one `const _C_X := preload(...)` per card + add to the `_ensure_loaded()` list (Android preload rule).
- Branches (MagicTypes, source of truth): verdant = bloom, thorn; rift = flux, fracture. `test_magic_types` fails if a card's magic_type doesn't own its branch.
- Keywords: `game_logic/battle/Keywords.gd` (ward, surge, shroud); existing minion abilities — read docs/agent/battle-system.md and combat-model.md (Allies) before inventing new effects; prefer existing effects.
- Art (docs/agent/card-visuals.md): `tools/generate_cards.py` FAMILIES crops creature portraits from `assets/textures/characters/`; `game_logic/CardArtRegistry.gd` `_CARD_ART` maps every minion id to a family. `test_every_creature_card_has_generated_art` fails without a row. Reuse existing families (forest/bog creatures for verdant, rift/void creatures for rift) unless a new family is cheap.
- Damage schools: a minion hits as its card's magic_type (DamageSchools.school_of) — docs/agent/damage-schools.md.
- Look at light/dark minion stat curves (grep card_class = "minion" with magic_type light/dark) to match cost→stats budget.
- Output: a roster table (id, name, branch, cost, atk/hp, keyword/ability, flavour line, art family) written into this task file AND into docs/agent/magic-system.md (spell card rosters section). No code in this task.

## Plan

- Read spec Identity, magic-system, battle-system, combat-model (Allies), damage-schools, MagicTypes, Keywords, CardData, the light/dark minion `.tres` set, `SpellEffectResolver.resolve_emergence`, and the art FAMILIES / `_CARD_ART` tables.
- Cost to stat budget taken from the light/dark minion curve: cost 1 ≈ 3 points, 2 ≈ 4, 3 ≈ 5–6, 4 ≈ 6–7, 5 ≈ 8. A keyword or emergence effect is worth about one stat point.
- Verdant = sustain, ward and growth (Bloom: heals and buffs; Thorn: ward and retaliation). Rift = tempo, shroud and displacement (Flux: draw, surge and buffs; Fracture: shroud and removal-by-freeze).
- 8 Allies per school, 4 per branch. Mechanics reuse existing keywords (`ward`, `surge`, `shroud`) and emergence keys, except one flagged new emergence (`emergence_freeze_random`) for the Displacer.
- Output: roster below (Changes Made), mirrored into `docs/agent/magic-system.md`. No code.

## Changes Made

Design document only. No game code, card `.tres`, or registry edits.

### Ally Roster — Verdant & Rift (GID-183 / TID-767)

Design only. Every Ally below uses a keyword that exists (`ward`, `surge`, `shroud`) and/or an
emergence effect that `SpellEffectResolver.resolve_emergence` already runs, except one flagged
new mechanic. Stat budget is matched to the light/dark Allies: cost 1 ≈ 3 stat points, cost 2 ≈ 4,
cost 3 ≈ 5–6, cost 4 ≈ 6–7 (a keyword or emergence buys roughly one stat point), cost 5 ≈ 8.
Verdant identity is sustain, ward and growth (Bloom heals and grows, Thorn wards and retaliates).
Rift identity is tempo, shroud and displacement (Flux acts fast, Fracture hides and stops things).

| ID | Name | Branch | Cost | ATK/HP | Keyword / ability (existing) | Flavour | Art family |
|---|---|---|---|---|---|---|---|
| `bloom_sprout` | Sproutling | Bloom | 1 | 1/2 | `emergence_heal_hero` 1 | It is small, and it has already begun sharing its water. | herbalist |
| `bloom_grove_mother` | Grove Mother | Bloom | 3 | 1/5 | `emergence_heal_hero` 3 | Every wound in the grove is somebody's nursery. | stag |
| `bloom_rootweaver` | Rootweaver | Bloom | 4 | 2/5 | `emergence_buff_friendly` 1 | Its roots reach for the nearest friend and pull it closer. | treant |
| `bloom_elder_root` | Elder Root | Bloom | 5 | 2/6 | `ward`; `emergence_heal_hero` 3 | It was here before the road, and it means to be here after. | treant |
| `thorn_briar_sprite` | Briar Sprite | Thorn | 2 | 1/3 | `emergence_apply_poison` 1 | Brush it once and you will remember which hand. | worm |
| `thorn_bramble_warden` | Bramble Warden | Thorn | 3 | 1/4 | `ward` | It never attacks. It has never needed to. | treant |
| `thorn_thornback` | Thornback Briarhound | Thorn | 4 | 2/4 | `ward`; `emergence_apply_poison` 1 | Its spines grow back faster than you can take them. | wolf_pack |
| `thorn_briarwall` | Briarwall Colossus | Thorn | 5 | 2/6 | `emergence_deal_damage` 2 (verdant school) | Walk into the thorns and the thorns walk into you. | terror |
| `flux_skitter` | Skitterwisp | Flux | 1 | 1/2 | `emergence_draw` 1 | It arrives before the thing it came to warn about. | scout |
| `flux_blinkfox` | Blinkfox | Flux | 2 | 2/2 | `surge` | There is always one more fox than you counted. | rift_echo |
| `flux_warp_adept` | Warp Adept | Flux | 3 | 1/3 | `emergence_buff_friendly` 2 | She is already where she said she would be, which is rude. | duelist |
| `flux_temporal_rider` | Temporal Rider | Flux | 5 | 3/3 | `surge`; `emergence_deal_damage` 2 (rift school) | He has been a moment early three days running. | rival |
| `fracture_shardling` | Shardling | Fracture | 2 | 1/3 | `shroud` | A piece of something that was once whole, now mostly corners. | scarab |
| `fracture_mirror_wight` | Mirror Wight | Fracture | 3 | 1/4 | `emergence_apply_poison` 1 | It shows you the wound before you have taken it. | ghost |
| `fracture_displacer` | Displacer | Fracture | 4 | 2/4 | `shroud`; **NEW** `emergence_freeze_random` 1 | Every step it takes leaves the ground slightly less where it was. | warden |
| `fracture_unmaker` | Unmaker | Fracture | 5 | 3/3 | `shroud`; `emergence_deal_damage` 2 (rift school) | The seam splits, and whatever sat on the seam is no longer there. | undead_elite |

Art families are keys of `tools/generate_cards.py` `FAMILIES`, except `ghost` (the existing
`_CARD_GHOST` in `game_logic/CardArtRegistry.gd`). Families are reused across cards (as `treant`,
`worm`, `terror` are); TID-768 / TID-769 should check each portrait reads as the card and swap
to a nearby family if not.

Notes for the build tasks:
- **Near-duplicate check.** Bramble Warden (1/4 ward) sits next to Bog Treant (1/5 ward, `treant`);
  the 1 HP gap keeps the Thorn ward card below the Treant's stat line.
- **Verdant Allies hit as verdant, Rift Allies hit as rift** (`DamageSchools.school_of`), so the
  emergence damage on Briarwall and Unmaker, and the Thorn poison, follow the school rules in
  `docs/agent/damage-schools.md`.
- **One new mechanic (flagged).** `emergence_freeze_random` (Displacer): on placement, call
  `apply_status("freeze", power)` on one random enemy minion, the same call `freeze_single` uses in
  `SpellEffectResolver.gd`. Estimate: one `match` arm in `resolve_emergence` (~6 lines), one entry in
  the emergence key list in `battle-system.md` and the `CardData` docs, and an `EMERGENCE_LABELS`
  line for the card face. About 30 min including one unit test. Everything else in the roster uses
  existing keys. If the build task wants to avoid it, Displacer becomes a plain `shroud` 2/4 at cost 4.
- **Drop biomes** are TID-770's call; the roster does not set them.


## Documentation Updates

- `docs/agent/magic-system.md`: "Ally Roster — Verdant & Rift (GID-183 / TID-767)" added under the spell card roster section.
