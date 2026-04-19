# TID-084: Legendary Card Unlock Progression

**Goal:** GID-024
**Type:** agent
**Status:** pending
**Depends On:** TID-082

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Standard cards (all existing + GID-018 Dawn/Dusk cards) remain always available in shop and drops. This task adds a small set of Legendary cards (5–8) that are exclusively unlocked via specific achievement milestones — they never appear in shop or drops until unlocked.

## Research Notes

- Add `card_class: "legendary"` to the CardData resource (field may already exist as a string; check existing cards — current values are likely "minion" and "spell")
- Create 5–8 Legendary card .tres files in `data/cards/` with distinct, powerful effects and `card_class = "legendary"`; each needs a `.uid` sidecar
- Legendary card ideas (powerful, unique mechanics):
  - `ancient_guardian` — 6 cost, 5/8 minion, taunt (all enemy attacks redirect to it)
  - `soul_harvest` — 5 cost spell, destroy all minions on both sides, draw 3 cards
  - `time_warp` — 4 cost spell, player gets an extra turn (take two turns in a row)
  - `phoenix` — 5 cost minion, 4/4, when it dies it resurrects with 2/2
  - `void_wyrm` — 7 cost, 6/6 minion, deals 2 damage to ALL entities on play
- `autoloads/SaveManager.gd` — `unlocked_achievements` already tracks which achievements are done; derive unlocked legendary cards from achievements that have a `reward_card_id`
- Shop and drops: filter out legendary cards whose unlock achievement is NOT in `SaveManager.unlocked_achievements`; standard cards always pass through this filter unchanged
- When an achievement with a `reward_card_id` is unlocked: add the card to `SaveManager.owned_cards` automatically (the achievement reward IS the card) — don't require the player to buy it
- Update CardRegistry (or ShopScene) to check the legendary unlock gate

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
