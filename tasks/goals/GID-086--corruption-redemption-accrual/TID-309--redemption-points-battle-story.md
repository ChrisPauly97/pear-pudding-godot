# TID-309: Accrue redemption points from battle outcomes and story flags

**Goal:** GID-086
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`SaveManager.add_redemption_points()` has zero call sites. Per user decision (June 2026): redemption points should accrue from Dusk-branch card usage in battles and from story milestone flags.

Intended accrual logic:
- On battle victory, count how many Dusk-branch cards were played
- Award `played_dusk_cards * REDEMPTION_PER_CARD` points (suggested 1 per card)
- When a story chapter flag is set (e.g. `chapter1_complete`), award a fixed redemption bonus (suggested 10 points)
- Call `SaveManager.add_redemption_points(amount)` and verify `GameBus.redemption_points_changed` fires

Dusk-branch card identification: check `CardData.magic_branch == "dusk"` or equivalent field.

## Plan

## Changes Made

## Documentation Updates
