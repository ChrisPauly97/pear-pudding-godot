# TID-563: Art Pass — Helmets, Boots Slot, Directional Frames

**Goal:** GID-137
**Type:** agent
**Status:** pending
**Depends On:** TID-560

## Context

TID-560 ships one facing (right, mirrored by `flip_h`) and draws only the
existing slots. Head/feet gear would need new equipment slots.

## Research Notes

- Row 0 of the 16×28 frame is free for helmets; boots are drawn by
  `_draw_legs` and could take a gear palette.
- New slots need `SaveManager` fields, `WeaponData.slot` values, CharacterScene
  slot buttons, and `PaperDoll.VISIBLE_SLOTS`.
- Optional: up/down facing frames (camera is fixed iso, so back view when
  walking "north") and an attack/cast pose for the battle token.
