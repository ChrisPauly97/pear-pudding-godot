# TID-055: Create Dawn Branch Card .tres Files

**Goal:** GID-018
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
