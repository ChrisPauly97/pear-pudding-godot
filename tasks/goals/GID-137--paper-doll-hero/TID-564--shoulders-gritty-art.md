# TID-564: Shoulders Slot & Gritty Art Pass

**Goal:** GID-137
**Type:** agent
**Status:** done
**Depends On:** TID-560

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User asked for shoulder gear and a less cartoon, grittier hero.

## Plan

1. New `shoulders` equipment slot end to end: SaveManager fields
   (`PERSISTED_FIELDS` defaults cover old saves), `equip_item`/`add_equipment`/
   getters (table-driven `_OWNED_BY_SLOT` to stay under gdlint max-returns),
   CharacterScene slot, Shop section, chest loot, battle effects + arena gear list.
2. Three items: leather pauldrons (+4 HP), iron pauldrons (+8 HP), spiked
   spaulders (+1 attack). Avoided `starting_armor`, which overwrites rather than stacks.
3. Art: smaller head, muted palette, three-tone shading, grime dither, stubble/brow.

## Changes Made

- `SaveManager`, `CharacterScene`, `ShopScene`, `ChestLoot`, `BattleModifiers`,
  `BattleArena`, `WeaponData` doc, `WeaponRegistry` (+3 preloads).
- `data/weapons/{leather_pauldrons,iron_pauldrons,spiked_spaulders}.tres` (+ uid).
- PaperDoll palette/shading rewrite; `_draw_shoulders` (pauldron / plate / spiked).
- Session records (co-op) still carry only weapon/armor — shoulders, like
  ring/trinket/offhand, are not session-synced (see TID-561).

## Documentation Updates

- `camera-and-player.md` Paper-doll section, `inventory-and-deck.md` slots.
