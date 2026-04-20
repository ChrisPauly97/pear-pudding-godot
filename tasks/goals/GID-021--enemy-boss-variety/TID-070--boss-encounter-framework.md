# TID-070: Boss Encounter Framework

**Goal:** GID-021
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No boss system exists. This task adds a boss flag to EnemyData and changes the battle presentation for boss fights (distinct UI treatment, optional phase-2 mechanic). TID-071 then places actual bosses using this framework.

## Research Notes

- `data/enemies/EnemyData.gd` (or the Resource subclass used for enemies) — add `is_boss: bool` and optionally `phase2_deck: Array[String]` (empty = no phase 2)
- `scenes/battle/BattleScene.gd` — when `is_boss` is true:
  - Show a boss name banner at battle start (Label that fades in/out)
  - Enemy hero HP could be higher (set via enemy data or a `boss_hp: int` field on EnemyData)
  - Phase 2: if `phase2_deck` is non-empty, when enemy HP drops below 50%, swap enemy deck to phase2_deck (discard hand, draw from new deck)
- Boss battles should not drop a random card from drop_pool — they should drop all items in the drop_pool (guaranteed rewards for a hard fight)
- `scenes/world/entities/EnemyNPC.gd` — boss enemies in the world could have a different sprite tint or scale to visually distinguish them; keep this simple (just a modulate color change)
- Follow CLAUDE.md UI sizing for the boss banner

## Plan

1. Add `is_boss`, `boss_hp`, `phase2_deck` fields to `data/EnemyData.gd`.
2. Add `get_is_boss()`, `get_boss_hp()`, `get_phase2_deck()` to `autoloads/EnemyRegistry.gd`.
3. Update `scenes/world/entities/EnemyNPC.gd`:
   - `init_from_data()`: look up is_boss from registry and apply gold modulate + 1.3× scale.
   - `engage()`: populate `"is_boss"`, `"boss_hp"`, `"phase2_deck"` in edata.
4. Update `scenes/battle/BattleScene.gd`:
   - `_ready()`: if is_boss, override enemy hero HP, show fading boss-name banner.
   - New `_show_boss_banner()`: centered label with enemy display name, fades after 2 s.
   - New `_check_boss_phase2()`: if non-empty phase2_deck and enemy HP ≤ 50%, discard hand, rebuild deck, draw 4, show "PHASE 2" label.
   - `_check_game_over()`: call `_check_boss_phase2()` first; on boss win emit all drop_pool cards as `"card_rewards"`.
   - New `_show_victory_overlay_boss()`: victory overlay listing all reward cards.
5. Update `autoloads/SceneManager.gd`: in `_on_battle_won()` also handle `"card_rewards"` list for boss multi-drops.

## Changes Made

- `data/EnemyData.gd`: Added `is_boss: bool`, `boss_hp: int`, `phase2_deck: PackedStringArray` exported fields.
- `autoloads/EnemyRegistry.gd`: Added `get_is_boss()`, `get_boss_hp()`, `get_phase2_deck()` static methods.
- `scenes/world/entities/EnemyNPC.gd`:
  - Added `_is_boss: bool` member; set in `init_from_data()` via registry lookup.
  - `_ready()`: calls `_apply_boss_visual()` if `_is_boss` (after all mesh children are built).
  - `engage()`: populates `"is_boss"`, `"boss_hp"`, `"phase2_deck"` in edata dict before emitting.
  - New `_apply_boss_visual()`: scales NPC to 1.3×, applies gold materials.
- `scenes/battle/BattleScene.gd`:
  - Added `_boss_phase2_triggered`, `_boss_banner`, `_boss_banner_timer` members.
  - `_process()`: fades boss banner over last 0.5 s.
  - `_ready()`: if `is_boss`, overrides enemy hero HP from `boss_hp` and calls `_show_boss_banner()`.
  - New `_show_boss_banner()`: full-width Label with enemy display name, gold colour, fades after 2.5 s.
  - New `_check_boss_phase2()`: triggers at ≤50% HP — rebuilds enemy deck, draws 4, shows "PHASE 2" banner.
  - `_check_game_over()`: calls `_check_boss_phase2()` first; boss win uses `_show_victory_overlay_boss()`.
  - New `_show_victory_overlay_boss()`: overlay listing all drop_pool cards; emits `{"card_rewards": [...]}`.
  - `_refresh_hero()`: enemy name label shows boss display name instead of "ENEMY" for boss fights.
- `autoloads/SceneManager.gd`: `_on_battle_won()` handles `"card_rewards"` list in addition to `"card_reward"`.

## Documentation Updates

- Updated `docs/agent/enemies-and-npcs.md` with boss framework details.
