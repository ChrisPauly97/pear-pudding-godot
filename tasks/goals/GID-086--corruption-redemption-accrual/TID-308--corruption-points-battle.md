# TID-308: Accrue corruption points from battle outcomes

**Goal:** GID-086
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`SaveManager.add_corruption_points()` has zero call sites. Per user decision (June 2026): corruption points should accrue from Dawn-branch card usage in battles.

Intended accrual logic:
- On battle victory, count how many Dawn-branch cards were played this battle
- Award `played_dawn_cards * CORRUPTION_PER_CARD` points (define constant, suggested 1 per card)
- Cleansing a BlightHeart also awards a fixed bonus (suggested 5 points)
- Call `SaveManager.add_corruption_points(amount)` and verify `GameBus.corruption_points_changed` fires

Dawn-branch card identification: check `CardData.magic_branch == "dawn"` or equivalent field.

## Plan

## Changes Made

## Documentation Updates
