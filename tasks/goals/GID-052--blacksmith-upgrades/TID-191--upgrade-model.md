# TID-191: Weapon Upgrade Levels, Data Model & Cost Curve

**Goal:** GID-052
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Owned weapons are currently flat strings (weapon IDs) in `SaveManager.owned_weapons` (line 58). This task converts them to instance dictionaries with upgrade level tracking, defines stat scaling, and establishes the cost curve. All upgrading logic flows through a new helper module `UpgradeDefs.gd`.

## Research Notes

- **Owned weapons storage:** Currently `SaveManager.owned_weapons: Array[String]` (lines 58, 159, 386). Must convert to `Array[Dictionary]` with shape `{weapon_id: String, upgrade_level: int}` per instance (like `owned_cards` instances, v10+).
  - On load, each owned weapon inherits level 0 via migration `_migrate_v14_to_v15` (new version 15).
  - The migration iterates old owned weapons and wraps each ID: `{weapon_id: id, upgrade_level: 0}`.
  - `player_deck` is never affected (stays strings).

- **Weapon stats — what scales:** `WeaponData` (lines 1–16 in **data/WeaponData.gd**) has:
  - `battle_effect_type: String` — one of `"deck_inject"`, `"starting_mana"`, `"starting_hp"`, `"passive_atk"`
  - `battle_effect_value: int` — numeric bonus for mana/hp/atk (unused for deck_inject)
  - `injected_card_count: int` — for deck_inject, number of cards injected
  - **Which scale on upgrade?** Only numeric bonuses scale: `battle_effect_value` for mana/hp/atk, and optionally `injected_card_count` for deck_inject (expand arsenal).

- **Stat scaling formula:** Each upgrade level multiplies the **base** effect:
  - `effective_value(base, level) := base * (1.0 + 0.10 * level)` — 10% per level, so level 5 = 1.5× base.
  - `deck_inject` cards (if scaling): `effective_count(base_count, level) := base_count + level` (one extra card per upgrade, capped at reason).
  - Store in **game_logic/UpgradeDefs.gd** as a static helper `effective_stat(weapon_id: String, level: int) -> int` that returns the scaled value.

- **Cost curve:** `game_logic/UpgradeDefs.gd` defines:
  ```gdscript
  const UPGRADE_COST_COINS: Array[int] = [100, 200, 300, 400, 500]  # level 1→5
  const UPGRADE_COST_ESSENCE: Array[int] = [5, 10, 15, 20, 25]      # level 1→5
  ```
  Level 0→1 costs `UPGRADE_COST_COINS[0]` + `UPGRADE_COST_ESSENCE[0]`, etc. Verify against actual coin earn rates from GID-007 (`add_coins` calls in SceneManager on battle/chest); essence earn from GID-028 (line 562: `scrap_essence` per rarity in `IsoConst.RARITY_CONFIG`). Adjust curve so mid-game player (say 10–20 battles) can afford 1–2 upgrades per weapon type, and essence is the bottleneck (slower to farm than coins).

- **SaveManager fields — new version 15:**
  - Rename `owned_weapons: Array[String]` → `owned_weapons: Array[Dictionary]` with the shape above.
  - Rename `equipped_weapon: String` → `equipped_weapon: String` (stays string, just the ID; upgrade level resolved at use time by looking up the owned instance).
  - Add a helper `get_owned_weapon_by_id(weapon_id: String) -> Dictionary` that returns the instance with upgrade_level, or a default `{weapon_id: weapon_id, upgrade_level: 0}` if not found (defensive).

- **Battle application:** In **scenes/battle/BattleScene.gd** line 181, when resolving an equipped weapon:
  ```gdscript
  var weapon_inst: Dictionary = sm.get_owned_weapon_by_id(item_id)
  var level: int = int(weapon_inst.get("upgrade_level", 0))
  var scaled_value: int = UpgradeDefs.effective_stat(item_id, level)
  # Apply scaled_value instead of weapon.battle_effect_value
  ```
  Cite exact lines where `weapon.battle_effect_value` is used (lines 193–199 in BattleScene) and plan the patch.

- **GameBus signals:** Add `weapon_upgraded(weapon_id: String, new_level: int)` to **autoloads/GameBus.gd**. Emit from upgrade success path in the blacksmith (TID-192).

- **Headless tests:** New file **tests/test_weapon_upgrades.gd**:
  - Test `UpgradeDefs.effective_stat(id, level)` scaling math for each effect type.
  - Test cost curve array indexing (no out-of-bounds).
  - Test migration: convert old owned_weapons to level-0 instances, verify round-trip save/load preserves levels.
  - Test that CharacterScene reads upgrade_level correctly and calls effective_stat for display.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
