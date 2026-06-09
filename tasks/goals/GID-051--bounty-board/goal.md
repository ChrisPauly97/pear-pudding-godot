# GID-051: Bounty Board Contracts

## Objective

A town bounty board offering three seeded daily contracts — defeat-N-enemies, open-chests, and similar — paying coins on completion, with live progress tracking in the HUD.

## Context

Coins come from wandering and fighting whatever appears. Daily bounties give directed, repeatable income and another reason to revisit towns. Progress hooks listen to GameBus signals that already exist (`battle_won`, `coins_changed`) — no new coupling into gameplay systems. Bounties integrate into the day/night cycle via `SaveManager.days_elapsed`, which increments on each `time_of_day` wrap in `WorldScene._process()`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-188 | Bounty model + seeded daily generation + save fields | agent | pending | — |
| TID-189 | Bounty board entity in towns + accept/track/claim UI | agent | pending | TID-188 |
| TID-190 | Progress tracking via existing GameBus signals + HUD tracker + coin payout | agent | pending | TID-188 |

## Acceptance Criteria

- [ ] Three bounties generate per in-game day, seeded from world seed + day index so they're stable within a day and rotate the next day; offered/accepted/progress state persists in SaveManager with migration
- [ ] Bounty types in v1: defeat N enemies of type X (N 2–4, types from EnemyRegistry), defeat N enemies in biome Y, open N chests; coin rewards scale with difficulty (~40–120 coins)
- [ ] A bounty board entity in each town opens a board UI listing the day's bounties with accept buttons (max 3 active); completed bounties show a Claim button that pays out once
- [ ] Progress increments via existing GameBus signals only; an accepted bounty shows as a small HUD tracker line (e.g. "Ghoul packs 1/3") that updates live
- [ ] Fully touch-operable, viewport-relative sizing (mobile parity per CLAUDE.md)
- [ ] All tests pass headless
