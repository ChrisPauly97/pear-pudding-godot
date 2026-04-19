# TID-076: Add Weapons to ShopScene

**Goal:** GID-022
**Type:** agent
**Status:** pending
**Depends On:** TID-073

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

ShopScene currently only lists cards. Adding weapons to the shop gives players another avenue to acquire them and makes coins more meaningful.

## Research Notes

- `scenes/ui/ShopScene.gd` — find how shop items are listed; add a weapons section below or alongside the card section
- Pricing: weapons should cost more than cards (cards are 15 coins; weapons suggested 40–80 coins depending on power)
- Only show weapons the player does NOT already own (filter against SaveManager.owned_weapons)
- Do not show starter_dagger in the shop (player starts with it)
- On purchase: add to SaveManager.owned_weapons, deduct coins, mark dirty; show confirmation
- If the player can't afford a weapon, grey it out with the coin cost shown in red
- Consider a separate "Weapons" tab or section header in the shop rather than mixing weapons and cards in one list
- Follow CLAUDE.md UI sizing and mobile parity rules

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
