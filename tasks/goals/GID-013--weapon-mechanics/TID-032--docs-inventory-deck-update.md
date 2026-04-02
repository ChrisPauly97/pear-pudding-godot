# TID-032: Docs: inventory-and-deck.md update

**Goal:** GID-013
**Type:** agent
**Status:** pending
**Depends On:** TID-031

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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_This task is entirely a documentation update._
