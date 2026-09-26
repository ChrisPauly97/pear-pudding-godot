# TID-542: Consumables — Inventory Use & D3-Style Quick Slot

**Goal:** GID-136
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User: consumables are used from your inventory (not only via the one-per-battle picker), and the control scheme should make them easy "like D3 does" — an always-visible quick-use potion button with a cooldown.

## Research Notes

- Potions: `SaveManager.potions` {id: count}, crafting in `docs/agent/home-garden-potions.md`, in-battle picker in
  `scenes/battle/modules/BattleConsumables.gd`. Check which effects make sense out of battle (heal-over-time buff for
  next fight, XP/elixir buffs à la WoW) and add a Use button in the inventory UI.
- D3-style quick slot: 1–2 assignable consumable slots shown on both the world HUD and the battle UI (same position,
  count badge, radial cooldown sweep), one tap/key (e.g. Q / 1–2) to drink. Replaces the in-battle picker as the
  primary path (keep picker for choosing what's slotted). World HUD button via `_world_hud.register_action`
  (never bare `_hud.add_child`); battle button lives in `BattleConsumables.gd`. Mobile + keyboard parity.
- Revisit the "one potion per battle" rule → shared cooldown instead (decide in TID-540).
- Persist slot assignment + cooldown in SaveManager.PERSISTED_FIELDS.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
