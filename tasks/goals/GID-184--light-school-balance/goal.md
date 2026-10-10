# GID-184: Light School Damage & School Balance (BID-101)

## Objective

Close BID-101: the school-matched light deck trails the default deck by 20–35 pp because its technique fill
(`tech_pyroblast` + `tech_blazing_draw`) carries a draw-only card. Give light real single-target damage, re-measure,
and make balance band (a) (every school-matched deck within ±25 pp of the default) gating.

## Context

- User decision (2026-10-10): rework Blazing Draw into a single-target light damage + draw-1 technique.
- Bands and sims: `game_logic/battle/BalanceBands.gd`, `tests/balance_bands.gd`, `tools/balance_sim.gd`,
  `docs/agent/balance-sim.md` (School bands). Matched decks: `BattleSetup.school_matched_deck`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-772 | Blazing Draw → light smite + draw (`smite_draw` effect) | agent | done | — |
| TID-773 | Re-measure schools, tune, gate band (a) | agent | done | TID-772 |

## Acceptance Criteria

- [x] Blazing Draw deals light damage to one target and draws a card, in both battle modes
- [x] Light matched deck within ±25 pp of the default deck in every biome cell
- [x] Band (a) gating in `tests/balance_bands.gd`; BID-101 archived
