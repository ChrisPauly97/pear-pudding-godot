# TID-076: Add Weapons to ShopScene

**Goal:** GID-022
**Type:** agent
**Status:** done
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

Add a "— Weapons —" section to ShopScene below the cards list. Compute price dynamically from effect type/value (no new WeaponData field needed). Filter to unowned weapons only, hide rusty_dagger. Grey price label when unaffordable. `_on_buy_weapon` deducts coins and calls `SaveManager.add_weapon()`.

## Changes Made

- `scenes/ui/ShopScene.gd` — added WeaponRegistry/WeaponData preloads; split `_make_row` into `_make_card_row` and `_make_weapon_row`; `_refresh()` now emits section headers and a weapons list filtered to unowned (excl. rusty_dagger); `_weapon_price()` computes 40–80 coin prices; `_on_buy_weapon()` handles purchase

## Documentation Updates

None required.
