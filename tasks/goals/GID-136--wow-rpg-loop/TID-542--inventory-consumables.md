# TID-542: Use Consumables From the Inventory

**Goal:** GID-136
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User: consumables are used from your inventory (not only via the one-per-battle picker).

## Research Notes

- Potions: `SaveManager.potions` {id: count}, crafting in `docs/agent/home-garden-potions.md`, in-battle picker in
  `scenes/battle/modules/BattleConsumables.gd`. Check which effects make sense out of battle (heal-over-time buff for
  next fight, XP/elixir buffs à la WoW) and add a Use button in the inventory UI. Keep in-battle use.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
