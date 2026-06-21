# TID-281: Dawn Spell Cards — 10 `.tres` Files

**Goal:** GID-076
**Type:** agent
**Status:** done
**Depends On:** TID-279

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Create the 10 Dawn-branch spell card resources. Dawn is healing/protection — restores hero health, grants Ward/Shroud to minions, armors heroes, and can silence (Bind) enemy keywords.

## Research Notes

### File conventions
Same `.tres` template as TID-280 but with `magic_type = "light"` and `magic_branch = "dawn"`.

### Existing Dawn spells to avoid duplicating
`mend` (cost 1, heal_single 3), `blessed_light` (cost 2, heal_single 5), `bulwark` (cost 2, shield_minion 2), `restore` (cost 3, heal_all 2), `rally` (cost 3, buff_attack 2), `radiance` (cost 4, heal_all 4)

### 10 New Dawn Spells

| ID | Display Name | Cost | Effect | Power | Description |
|---|---|---|---|---|---|
| `dawn_soothing_touch` | Soothing Touch | 1 | `heal_hero` | 4 | A gentle blessing restores 4 HP to your hero. |
| `dawn_guardian_vow` | Guardian's Vow | 2 | `grant_ward` | 0 | Anoint a minion with Ward — enemies must face it first. |
| `dawn_aegis` | Aegis | 2 | `armor_hero` | 4 | Surround your hero with 4 points of holy armor. |
| `dawn_bind` | Bind | 2 | `bind_minion` | 0 | Bind an enemy minion, stripping all its keywords. |
| `dawn_blessing` | Blessing of Vigor | 3 | `buff_health_all` | 2 | Invigorate all your minions, granting +2 health. |
| `dawn_sanctuary` | Sanctuary | 3 | `grant_shroud` | 0 | Cloak a minion in holy light — the first hit is absorbed. |
| `dawn_beacon` | Beacon of Hope | 4 | `heal_all` | 3 | A beacon of light restores 3 HP to all friendly minions. |
| `dawn_lay_on_hands` | Lay on Hands | 4 | `heal_hero` | 8 | Channel divine power to restore 8 HP to your hero. |
| `dawn_aegis_of_all` | Aegis of All | 5 | `grant_ward_all` | 0 | All your minions become Ward guardians. |
| `dawn_salvation` | Salvation | 6 | `heal_hero` | 12 | A miracle of light restores 12 HP to your hero. |

## Plan

Create 10 .tres + .uid files in data/cards/, add preloads to CardRegistry.gd, update test count 70→80.

## Changes Made

- Created 10 Dawn spell .tres files: dawn_aegis, dawn_aegis_of_all, dawn_beacon, dawn_bind, dawn_blessing, dawn_guardian_vow, dawn_lay_on_hands, dawn_salvation, dawn_sanctuary, dawn_soothing_touch
- Created matching .uid sidecar files for each
- `autoloads/CardRegistry.gd`: added 10 _C_DAWN_* preload consts and registered them in _ensure_loaded()
- `tests/unit/test_card_registry.gd`: updated card count assertion from 70 → 80

## Documentation Updates

None (deferred to TID-285).
