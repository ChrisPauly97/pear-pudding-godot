# TID-563: Art Pass — Helmets & Boots Slots

(Shoulders shipped in TID-564; the frame is now 32×28 with a centred 16-px body column.
Directional frames were split out to TID-618.)

**Goal:** GID-137
**Type:** agent
**Status:** done
**Depends On:** TID-560

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-560 ships one facing (right, mirrored by `flip_h`) and draws only the
existing slots. Head/feet gear needed new equipment slots.

## Research Notes

- Row 0 of the frame is free for helmets; boots are drawn by `_draw_legs` and
  can take a gear palette.
- New slots need `SaveManager` fields, `WeaponData.slot` values, CharacterScene
  slot buttons, and `PaperDoll.VISIBLE_SLOTS` (template: TID-564's shoulders).
- `HeroState.add_armor` now stacks, so `starting_armor` items are safe (TID-564
  avoided it when it overwrote).

## Plan

1. `helmet` and `boots` slots end to end, mirroring shoulders: `PERSISTED_FIELDS`
   (defaults cover old saves, no migration), `_OWNED_BY_SLOT`, `add_equipment` /
   `equip_item`, CharacterScene, Shop, chest loot, battle effects, arena gear list.
2. Six items: leather cap (+3 HP), iron helm (+2 armor), hooded cowl (+1 mana);
   travel boots (+3 HP), iron greaves (+2 armor), spurred boots (+1 attack).
3. Art: `_draw_helmet` (cap / helm / cowl) after the head; boot gear recolours
   the boots and `_draw_boot_gear` adds shaft / shin plates / spurs per leg.
   Colours picked from `PixelPalette` so quantize keeps them readable.
4. `VISIBLE_SLOTS` appends the two slots (positional co-op payload stays
   backward compatible).
5. CharacterScene: eight slots overflow one landscape column → 2-column grid.

## Changes Made

- `SaveManager`, `WeaponData` doc, `WeaponRegistry` (+6 preloads), `ChestLoot`,
  `BattleModifiers`, `BattleArena`, `ShopScene` (Helmets / Boots sections),
  `CharacterScene` (slot grid, ellipsis on long names).
- `data/weapons/{leather_cap,iron_helm,hooded_cowl,travel_boots,iron_greaves,spurred_boots}.tres` (+ uid).
- `PaperDoll.gd` (slots, visuals, `_draw_legs` boot gear), `PaperDollGear.gd`
  (`_draw_helmet`, `_draw_boot_gear`).
- Tests: `test_paper_doll` (helmet only touches head rows, boots only leg rows;
  payload round-trip covers new slots), new `test_head_feet_equipment`.

## Documentation Updates

- `camera-and-player.md` (styles, draw order), `inventory-and-deck.md` (slots),
  `multiplayer-coop.md` (gear payload order).
