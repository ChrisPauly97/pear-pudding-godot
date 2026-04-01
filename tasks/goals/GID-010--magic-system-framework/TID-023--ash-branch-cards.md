# TID-023: Ash Branch Spell Cards

**Goal:** GID-010
**Type:** agent
**Status:** pending
**Depends On:** TID-021

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Create the four Ash branch (Dark magic, disruption/necromancy) spell cards as `.tres` resource files with `.uid` sidecars. Ash is the dark offensive branch — earth imagery, phoenix metaphor, resurrection and weakening effects.

## Research Notes

- `data/CardData.gd` — resource script; after TID-021 will have `magic_type`, `magic_branch`, `spell_effect`, `spell_power`
- `data/cards/ghost.tres` — template for `.tres` format
- `.uid` sidecar format: `uid://` + 12 lowercase alphanumeric chars
- `autoloads/CardRegistry.gd` — auto-discovers all `.tres` in `data/cards/`; no changes needed
- Cards go in `data/cards/`

## Proposed Stats (from TID-020)

| Card | cost | spell_effect | spell_power | color | flavour |
|------|------|-------------|-------------|-------|---------|
| Ash | 1 | `debuff_attack` | 2 | Color(0.5, 0.45, 0.4, 1) | "What remains when fire has finished." |
| Brittle | 2 | `deal_damage_single` | 2 | Color(0.6, 0.55, 0.5, 1) | "Cold makes things fragile." |
| Char | 3 | `destroy_low_hp` | 3 | Color(0.3, 0.25, 0.2, 1) | "The last thing it knew was heat." |
| Alight | 4 | `resurrect_last` | 1 | Color(0.7, 0.5, 0.3, 1) | "From ash, something stirs." |

All four: `magic_type = "dark"`, `magic_branch = "ash"`, `card_class = "spell"`, `attack = 0`, `health = 0`.

`spell_power` for `destroy_low_hp` = threshold HP (destroy targets with ≤ 3 HP).
`spell_power` for `resurrect_last` = HP the resurrected minion comes back with (1).
`spell_power` for `debuff_attack` = amount of attack reduction (2).

## Plan

_Written during Plan phase._

For each of the four cards:
1. Generate a UID string.
2. Write `data/cards/<id>.tres` with all fields populated.
3. Write `data/cards/<id>.tres.uid` sidecar.

Cards: `ash`, `brittle`, `char`, `alight`.

Note: `char` is a GDScript keyword. The card **id** `"char"` is just a string so it's fine in `.tres` data, but avoid naming a GDScript variable `char`. The filename `char.tres` is also safe.

## Changes Made

_Filled after Build phase._

## Documentation Updates

None required beyond `docs/agent/magic-system.md` already created in TID-020.
