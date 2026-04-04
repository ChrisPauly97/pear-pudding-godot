# TID-038: Docs: inventory-and-deck.md update

**Goal:** GID-014
**Type:** agent
**Status:** done
**Depends On:** TID-037

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Agent-owned docs must be kept current after each feature. This task updates `docs/agent/inventory-and-deck.md` to document the full weapon system: WeaponData schema, WeaponRegistry, SaveManager field, all effect types, and the auto-resolve draw mechanic.

## Research Notes

**File:** `docs/agent/inventory-and-deck.md`

Sections to add or extend:
1. **Weapon System** — new top-level section covering:
   - One weapon slot: `SaveManager.equipped_weapon: String` (weapon id or "" for none)
   - `WeaponData` resource fields (id, display_name, description, battle_effect_type, battle_effect_value, injected_card_id, injected_card_count)
   - `WeaponRegistry` autoload — scans `data/weapons/`, resolves by id
   - Effect types table: deck_inject / starting_mana / starting_hp / passive_atk
   - Mana invariant: max_mana cap stays at 10; starting_mana is turn-1 burst only
2. **Auto-Resolve Cards** — sub-section or addition to the card types section:
   - `CardData.auto_resolve: bool` — when true, card fires on draw and is discarded (never enters hand)
   - `spell_effect = "deal_damage_random"` — fires at a random enemy minion, or hero face if board empty
   - Used by weapon-injected cards (dagger_throw etc.)

Preserve all existing sections; only add new content. Follow the existing doc style (Key Features, How It Works, Integrations).

## Plan

Add two new sections to `docs/agent/inventory-and-deck.md`: **Weapon System** (WeaponData schema, WeaponRegistry, SaveManager field, effect types table, mana invariant) and **Auto-Resolve Cards** (auto_resolve field, pending_auto_spells mechanic, dagger_throw). Update Integrations table and Asset Requirements table to include weapon-related entries.

## Changes Made

- `docs/agent/inventory-and-deck.md`: Added "Weapon System" and "Auto-Resolve Cards" sections; updated Integrations and Asset Requirements tables.

## Documentation Updates

This task is entirely a documentation update — see Changes Made above.
