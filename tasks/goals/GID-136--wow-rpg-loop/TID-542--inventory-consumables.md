# TID-542: Consumables — Inventory Use & D3-Style Quick Slot

**Goal:** GID-136
**Type:** agent
**Status:** done
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

1. Pure `game_logic/battle/QuickSlots.gd`: 2 slots, shared cooldown (3 of your
   own turns, or `potion_cooldown` seconds in real time), `resolve` (auto-fill
   from owned potions) and `assign`.
2. `SaveManager.quick_slots` persisted; Items tab assigns potions to Q / E.
3. Battle: two quick-slot buttons replace the Potion button + picker; keys Q / E
   (1–3 are the real-time skill bar).
4. **World use moves to TID-543:** none of today's potions do anything outside a
   fight until hero HP persists; TID-543 adds the world-HUD quick slot with food
   and out-of-combat healing.

## Changes Made

- New `game_logic/battle/QuickSlots.gd` (+ uid); `CombatTuning` `potion_cooldown` knob.
- `SaveManager.quick_slots`; `BattleConsumables` (quick slots, keys, cooldown; picker
  removed); `BattleScene` (dropped `_potion_btn` / `_used_potion_this_battle`, turn
  changes refresh the slots); `BattleRealtime._process` ticks the cooldown;
  `ItemsPanel` Q / E assignment.
- Tests: new `test_quick_slots.gd`.

## Documentation Updates

- `home-garden-potions.md` (quick slots section), `combat-model.md` (current-state table).
