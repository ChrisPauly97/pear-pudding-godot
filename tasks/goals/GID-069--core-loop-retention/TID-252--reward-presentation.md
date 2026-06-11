# TID-252: Full Reward Presentation — Coins, XP, Rarity & Level-Up Prompt

**Goal:** GID-069
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Winning a battle awards a card, coins, and XP — but the victory overlay only shows the card *name*. Coins and XP are added silently in `SceneManager._on_battle_won()` after the overlay closes, and the card's rarity is rolled there too, so the player never sees what rarity they got. Level-up is a passive toast with no route to spend the new skill point. Rewards players can't see don't motivate; this task makes the victory screen the full reward moment.

## Research Notes

- **Victory overlay:** `BattleScene._show_victory_overlay()` (BattleScene.gd:1478) and `_show_victory_overlay_boss()` (BattleScene.gd:1533) — code-built PanelContainer; shows "You earned: <card name>" and optional weapon line, then a Collect button that emits `GameBus.battle_won` with `{card_reward, weapon_reward}`.
- **The rarity-after-overlay problem:** `SceneManager._on_battle_won()` (SceneManager.gd:253) rolls rarity/stats via `CardDropUtil.effective_rarity` / `roll_rarity(drop_tier)` / `roll_stats` *after* the overlay is gone. Fix: roll rarity+stats **in BattleScene before showing the overlay** (BattleScene knows `enemy_data`, can compute `drop_tier` via `EnemyRegistry.get_difficulty_tier`, boss → tier 4) and pass the rolled results through the `battle_won` result dict so SceneManager only *applies* them. Keeps the award authority in SceneManager, moves the roll to the reveal.
- **Coins:** `EnemyRegistry.get_coin_reward(enemy_type)` — deterministic, can be displayed up front.
- **XP:** `_XP_TABLE` const inside `_on_battle_won` (SceneManager.gd:~297): `{undead_basic:20, undead_horde:35, ghoul_pack:50, undead_elite:80}`, default 25, ×2 for bosses. Move this table to `EnemyRegistry` (or IsoConst) so BattleScene can display the same number SceneManager awards — no duplicate tables (CLAUDE.md canonical-constants rule).
- **Overlay content:** card name + rarity (color-coded; rarity tiers/colors already used by InventoryScene sort, see InventoryScene.gd:268 and `CardDropUtil`), "+N coins", "+N XP", weapon line if any. Keep one Collect button.
- **Level-up prompt:** `SaveManager.add_xp()` (SaveManager.gd:~790) grants `skill_points` and emits `GameBus.level_up(new_level)`; the only listener is `SceneManager._on_level_up` (SceneManager.gd:414) showing a passive toast. Add: if `save_manager.skill_points > 0` after Collect, show a "Level Up — you have N skill points" line/button on the victory overlay (or a follow-up toast with action) that opens the skill tree. Skill tree entry: `SkillTreeScene` (scenes/ui/SkillTreeScene.tscn) — check how CharacterScene/menu currently routes there and reuse that path via SceneManager.
- **Boss overlay:** apply the same additions to `_show_victory_overlay_boss` (it lists multiple cards; roll each card's rarity up front).
- **Tests:** CardDropUtil rolling moved call sites — keep existing tests green; add a test asserting the result dict carries pre-rolled rarity/stats and SceneManager applies them verbatim.
- **Mobile parity:** overlay is already touch-based; size new labels/buttons viewport-relative.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
