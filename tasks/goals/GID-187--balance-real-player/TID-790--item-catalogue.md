# TID-790: Author the item catalogue

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-789

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Hand-author the items: every slot in every band, with at least two items per slot and band that differ in stat
focus (e.g. a tanky Stamina/Armor helm vs a Haste/Crit helm), plus the per-magic-type pieces (Mastery of that
school) from Superior. Roughly 8 slots × 5 bands × 2 ≈ 80 items, plus weapons per swing speed. Names and lore
fit the story (`docs/human/story.md`, read-only); icons reuse or extend the existing gear art.

## Research Notes

- Each `.tres` needs a `.uid` sidecar and a `const` preload in `WeaponRegistry` (Android packaging rule).
- Weapon swing speeds: dagger 1.8, wand 2.2, blade 2.6, staff 3.2, axe 3.6 (`WeaponData.swing_speed`).
- `test_gear_budget` (TID-789) validates every item.

## Plan

## Changes Made

## Documentation Updates
