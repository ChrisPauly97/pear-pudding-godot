# TID-538: Gear Rarity, Item Level & Quest Reward Choice

**Goal:** GID-136
**Type:** agent
**Status:** pending
**Depends On:** TID-533, TID-536

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Better gear as you explore: rarity tiers, item level scaled to enemy level, and a choose-one reward on quest turn-in.

## Research Notes

- Gear: `data/WeaponData.gd` (slot, battle_effect_type/value, injected_card_id/count), `autoloads/WeaponRegistry.gd`,
  slots `equipped_weapon/armor/ring/trinket` in SaveManager, `scenes/ui/CharacterScene.gd`,
  drops in `scenes/world/modules/ChestLoot.gd`. Card rarity already exists (GID-028) — reuse its colours.
- Item instances need per-drop stats (rarity, ilvl) — owned gear is currently id strings (`owned_weapons`); needs an
  instance dict + save migration. BID-033 notes session equipment gaps for co-op.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
