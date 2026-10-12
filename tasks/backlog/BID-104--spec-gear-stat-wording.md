# BID-104: Spec still describes gear as "item-level stat rolls"

**Category:** spec-gap
**Discovered During:** GID-187 / TID-788

## Description

`docs/human/specification.md` (Damage Schools & Horizontal Progression) says school affixes "sit on top of
item-level stat rolls", and Identity says progression is "not a stat bar". The user decided (2026-10-11) that gear
carries hand-made stats that **boost the cards** (haste → draw speed, spell / physical crit → card and weapon
damage, …), that random rolls retire (TID-789), and that gear is ~60 % of a level-30 player's power.

## Suggested Resolution

Human edit of the spec (human-owned): describe gear as hand-made items whose stats boost cards (list in
`docs/agent/inventory-and-deck.md` → Gear Stats), drop "item-level stat rolls", and note the gear share target.
