# BID-062: Minion Card Placement Bypasses the Real-Time GCD/Spell Queue

**Category:** design-inconsistency
**Discovered During:** TID-555 (GID-135)

## Description

`BattleRealtime.run_cast()` is the shared path that gates a real-time play on the GCD and (since TID-555)
queues an instant play inside the spell-queue window instead of letting it fire early. It only covers
spells and skill-bar abilities. Placing a minion (non-spell card) — via tap-to-slot-select or drag-drop —
never goes through `run_cast` at all: `BattleTargeting._do_play_card_at_slot()` /
`BattleInput._on_empty_slot_input()` call `PlayerState.play_card_at_slot()` directly and start the GCD
afterward with `note_player_play()`. In practice this is hard to exploit today (the tap/drop entry points
are already gated by `_can_local_act()` before the player can even begin placing a card), but it means a
minion play has no analog to the instant-spell queue fix TID-555 just made, and if that entry gating ever
changes, the same early-fire bug would resurface for minions with no queue to catch it.

## Evidence

- `scenes/battle/modules/BattleTargeting.gd` `_do_play_card_at_slot()`, `_board_drop()`
- `scenes/battle/modules/BattleInput.gd` `_on_empty_slot_input()`
- `scenes/battle/modules/BattleRealtime.gd` `run_cast()` (spells/skill-bar only)

## Suggested Resolution

When TID-530 (Input Flow — Spell Queue & One-Tap Targeting) or TID-545 (Hero Kit / Ally slots) next touches
minion placement in real time, route it through `run_cast()` (or an equivalent instant-queue path) the same
way TID-555 did for instant spells and skill-bar abilities, so every real-time play shares one GCD/queue
mechanism.
