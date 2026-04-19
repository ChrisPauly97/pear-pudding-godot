# TID-055: Create Dawn Branch Card .tres Files

**Goal:** GID-018
**Type:** agent
**Status:** done
**Depends On:** TID-054

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Dawn branch represents light/healing/restoration magic. This task creates the .tres card resources and their .uid sidecars. Spell effect handlers must exist first (TID-054).

## Research Notes

- Existing card .tres files live in `data/cards/` — follow their format exactly
- Every .tres needs a companion `.uid` file (see CLAUDE.md). Generate uid: `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`
- `CardData` fields: id (String), display_name (String), cost (int), attack (int), health (int), magic_type (String), magic_branch (String), spell_effect (String), spell_power (int), auto_resolve (bool), card_class (String: "minion" or "spell")
- `magic_type` for Dawn cards: `"dawn"`, `magic_branch`: `"light"`
- Minion cards have attack + health > 0; spell_effect is empty or auto-targeting; card_class = "minion"
- Spell cards have attack=0, health=0, card_class = "spell"; spell_power drives the effect

**Planned Dawn cards (8 total):**

| ID | Display Name | Cost | Attack | Health | Class | Spell Effect | Spell Power |
|---|---|---|---|---|---|---|---|
| dawn_acolyte | Dawn Acolyte | 2 | 1 | 3 | minion | — | 0 |
| dawn_paladin | Dawn Paladin | 4 | 2 | 5 | minion | — | 0 |
| mend | Mend | 1 | 0 | 0 | spell | heal_single | 3 |
| restore | Restore | 3 | 0 | 0 | spell | heal_all | 2 |
| bulwark | Bulwark | 2 | 0 | 0 | spell | shield_minion | 2 |
| rally | Rally | 3 | 0 | 0 | spell | buff_attack | 2 |
| radiance | Radiance | 4 | 0 | 0 | spell | heal_all | 4 |
| blessed_light | Blessed Light | 2 | 0 | 0 | spell | heal_single | 5 |

## Plan

Create 8 .tres files and 8 .uid sidecars in `data/cards/` following the ember.tres format. Use `magic_type = "light"`, `magic_branch = "dawn"`, Color(1, 0.9, 0.5, 1) (golden). For spell cards: attack=0, health=0 omitted (they default to 0). For minion cards: no spell_effect/spell_power.

## Changes Made

Created 8 Dawn card .tres files and 8 .uid sidecars in `data/cards/`:
- `dawn_acolyte.tres` — 2-cost minion (1/3), light/dawn
- `dawn_paladin.tres` — 4-cost minion (2/5), light/dawn
- `mend.tres` — 1-cost spell, heal_single 3
- `restore.tres` — 3-cost spell, heal_all 2
- `bulwark.tres` — 2-cost spell, shield_minion 2
- `rally.tres` — 3-cost spell, buff_attack 2
- `radiance.tres` — 4-cost spell, heal_all 4
- `blessed_light.tres` — 2-cost spell, heal_single 5

Note: `magic_type = "light"`, `magic_branch = "dawn"` (research notes had these reversed vs actual CardData schema).

## Documentation Updates

No doc changes needed — battle-system.md spell_effect table was updated in TID-054.
