# TID-291: Slot-indexed zone data model

**Goal:** GID-079
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
