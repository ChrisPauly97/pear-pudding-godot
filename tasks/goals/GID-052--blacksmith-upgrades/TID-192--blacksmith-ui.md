# TID-192: Blacksmith NPC & Upgrade Screen UI

**Goal:** GID-052
**Type:** agent
**Status:** pending
**Depends On:** TID-191

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The blacksmith is an NPC in the world who opens a dedicated UI for upgrading owned weapons and salvaging duplicates. The screen layout mirrors **ShopScene.gd** (lines 1–100+): dark overlay, scrollable list of items, purchase/upgrade buttons.

## Research Notes

- **NPC placement & detection:** Blacksmith appears in a town map via `MapNpc` entity with an `npc_type: String` field (see **docs/agent/named-maps-and-dungeons.md** for exact pattern). Detect via `current_npc_type == "blacksmith"` and route to `_open_blacksmith_upgrade_scene()` in **SceneManager.gd**, matching how merchants are routed (line references TBD in SceneManager).

- **Which town?** Check existing NPC counts in town `.tres` files (search **assets/maps/** for `.tres` files with NPC list fields). Place blacksmith in the town with fewest NPCs, or in a central town like Madrian. Cite exact town name once verified.

- **New scenes/ui/BlacksmithScene.gd + .tscn:**
  - Extends Control, singleton-like instantiation via SceneManager (not reused).
  - Layout: header with title + close button (C key + HUD button on desktop/mobile parity per CLAUDE.md), coin/essence display (line 45–49 of ShopScene for pattern), scrollable list of owned weapons.
  - Each weapon row (mirroring ShopScene item rows, lines 65–100+):
    - Weapon name + current upgrade level (e.g. "Rusty Dagger +2")
    - Current stats: effective value calculated via `UpgradeDefs.effective_stat(id, level)` (from TID-191)
    - Next-level stats: preview if upgraded (only if level < 5)
    - Cost breakdown: icons + text (e.g. "100 coins, 5 essence" — cite ShopScene's _make_item_row pattern for icon/label pair formatting)
    - Upgrade button: disabled if level >= 5 (maxed), or if coins/essence insufficient. When disabled, show visual feedback like `disabled = true` and greyed-out text (cite ShopScene's disabled button pattern, e.g. lines 80–90 TBD).
    - On click: call `_upgrade_weapon(weapon_id)` which calls `SaveManager.upgrade_weapon(weapon_id)` (new method, defined in TID-191's SaveManager extensions). If success, update the row and emit toast. If fail (insufficient funds), show tooltip or flash effect.

- **Feedback patterns:**
  - Toast on upgrade: Call `AchievementToast.show_text("Upgraded!", "Rusty Dagger → +3")` (cite line 67 of AchievementToast) after successful upgrade.
  - Anvil sound (optional, nice-to-have): Check if `AudioManager` has a sfx helper; if so, call it on upgrade success. Cite AudioManager.play_sfx() if it exists.
  - Button state: disabled bool flips on affordability change; test by refreshing cost display on each frame or when coins/essence change via signal.

- **Salvage button (prepared for TID-193):**
  - For now, leave a comment "Salvage button added in TID-193" or stub a Salvage button that's invisible. Do NOT implement full salvage flow yet.

- **Mobile parity:**
  - Viewport-relative sizing per CLAUDE.md (all custom_minimum_size as vh/vw fractions).
  - Close button text: "Close [C]" on desktop (check OS.has_feature("android")), just "Close" on mobile.
  - Tap to upgrade (no extra key binding needed beyond Shop pattern).

- **Preload & Android:** BlacksmithScene is instantiated on demand, not preloaded. No `.tres` resources, so no `.uid` sidecars needed. Cite Android rules (CLAUDE.md).

- **Headless tests:** Extract button affordability logic into a pure function `can_afford_upgrade(coins, essence, cost_coins, cost_essence) -> bool` and test it. Mock the upgrade flow with a fake SaveManager state.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
