# TID-282: Dusk Spell Cards — 10 `.tres` Files

**Goal:** GID-076
**Type:** agent
**Status:** done
**Depends On:** TID-279

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Create the 10 Dusk-branch spell card resources. Dusk is drain/curse/disruption — steals life from heroes, discards enemy cards, freezes and stuns minions, and siphons mana.

## Research Notes

### File conventions
Same `.tres` template with `magic_type = "dark"` and `magic_branch = "dusk"`.

### Existing Dusk spells to avoid duplicating
`wither` (cost 1, curse_minion 1), `drain` (cost 2, lifesteal_hit 3), `shadow_bolt` (cost 2, deal_damage_single 4), `siphon` (cost 3, mana_drain 3), `dark_pact` (cost 3, curse_minion 2), `soul_rend` (cost 4, lifesteal_hit 5)

### 10 New Dusk Spells

| ID | Display Name | Cost | Effect | Power | Description |
|---|---|---|---|---|---|
| `dusk_shadow_whisper` | Shadow Whisper | 1 | `enemy_discard` | 1 | A whisper from the void causes the enemy to lose a card. |
| `dusk_nightchill` | Nightchill | 2 | `freeze_single` | 1 | A wave of cold freezes an enemy minion for one turn. |
| `dusk_vampiric_touch` | Vampiric Touch | 2 | `drain_hero` | 3 | Drain 3 life from the enemy hero and restore it to yours. |
| `dusk_corrupt` | Corrupt | 3 | `curse_minion` | 3 | Corrupt a minion — its attack and HP each fall by 3. |
| `dusk_mind_rot` | Mind Rot | 3 | `enemy_discard` | 2 | Rot corrupts the enemy's hand — they discard 2 cards. |
| `dusk_hex` | Hex of Weakness | 3 | `debuff_attack` | 3 | Curse all enemy minions — reduce their attack by 3. |
| `dusk_drain_essence` | Drain Essence | 4 | `drain_hero` | 5 | Drain 5 life from the enemy hero and restore it to yours. |
| `dusk_shadow_bind` | Shadow Bind | 4 | `stun_single` | 2 | Bind an enemy minion in shadow — stunned for 2 turns. |
| `dusk_eclipse` | Eclipse | 5 | `freeze_all` | 1 | Plunge the battlefield into darkness, freezing all enemies. |
| `dusk_soul_eater` | Soul Eater | 6 | `lifesteal_hit` | 8 | Devour a minion's soul — deal 8 and restore that to your hero. |

## Plan

Create 10 .tres + .uid files in data/cards/, add preloads to CardRegistry.gd, update test count 80→90.

## Changes Made

- Created 10 Dusk spell .tres files: dusk_corrupt, dusk_drain_essence, dusk_eclipse, dusk_hex, dusk_mind_rot, dusk_nightchill, dusk_shadow_bind, dusk_shadow_whisper, dusk_soul_eater, dusk_vampiric_touch
- Created matching .uid sidecar files for each
- `autoloads/CardRegistry.gd`: added 10 _C_DUSK_* preload consts and registered in _ensure_loaded()
- `tests/unit/test_card_registry.gd`: updated card count 80 → 90

## Documentation Updates

None (deferred to TID-285).
