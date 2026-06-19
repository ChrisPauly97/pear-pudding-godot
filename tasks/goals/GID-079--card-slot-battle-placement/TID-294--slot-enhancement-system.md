# TID-294: Slot enhancement system

**Goal:** GID-079
**Type:** agent
**Status:** pending
**Depends On:** TID-291

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With named, indexed slots in place (TID-291) and visual slot panels (TID-292), slots can carry persistent state between turns. This task adds the enhancement data model, two new spell cards that apply enhancements, and the visual indicator for enhanced slots. It establishes the pattern for future position-aware mechanics (leftmost attacker bonus, neighbour synergies, etc.).

## Research Notes

**Files to edit:**
- `game_logic/battle/ZoneState.gd` — enhancement API (added in TID-291; consumed here)
- `scenes/battle/BattleScene.gd` — `_resolve_spell_effect`, `_apply_card_style` / slot panel styling, new `bless_slot` targeting mode
- `data/cards/` — 2 new `.tres` CardData resources
- `autoloads/CardRegistry.gd` — add preload const for each new card
- `docs/agent/battle-system.md` — document new spell effects and enhancement types

**Enhancement types (v1):**
| type | effect |
|---|---|
| `"atk_bonus"` | Minion placed in this slot gains +`value` ATK immediately on play |
| `"shroud"` | Minion placed in this slot gets the Shroud keyword (absorbs first hit) |

Future types (not in this task): `"on_death_heal"`, `"extra_attacks"`, etc.

**New spell effect keys added to `_resolve_spell_effect`:**
```
"bless_slot"   — apply atk_bonus enhancement to target slot; spell_power = ATK bonus value
"ward_slot"    — apply shroud enhancement to target slot; spell_power ignored (always shroud)
```

Both are friendly-targeted (target a slot on the player's own board). They use a new targeting mode: slot targeting (different from the existing minion/hero targeting).

**New card data resources:**

`data/cards/arcane_seal.tres` — `CardData`:
```
id = "arcane_seal"
display_name = "Arcane Seal"
card_class = "spell"
magic_type = "light"
magic_branch = "dawn"
cost = 2
spell_effect = "bless_slot"
spell_power = 2
description = "Bless a board slot. The next minion placed there gains +2 ATK."
```

`data/cards/shadow_ward.tres` — `CardData`:
```
id = "shadow_ward"
display_name = "Shadow Ward"
card_class = "spell"
magic_type = "dark"
magic_branch = "dusk"
cost = 1
spell_effect = "ward_slot"
spell_power = 1
description = "Ward a board slot. The next minion placed there gains Shroud."
```

**Resolving bless_slot / ward_slot:** These spells need the player to pick a target *slot* (not a card). A slot that already has an enhancement or already has a minion is not a valid target.

New targeting mode: `_SLOT_TARGETED_EFFECTS: Array[String] = ["bless_slot", "ward_slot"]`

Flow when player plays `bless_slot`:
1. Drag spell to board → detect `bless_slot` in `_SLOT_TARGETED_EFFECTS` → enter slot-targeting mode
2. All 5 player slot panels are highlighted (both empty and occupied, since you can pre-bless an occupied slot to bless the next occupant after this one dies — actually, simpler: only empty slots are valid targets for pre-placement blessings)
3. Player taps a slot → `_resolve_slot_spell(card, slot_idx)` is called
4. `_state.players[0].board.enhance_slot(slot_idx, "atk_bonus", card.spell_power)` is called
5. `_refresh_all()` shows the enhanced slot's coloured border

**Applying enhancement on placement (in `PlayerState.play_card_at_slot`):**
```gdscript
func play_card_at_slot(card: CardInstance, slot_idx: int) -> bool:
    if not can_play(card):
        return false
    if not board.add_card_at_slot(card, slot_idx):
        return false
    hand.erase(card)
    hero.spend_mana(card.cost)
    card.summoning_sick = true
    if card.keywords.has(Keywords.SURGE):
        card.summoning_sick = false
    # Apply and consume any slot enhancement
    var enh: Dictionary = board.consume_slot_enhancement(slot_idx)
    _apply_enhancement_to_card(card, enh)
    return true

func _apply_enhancement_to_card(card: CardInstance, enh: Dictionary) -> void:
    match enh.get("type", ""):
        "atk_bonus":
            card.attack += int(enh.get("value", 0))
        "shroud":
            card.shroud_active = true  # CardInstance already has this field
```

Note: `_apply_enhancement_to_card` is a method on `PlayerState`, not a static function — it only modifies a `CardInstance`.

**Visual — enhanced slot border:**
In `_refresh_zone`, when rendering a slot (empty or occupied), check `zone_state.get_slot_enhancement(i)`:
- `"atk_bonus"` → orange border `Color(1.0, 0.65, 0.1)`
- `"shroud"` → pale blue border `Color(0.6, 0.6, 1.0)`
For occupied slots: modify `_apply_card_style` to accept an optional `enhancement: Dictionary` param and overlay the border color.

**CardRegistry preloads** (add to `autoloads/CardRegistry.gd`):
```gdscript
const _C_ARCANE_SEAL := preload("res://data/cards/arcane_seal.tres")
const _C_SHADOW_WARD := preload("res://data/cards/shadow_ward.tres")
```

**UID files** needed (per CLAUDE.md):
- `data/cards/arcane_seal.tres.uid`
- `data/cards/shadow_ward.tres.uid`

**Drop pools / shops:** These cards should be discoverable. Add `arcane_seal` to `dawn_clarity` or `undead_basic` enemy drop pools (or a new pool). ShopScene lists all cards from CardRegistry, so they will appear automatically.

**`_SPELL_EFFECT_LABELS` additions (BattleScene + CardInspectOverlay — keep in sync):**
```gdscript
"bless_slot": "Bless a board slot — the next minion placed there gains +[power] ATK",
"ward_slot":  "Ward a board slot — the next minion placed there gains Shroud",
```

**Slot-targeting UI (new targeting mode):**
```gdscript
var _slot_targeting_spell: CardInstance = null

const _SLOT_TARGETED_EFFECTS: Array[String] = ["bless_slot", "ward_slot"]

func _enter_slot_targeting_mode(spell: CardInstance) -> void:
    _slot_targeting_spell = spell
    _targeting_active = true
    # Highlight empty player slot panels
    for child in _player_board_view.get_children():
        if bool(child.get_meta("is_empty_slot", false)):
            # apply cyan/teal highlight style
            pass
    _show_cancel_btn("✕ Cancel", _exit_slot_targeting_mode)
    # Wire gui_input on each empty slot to _on_slot_target_input
    ...

func _exit_slot_targeting_mode() -> void:
    _slot_targeting_spell = null
    _targeting_active = false
    _hide_cancel_btn()
    _refresh_all()

func _resolve_slot_spell(spell: CardInstance, slot_idx: int) -> void:
    match spell.spell_effect:
        "bless_slot":
            _state.players[0].board.enhance_slot(slot_idx, "atk_bonus", spell.spell_power)
        "ward_slot":
            _state.players[0].board.enhance_slot(slot_idx, "shroud", 1)
    _exit_slot_targeting_mode()
    _refresh_all()
    _check_game_over()
```

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
