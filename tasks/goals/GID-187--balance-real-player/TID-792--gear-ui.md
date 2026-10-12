# TID-792: Gear UI: stats, comparison, level requirement

**Goal:** GID-187
**Type:** agent
**Status:** done
**Depends On:** TID-789

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Item tooltips list stats (rating and the % it gives at the player's level), band / rarity colour and level
requirement; compare against the equipped item (green / red deltas); the character sheet totals every stat.
Touch and mouse parity (long-press to inspect).

## Research Notes

- `scenes/ui/CharacterScene.gd`, `BlacksmithScene.gd`, inventory tiles (`tests/inventory_tiles_smoke.gd`);
  `UiUtil` factories, `UiUtil.rarity_color`, `LongPressDetector`.
- Viewport-relative sizing rules in CLAUDE.md.

## Plan

1. Pure `game_logic/items/GearTooltip.gd`: `build` (name, band + item level, level requirement flag, one line
   per stat with rating and value at the player's level, legacy mechanic line), `stat_line` / `summary`,
   `compare` (per-stat deltas) with `delta_rows` for green / red, `sheet_lines` for the character-sheet totals.
2. CharacterScene: picker rows show the summary and the requirement; inspect popup (Shift hover, long-press on
   every row) shows details plus green / red deltas vs equipped; "Gear stats" sheet block; equip above the
   player's level refused with a toast.
3. BlacksmithScene rows show band, requirement, current and next stat summaries.
4. Keep CharacterScene under gdlint's 500-line limit: popup body and sheet rendering in `scenes/ui/GearInspect.gd`.
5. Unit tests `tests/unit/test_gear_tooltip.gd`; docs in `docs/agent/inventory-and-deck.md`.

## Changes Made

- `game_logic/items/GearTooltip.gd` (new): the pure formatter described above.
- `scenes/ui/GearInspect.gd` (new): popup body (`fill`), character-sheet rendering (`fill_sheet`), `upgrade_level_of`.
- `scenes/ui/CharacterScene.gd`: picker rows use `GearTooltip.summary` and show "Requires level N (you are level M)"
  when unmet; inspect on every row (Shift hover / long-press) via `GearInspect.fill`; "Gear stats" block refreshed
  from `_refresh_slot_buttons`; `_on_equip` refuses `level_req > level` with a "Too advanced" toast. The old
  single `effective_stat` delta is gone from the popup.
- `scenes/ui/BlacksmithScene.gd`: weapon rows show band / item level / requirement and stat summaries (current and next).
- `tests/unit/test_gear_tooltip.gd` (new): 15 tests (labels, percent at level 1 and 30, cap, upgrade scaling,
  requirement flag, deck_inject mechanic line, compare deltas incl. empty slot and identical items, sheet totals).

Validation: parse check clean; `scripts/unsafe-hits.sh` clean; `gdlint` clean over the source tree; full runner
RESULT: PASS with 0 SCRIPT ERROR; `world_scene_smoke` and `menu_hub_smoke` exit 0 with no SCRIPT ERROR.
`inventory_tiles_smoke` not re-run (known BID-106 failure).

Notes: the mechanic line shows for any non-empty `battle_effect_type` rather than only deck_inject / offhand_atk,
so legacy starting-* effects on items that also carry stats are not hidden. Equip buttons stay enabled above the
level so the refusal explains itself. The roll multiplier affects only the legacy battle values, not stat ratings.

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: new "Gear Tooltips and Comparison (GID-187 / TID-792)" section under Gear Curve.
