# TID-022: Ember Branch Spell Cards

**Goal:** GID-010
**Type:** agent
**Status:** done
**Depends On:** TID-021

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Create the four Ember branch (Light magic, offensive fire) spell cards as `.tres` resource files with `.uid` sidecars. These are the first Card/Spell type cards in the game.

## Research Notes

- `data/CardData.gd` — resource script; after TID-021 will have `magic_type`, `magic_branch`, `spell_effect`, `spell_power`
- `data/cards/ghost.tres` — template for `.tres` format; uses `script_class="CardData"` and `uid://` header
- `.uid` sidecar format: single line `uid://` followed by 12 lowercase alphanumeric chars; generate with `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`
- `autoloads/CardRegistry.gd` — auto-discovers all `.tres` in `data/cards/`; no changes needed
- Cards go in `data/cards/`

## Proposed Stats (from TID-020)

| Card | cost | spell_effect | spell_power | color | flavour |
|------|------|-------------|-------------|-------|---------|
| Spark | 1 | `deal_damage_single` | 1 | Color(1.0, 0.7, 0.2, 1) | "The smallest flame is still a flame." |
| Flicker | 2 | `deal_damage_all` | 1 | Color(1.0, 0.6, 0.1, 1) | "Unstable, uncontainable, inevitable." |
| Ember | 3 | `deal_damage_single` | 3 | Color(1.0, 0.4, 0.05, 1) | "What smolders longest burns deepest." |
| Scorch | 5 | `deal_damage_single` | 5 | Color(1.0, 0.2, 0.0, 1) | "Nothing survives the full expression of the flame." |

All four: `magic_type = "light"`, `magic_branch = "ember"`, `card_class = "spell"`, `attack = 0`, `health = 0`.

## Plan

_Written during Plan phase._

For each of the four cards:
1. Generate a UID string.
2. Write `data/cards/<id>.tres` with all fields populated.
3. Write `data/cards/<id>.tres.uid` sidecar.

Cards: `spark`, `flicker`, `ember_card` (avoid shadowing branch name if needed), `scorch`.

Note: card id `"ember"` may shadow the branch name in docs — use `"ember_card"` as the id if that causes confusion, or keep `"ember"` since ids are just strings. Prefer `"ember"` for simplicity.

## Changes Made

- `data/cards/spark.tres` + `spark.tres.uid` — cost 1, `deal_damage_single` 1, light/ember spell
- `data/cards/flicker.tres` + `flicker.tres.uid` — cost 2, `deal_damage_all` 1, light/ember spell
- `data/cards/ember.tres` + `ember.tres.uid` — cost 3, `deal_damage_single` 3, light/ember spell
- `data/cards/scorch.tres` + `scorch.tres.uid` — cost 5, `deal_damage_single` 5, light/ember spell

## Documentation Updates

None required beyond `docs/agent/magic-system.md` already created in TID-020.
