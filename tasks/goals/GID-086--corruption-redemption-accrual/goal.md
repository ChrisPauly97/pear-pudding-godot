# GID-086: Corruption & Redemption Points Accrual

## Objective

Wire the corruption and redemption point accrual functions into actual gameplay events so the skill-tree currencies can be earned and spent.

## Context

`SaveManager.add_corruption_points()` and `SaveManager.add_redemption_points()` are defined but have zero call sites. The system is wired for spending and display (`corruption_points_changed` / `redemption_points_changed` GameBus signals exist and are emitted), but nothing ever grants the points. The player can never progress any corruption or redemption skill tree branch in practice. Per user decision (June 2026): points should accrue from gameplay. (BID-017)

Intended accrual sites:
- **Corruption**: winning battles using Dawn-branch (dark/aggressive) cards; cleansing Blight Hearts
- **Redemption**: winning battles using Dusk-branch (healing/protective) cards; completing story chapter flags

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-308 | Accrue corruption points from battle outcomes | agent | pending | — |
| TID-309 | Accrue redemption points from battle outcomes and story flags | agent | pending | — |

## Acceptance Criteria

- [ ] Winning a battle awards corruption points proportional to Dawn-branch cards played
- [ ] Winning a battle awards redemption points proportional to Dusk-branch cards played
- [ ] Cleansing a BlightHeart awards a fixed corruption point bonus
- [ ] Setting story chapter flags awards a fixed redemption point bonus
- [ ] `GameBus.corruption_points_changed` and `redemption_points_changed` fire after each award
- [ ] Points persist across sessions via SaveManager
- [ ] All existing tests pass headless
