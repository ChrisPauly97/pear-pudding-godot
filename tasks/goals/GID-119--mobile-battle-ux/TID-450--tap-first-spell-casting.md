# TID-450: Tap-First Spell Casting

**Goal:** GID-119
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Minions are tap-playable (TID-293 slot-select) and slot-spells tap into slot-targeting,
but every other spell requires a drag onto the board (`_board_drop`): tapping a
targeted or untargeted spell in hand falls through to the inspect overlay
(`_on_hand_card_tap`). Drag is the least reliable gesture on a small screen, and there
is no tap path at all for enemy-targeted, friendly-targeted, ally-targeted, or plain
untargeted spells.

## Research Notes

- `_board_drop` is the canonical routing: slot-targeted → `_enter_slot_targeting_mode`;
  ally-targeted (`_coop_pve`) → `_enter_ally_targeting_mode`; enemy/friendly-targeted →
  `_enter_targeting_mode(card, friendly)` with empty-board guards (friendly needs own
  minions; enemy-targeted except `deal_damage_single` needs enemy minions);
  untargeted → `_do_play_card` + `resolve_spell` (PvP client: `_send_intent`).
- Targeting-mode taps already resolve through `_on_target_chosen_card/_hero`, which
  handle PvP intents — reusing `_enter_targeting_mode` from a tap gets the full
  network path for free.
- Untargeted spells resolve instantly, so a bare tap needs a confirm step to avoid
  accidental casts (fat-finger while scrolling the fan).

## Plan

1. `_on_hand_card_tap`: mirror `_board_drop` routing for playable spells —
   ally-targeted → ally targeting; enemy/friendly-targeted (guards permitting) →
   `_enter_targeting_mode`; untargeted → new `_show_cast_confirm(card)`; anything
   unplayable keeps falling through to inspect.
2. `_show_cast_confirm`: centered panel (name, ability text, Cast + Cancel buttons,
   dimmed backdrop) → on Cast, run the exact `_board_drop` untargeted branch
   (PvP-client intent path included).
3. Enlarge `_show_cancel_btn` to `vh*0.20 × vh*0.07`, font 3% vh.

## Changes Made

- `BattleScene._on_hand_card_tap`: spell routing added (ally/enemy/friendly/untargeted);
  unplayable cards and empty-target situations still open inspect.
- New `BattleScene._show_cast_confirm(card)` + `_cast_confirmed_spell(card)` — confirm
  overlay and the shared untargeted-cast path (also now used by `_board_drop`).
- `_show_cancel_btn` enlarged.

## Documentation Updates

- `docs/agent/battle-system.md`: tap-first casting documented in the GID-119 section.
