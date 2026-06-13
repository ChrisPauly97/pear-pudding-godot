# BID-017: add_corruption_points / add_redemption_points never called — currencies may never accrue

**Category:** design-inconsistency
**Discovered During:** GID-074 research (simplification audit, June 2026)

## Description

`SaveManager.add_corruption_points()` (SaveManager.gd:800) and
`SaveManager.add_redemption_points()` (SaveManager.gd:805) are defined but have zero
call sites anywhere in the codebase. These are the accrual entry points for the
skill-tree corruption/redemption currencies (GID-032 / docs/agent/skill-trees.md), and
GameBus declares matching `corruption_points_changed` / `redemption_points_changed`
signals that are emitted elsewhere — so the system appears wired for spending/display
but nothing ever grants the points. Unlike plain dead code, deleting these would be
wrong if the currencies are supposed to accrue from gameplay (battles, story choices)
and that hookup was simply never implemented.

## Evidence

- `autoloads/SaveManager.gd:800` `add_corruption_points()` — 0 call sites
- `autoloads/SaveManager.gd:805` `add_redemption_points()` — 0 call sites
- `docs/agent/skill-trees.md` describes corruption/redemption currencies as live systems

## Suggested Resolution

Decide whether corruption/redemption points are meant to accrue in v1. If yes, create a
task to call these from the intended gameplay sites (likely battle outcomes or story
flags). If no, remove the functions and the related currency UI/signals. GID-074
TID-274 (SaveManager simplification) deliberately leaves these two functions alone
pending this decision.
