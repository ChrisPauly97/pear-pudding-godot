# TID-102: Card Combining (3× Same Rarity → 1× Next Rarity)

**Goal:** GID-028
**Type:** agent
**Status:** pending
**Depends On:** TID-100

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players who accumulate duplicates can fuse 3 copies of the same card at the same rarity tier into 1 copy of the next higher rarity. The resulting card gets a fresh stat roll from the higher rarity's range. This gives duplicates value beyond selling/scrapping and creates a progression ladder.

## Research Notes

**Combine rules**:
- Input: 3× instances with same `template_id` and same `rarity`
- Output: 1× new instance with same `template_id`, next rarity tier, stats rolled fresh from that tier's ranges
- Rarity ladder: common → rare → epic → legendary
- Legendary cards cannot be combined further (they are the ceiling)
- Unique cards (`is_unique = true`) cannot be combined
- Cards flagged `can_craft = false` can still be combined (combine ≠ craft; combining uses what you own)

**SaveManager helper**:
- `combine_cards(template_id: String, rarity: String) -> Dictionary` — removes 3 matching instances from `owned_cards`, calls `add_card_instance(template_id, next_rarity, ...)` with fresh rolled stats, returns the new instance dict. Returns `{}` if fewer than 3 matching instances exist.

**Stat roll for combined card**: use `CardDropUtil.roll_stats(template_id, next_rarity)` (from TID-099) — the combined card gets a random roll in the new tier's range, not guaranteed to be the maximum.

**UI in InventoryScene** (extends TID-100 row layout):
- Per template group in the collection, if 3+ copies of the same rarity exist: show a "Combine 3×" button on the row
- Button label: "Combine 3× → [R]" (or → [E], → [L] depending on source rarity)
- After combining, call `_refresh()`
- If combining would consume cards currently in `_working_deck`: block the combine (disable button) or remove them from the working deck first — decide in Plan phase

**Helper to check combineability**:
```gdscript
func _can_combine(template_id: String, rarity: String) -> bool:
    var count := 0
    for inst in SaveManager.get_owned_instances():
        if inst["template_id"] == template_id and inst["rarity"] == rarity:
            count += 1
    return count >= 3
```

**No new resource files** in this task.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
