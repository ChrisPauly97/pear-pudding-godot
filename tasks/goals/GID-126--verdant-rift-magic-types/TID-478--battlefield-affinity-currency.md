# TID-478: Branch Affinity Table + Cross-Magic Currency Accrual

Goal: [GID-126](goal.md) · Type: agent · Status: done

## Problem

Two battle-side systems name Dawn and Dusk literally:

1. `BattlefieldRules.effective_cost()` — `if is_night and branch == "dusk"` /
   `elif not is_night and branch == "dawn"`.
2. `PlayerState.dawn_cards_played` / `dusk_cards_played`, plumbed through
   `BattleScene` → `BattleResultUI` → the battle result dict → `SceneManager`,
   which converts them to corruption / redemption points.

Neither can express a Bloom or Fracture card.

## Changes Made

### Battlefield affinity

- **`game_logic/battle/BattlefieldRules.gd`** — new `BRANCH_AFFINITY` table:

  | Branch | Condition | Effect |
  |---|---|---|
  | `dawn` | daytime | −1 mana |
  | `dusk` | night | −1 mana |
  | `bloom` | Forest biome | −1 mana |
  | `fracture` | Scorched biome | −1 mana |

  `effective_cost()` now consults the table instead of branching on literals.
  Light and Dark keep the time-of-day axis they already had; Verdant and Rift use
  the biome axis, so the two never stack on one card. `branch_affinity_text()`
  was added alongside it for UI use.

  Ember, Ash, Thorn and Flux have no affinity — one affinity branch per type,
  matching what Light and Dark already did.

### Currency accrual

- **`game_logic/battle/PlayerState.gd`** — the `dawn_cards_played` /
  `dusk_cards_played` int pair became `branch_cards_played: Dictionary`
  (branch → count), incremented in one place for any branch. New
  `cross_currency_earned()` folds that dictionary through
  `MagicTypes.currency_for_branch()` and returns
  `{"corruption": n, "redemption": n}`.
- **`scenes/battle/BattleScene.gd`** — passes that dictionary instead of two ints.
- **`scenes/battle/BattleResultUI.gd`** — the three result builders took
  `dawn_played: int = 0, dusk_played: int = 0`; they now take
  `currency_earned: Dictionary = {}` and write `corruption_earned` /
  `redemption_earned` into the result dict. Two parameters became one, and the
  three copies of the same pass-through pair collapsed.
- **`autoloads/SceneManager.gd`** — reads the two new result keys directly. The
  `CORRUPTION_PER_CARD` / `REDEMPTION_PER_CARD` constants moved into
  `MagicTypes.POINTS_PER_CARD`, since the per-card rate is a property of the
  magic system, not of scene routing.

## Behaviour Preserved

A Dawn card still grants exactly 1 corruption point and a Dusk card exactly 1
redemption point. The rename makes the rule explicit rather than changing it: the
currency was never "the Dawn currency", it was "the currency a Light player
spends", and Dawn is Light's signature branch.

## Documentation Updates

`docs/agent/battle-system.md`, `docs/agent/magic-system.md`,
`docs/agent/skill-trees.md` (TID-479).
