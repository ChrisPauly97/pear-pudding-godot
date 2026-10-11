# TID-790: Author the item catalogue

**Goal:** GID-187
**Type:** agent
**Status:** done
**Depends On:** TID-789

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Hand-author the items: every slot in every band, with at least two items per slot and band that differ in stat
focus (e.g. a tanky Stamina/Armor helm vs a Haste/Crit helm), plus the per-magic-type pieces (Mastery of that
school) from Superior. Roughly 8 slots × 5 bands × 2 ≈ 80 items, plus weapons per swing speed. Names and lore
fit the story (`docs/human/story.md`, read-only); icons reuse or extend the existing gear art.

## Research Notes

- Each `.tres` needs a `.uid` sidecar and a `const` preload in `WeaponRegistry` (Android packaging rule).
- Weapon swing speeds: dagger 1.8, wand 2.2, blade 2.6, staff 3.2, axe 3.6 (`WeaponData.swing_speed`).
- `test_gear_budget` (TID-789) validates every item.

## Plan

- Hand-made `.tres` gear in `data/weapons/` for every slot and band: two items per slot per band (A tank, B caster),
  five weapons per band (one per swing class), so each band has 19 items.
- Ratings come from a throwaway generator that solves integer ratings against `GearCurve.budget` (aim 97 %, in band).
- Register every item in `WeaponRegistry` with a preload const (under 500 lines, so no separate catalogue file).
- Paper doll: visible-slot items need a `GEAR_VISUALS` entry. Move the table to `PaperDollVisuals.gd` to keep
  `PaperDoll.gd` under 500 lines.
- Update the legacy count assertions (helmets / boots / off-hands 3 → 13).

## Changes Made

- 95 new `data/weapons/*.tres` items, each with a `.uid` sidecar. Item counts per band (identical per band):

  | Band | Weapon | Armor | Helmet | Shoulders | Boots | Offhand | Ring | Trinket | Total |
  |---|---|---|---|---|---|---|---|---|---|
  | basic | 5 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 19 |
  | fine | 5 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 19 |
  | superior | 5 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 19 |
  | heroic | 5 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 19 |
  | legendary | 5 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 19 |

- `autoloads/WeaponRegistry.gd`: 95 preload consts and list entries (196 lines).
- `game_logic/character/PaperDollVisuals.gd` (new): the `GEAR_VISUALS` table, moved out of `PaperDoll.gd`, plus 85
  entries for the new visible-slot items (rings are not drawn). `PaperDoll.gd` re-exports it.
- Test counts: `test_head_feet_equipment` (helmets / boots 3 → 13) and `test_offhand_equipment` (off-hands → 13).
- Validation: `GearCurve.validate()` passes for every registered item. Parse check clean, `unsafe-hits.sh` clean,
  gdlint clean on changed files, `tests/runner.gd` passes with 0 `SCRIPT ERROR`, `balance_bands` passes.
  `inventory_tiles_smoke` still fails on card checks (deck swap, forge scrap, sell basket). These are card-instance
  checks untouched by this change. The task said it already fails on main (BID-106).
- Shops, chests and boss rewards draw from the whole registry, so they now offer the new gear.

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: new "Gear Catalogue (GID-187 / TID-790)" section with the band/slot table,
  shape rules and visuals note. The Gear Curve table's legendary row no longer defers unique effects to TID-790.
