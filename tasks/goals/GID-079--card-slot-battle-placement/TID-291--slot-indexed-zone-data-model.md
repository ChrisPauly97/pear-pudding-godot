# TID-291: Slot-indexed zone data model

**Goal:** GID-079
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

ZoneState already holds `slots: Array[CardInstance]` of exactly 5 elements with `null` for empty. But `add_card()` auto-picks the first empty slot and there is no way for the caller to specify an index. This task adds the targeted-placement API and the per-slot enhancement storage that later tasks build on.

## Research Notes

**Files to edit:**
- `game_logic/battle/ZoneState.gd` — primary target
- `game_logic/battle/PlayerState.gd` — add `play_card_at_slot(card, idx)`

**ZoneState current API:**
- `add_card(card)` → finds `first_empty_slot()`, places card there
- `to_dict()` / `from_dict()` — serialise slots array; need extension for enhancements
- `SLOT_COUNT = 5`

**New fields:**
```gdscript
var slot_enhancements: Array[Dictionary] = []  # length SLOT_COUNT; {} means no enhancement
# Enhancement dict keys: "type" (String), "value" (int)
# Valid types: "atk_bonus", "shroud"  (extendable later)
```

**New methods on ZoneState:**
```gdscript
func add_card_at_slot(card: CardInstance, idx: int) -> bool:
    # Returns false if idx out of range or slot occupied
    if idx < 0 or idx >= SLOT_COUNT or slots[idx] != null:
        return false
    slots[idx] = card
    return true

func enhance_slot(idx: int, enhancement_type: String, value: int) -> void:
    if idx < 0 or idx >= SLOT_COUNT:
        return
    slot_enhancements[idx] = {"type": enhancement_type, "value": value}

func consume_slot_enhancement(idx: int) -> Dictionary:
    # Returns and clears the enhancement at idx (empty dict if none)
    if idx < 0 or idx >= SLOT_COUNT:
        return {}
    var enh: Dictionary = slot_enhancements[idx].duplicate()
    slot_enhancements[idx] = {}
    return enh

func get_slot_enhancement(idx: int) -> Dictionary:
    if idx < 0 or idx >= SLOT_COUNT:
        return {}
    return slot_enhancements[idx]
```

**Serialisation** — extend `to_dict()` to return a Dictionary (not just Array) so enhancements are included alongside slots. Or add a parallel `enhancements_to_dict()` array. Simpler: change `to_dict()` to return `{"slots": [...], "enhancements": [...]}` and update `from_dict()` accordingly. Check that `GameState.to_dict/from_dict` and `PlayerState.to_dict/from_dict` pass through the zone correctly — both call `board.to_dict()` / `board.from_dict()`.

**PlayerState.play_card_at_slot:**
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
    return true
```

`play_card()` (auto-slot) stays unchanged — BasicAI and puzzle mode continue to use it.

**Serialisation migration:** ZoneState's `to_dict()` currently returns a plain `Array`. Changing it to return a `Dictionary` will break `PlayerState.to_dict/from_dict` (which stores `"board": board.to_dict()`). Preferred approach: keep `to_dict()` returning the same Array for slots, and add a second method `enhancements_to_dict() -> Array` that `PlayerState` calls separately. This avoids any serialisation format change.

```gdscript
# In PlayerState.to_dict():
"board": board.to_dict(),          # slots Array — unchanged
"board_enhancements": board.enhancements_to_dict(),  # NEW parallel array

# In PlayerState.from_dict():
board.from_dict(d["board"])
if d.has("board_enhancements"):
    board.enhancements_from_dict(d["board_enhancements"])
```

This is fully backward-compatible (old saves that lack `board_enhancements` just get empty enhancements on load).

## Plan

1. Add `slot_enhancements: Array[Dictionary]` to `ZoneState._init()` (length SLOT_COUNT, all `{}`).
2. Add `add_card_at_slot(card, idx)`, `enhance_slot(idx, type, value)`, `consume_slot_enhancement(idx)`, `get_slot_enhancement(idx)`, `enhancements_to_dict()`, `enhancements_from_dict(arr)` to `ZoneState`.
3. Add `play_card_at_slot(card, slot_idx)` and `_apply_enhancement_to_card(card, enh)` to `PlayerState`. Update `play_card()` to also call `consume_slot_enhancement` + `_apply_enhancement_to_card` after auto-slot placement.
4. Extend `PlayerState.to_dict()` with `"board_enhancements": board.enhancements_to_dict()` and `from_dict()` to call `board.enhancements_from_dict()` when key present (backward-compatible).
5. Add unit tests covering all new ZoneState and PlayerState APIs.

## Changes Made

- **`game_logic/battle/ZoneState.gd`**: Added `slot_enhancements: Array[Dictionary]` field; initialised in `_init()`. Added `add_card_at_slot`, `enhance_slot`, `consume_slot_enhancement`, `get_slot_enhancement`, `enhancements_to_dict`, `enhancements_from_dict`.
- **`game_logic/battle/PlayerState.gd`**: Added `play_card_at_slot(card, slot_idx)` and `_apply_enhancement_to_card(card, enh)`. Updated `play_card()` to apply/consume slot enhancement after `board.add_card()`. Updated `to_dict()` and `from_dict()` for `board_enhancements`.
- **`tests/unit/test_zone_state.gd`**: Added `add_card_at_slot`, `enhance_slot`, `consume_slot_enhancement`, `get_slot_enhancement`, `enhancements_to_dict`, `enhancements_from_dict` test sections.
- **`tests/unit/test_player_state.gd`**: Added `play_card_at_slot` and enhancement round-trip test sections.

## Documentation Updates

Updated `docs/agent/battle-system.md` with slot enhancement types, new spell effects, and slot UI system details.
