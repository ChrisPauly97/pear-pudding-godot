# TID-193: Salvage Duplicate Weapons & Upgraded-Stat Display

**Goal:** GID-052
**Type:** agent
**Status:** done
**Depends On:** TID-191, TID-192

## Lock

**Session:** claude/work-task-gid-052-0nhmq8
**Acquired:** 2026-06-16T10:30:00Z
**Expires:** 2026-06-16T11:00:00Z

## Context

Weapons drop as duplicates (same ID, level 0 on pickup). Salvage converts unwanted copies into coins + essence. CharacterScene must display upgrade levels (+N) and scaled stats when showing equipped weapons. Both systems read from the same `UpgradeDefs.effective_stat()` helper to stay consistent.

## Research Notes

- **Salvage value formula:** A weapon salvaged returns:
  - **Base:** Look up weapon tier/rarity in `WeaponData` (check if `WeaponData.gd` lines 1–16 have a `tier` or `rarity` field; if not, use weapon slot as proxy: weapon=10, armor=8, ring=6, trinket=4 base).
  - **Calculation:** `coins = base * 0.4`, `essence = base * 0.2` (rough 40% coin / 20% essence of base value). Adjust so a full duplicate weapon returns ~25–40 coins + 2–4 essence, roughly 25% of purchase value (deterrent to over-salvaging, but still useful for duplicates).
  - Stored as consts in **UpgradeDefs.gd** or inline in `salvage_weapon()`.

- **Equipped weapon guard:** Before salvaging, verify weapon is not equipped. Check all four slots in SaveManager:
  - **autoloads/SaveManager.gd** lines 55, 61–63: `equipped_weapon`, `equipped_armor`, `equipped_ring`, `equipped_trinket` are all `String` fields.
  - Logic: if `weapon_id == SaveManager.equipped_weapon OR weapon_id == SaveManager.equipped_armor ...` (any match), refuse salvage and show message "Cannot salvage equipped items".

- **Salvage UI in BlacksmithScene (from TID-192):**
  - Each weapon row gets a "Salvage" button next to "Upgrade" button (or right-align it).
  - Salvage is enabled only if weapon is NOT equipped.
  - On click: Show a confirm dialog (cite existing confirm-dialog pattern, e.g. from deck builder or item delete; search **scenes/** for "confirm" pattern). Dialog: "Salvage [Weapon Name]? You'll get X coins and Y essence."
  - On confirm: Call `SaveManager.salvage_weapon(weapon_id)`, update row, emit `GameBus.weapon_salvaged(weapon_id)` signal, show toast.
  - Toast: "Salvaged [Weapon Name]! +X coins, +Y essence."

- **CharacterScene display upgrade level + scaled stats:**
  - Currently **scenes/ui/CharacterScene.gd** shows equipped weapon in slot buttons (line reference TBD). At the point where it renders the equipped weapon name or stats:
    - **Name suffix:** Append upgrade level as "+N" (e.g. "Rusty Dagger +2").
    - **Stat suffix:** If weapon has `battle_effect_type` in ["starting_mana", "starting_hp", "passive_atk"], show both base and effective value:
      - E.g. "Passive Attack: 2 → 3" (base → upgraded), or just show effective.
      - Use `UpgradeDefs.effective_stat(weapon_id, level)` to compute the upgraded value.
  - **Single-source rule:** Create a helper `UpgradeDefs.get_display_string(weapon_data: WeaponData, level: int) -> String` that returns the formatted stat line (e.g. "Mana +2 (base: 2 + 0 upgrade)"). Both CharacterScene and BlacksmithScene call this to ensure consistency.

- **SaveManager API (extend from TID-191):**
  - `salvage_weapon(weapon_id: String) -> Dictionary` returns `{coins: int, essence: int}` or `{}` if refused (equipped or not found).
  - `upgrade_weapon(weapon_id: String) -> bool` returns success/fail (already in TID-191, verify here).
  - Both call `mark_dirty()` and emit signals.

- **GameBus signals:**
  - `weapon_salvaged(weapon_id: String, coins: int, essence: int)` — emitted after successful salvage.
  - Update **docs/agent/signals-and-constants.md** signal table to include both `weapon_upgraded` and `weapon_salvaged`.

- **Headless tests:** New file **tests/test_weapon_salvage.gd**:
  - Test salvage value math (coins/essence calculation).
  - Test equipped-weapon guard: try to salvage while equipped, verify it's refused and save state unchanged.
  - Test display helper `get_display_string(weapon_data, level)` for all effect types; verify output is human-readable.
  - Test round-trip: salvage a weapon, reload save, verify it's gone from owned_weapons and coins/essence increased.

## Plan

- `SaveManager.salvage_weapon(weapon_id)` — removes first unequipped instance, returns `{coins, essence}`, checks all 4 equipped slots.
- `BlacksmithScene` Salvage button — disabled for equipped items, shows toast with `+coins/+essence`.
- `CharacterScene` — slot buttons show `+N` suffix for equipped weapon; picker rows show `+N` name and scaled stats via `UpgradeDefs.get_display_string`.
- Tests: `tests/unit/test_weapon_salvage.gd`.

## Changes Made

- **`autoloads/SaveManager.gd`** — `salvage_weapon(weapon_id)` implemented; flat `SALVAGE_COINS=30 / SALVAGE_ESSENCE=3` return; equipped-weapon guard checks all 4 slots; emits `GameBus.weapon_salvaged`.
- **`scenes/ui/BlacksmithScene.gd`** — Salvage button per row (greyed when equipped); `_on_salvage_weapon` calls `SaveManager.salvage_weapon` and shows toast.
- **`scenes/ui/CharacterScene.gd`** — `_refresh_slot_buttons` appends ` +N` suffix for equipped weapon slot; `_make_picker_row` shows upgrade level in name and uses `UpgradeDefs.get_display_string` for effect line. Added `UpgradeDefs` preload.
- **`tests/unit/test_weapon_salvage.gd`** — 27 tests; all pass.

## Documentation Updates

Updated `docs/agent/signals-and-constants.md` (weapon_salvaged signal row).

## Lock

**Session:** none
**Acquired:** —
**Expires:** —
