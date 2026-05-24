# TID-097: Rarity Data Model — Extend CardData with Per-Rarity Stat Ranges

**Goal:** GID-028
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Cards currently have flat stats (single `attack`, `health`, `cost` integers). This task adds rarity-tier fields to `CardData` and a new `RarityStats` sub-resource so each card can define stat ranges for common, rare, epic, and legendary tiers. It also adds `can_craft: bool` and `is_unique: bool` flags. This is a pure data-layer change; nothing in the save or UI changes yet — that follows in TID-098+.

## Research Notes

**CardData** (`data/CardData.gd`): currently has `id, card_name, cost, attack, health, card_class, description, color, magic_type, magic_branch, spell_effect, spell_power, auto_resolve, keywords`. The `attack`, `health`, `cost` fields become the baseline defaults (used if no rarity range is defined).

**CardRegistry** (`autoloads/CardRegistry.gd`): scans `data/cards/*.tres`, builds `_cards: Dictionary`. `get_template()` returns a flat dict. No changes to CardRegistry needed in this task — TID-098 will extend it.

**Rarity tiers**: common, rare, epic, legendary. "Unique" is not a separate rarity tier — it is a flag that means only one copy of this card can ever exist in the collection (`is_unique = true`). Unique cards will typically also be legendary.

**Legendary-only design**: legendary cards have no common/rare/epic stat ranges — only the legendary range applies. The `common_stats`, `rare_stats`, `epic_stats` fields will be `null` for such cards.

**`can_craft: bool`**: false for unique cards and any card the designer wants to exclude from recipes. Defaults `true` for normal cards.

**RarityStats sub-resource**: a small `Resource` subclass with:
- `attack_min: int`, `attack_max: int`
- `health_min: int`, `health_max: int`
- `cost_min: int`, `cost_max: int`

When both min and max are 0 (or the field is null), callers fall back to the base stat on CardData. This lets cards that don't need a range for a given tier leave those fields unset.

**Files to create/edit**:
- `data/RarityStats.gd` — new Resource subclass (needs `.uid` sidecar)
- `data/CardData.gd` — add `@export var common_stats: RarityStats`, `rare_stats`, `epic_stats`, `legendary_stats`, `can_craft: bool = true`, `is_unique: bool = false`
- Update `.tres` files for any cards that need ranges: at minimum define ranges for the 4 base minions (ghost, skeleton, zombie, ghoul) at common/rare/epic; define legendary ranges for the 5 existing legendary cards (`ancient_guardian`, `void_wyrm`, `iron_revenant`, `phoenix_rise`, `time_warp`)

**Suggested stat ranges (starting point, tune as desired)**:

| Rarity | Attack range | Health range | Cost range |
|--------|-------------|--------------|------------|
| Common | base±1 | base±1 | base (no range) |
| Rare | base+1 to base+3 | base+1 to base+3 | base (no range) |
| Epic | base+3 to base+5 | base+3 to base+5 | base (no range) |
| Legendary | unique-specific | unique-specific | base (no range) |

For non-minion cards (spells), apply ranges to `spell_power` instead — but to keep scope tight this task can leave spells with no ranges for now (they'll just always roll base stats).

**UID sidecar rule** (CLAUDE.md): `data/RarityStats.gd` needs a `.uid` sidecar at `data/RarityStats.gd.uid` with a random 12-char UID string.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
