# TID-144: Regional Champion Ladder & Rewards

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** TID-143

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Once friendly duels exist (TID-143), a champion ladder gives the player a goal: beat all duelists in a region to unlock a champion fight that rewards a legendary card. This is the same Gym Leader / card tournament beat the cadre → fight the boss pattern that makes duel progression satisfying.

## Research Notes

- **Champion NPC:** A new TownspersonNPC variant in a named map (e.g. blancogov) that is locked behind `SaveManager.defeated_duelists` containing all region duelists. The `_check_interact` should show "I won't duel you until you've beaten the other players in town."
- **EnemyData for champion:** Reuse EnemyData with a strong deck; `coin_reward` = 0; drop pool = one legendary card (e.g. a new `champion_trophy` CardData).
- **Save tracking:** `defeated_duelists` added in TID-143 is the gating data. No new save fields needed unless we add a `champion_defeated: bool` per region.
- **Legendary reward card:** May need a new CardData `.tres` of rarity `legendary` (use CraftingRegistry schema from GID-028). Check `data/cards/` for naming convention.
- **UI feedback:** After defeating all duelists, a notification ("Champion unlocked!") via `GameBus.achievement_unlocked` or a simple HUD toast using `AchievementToast`.
- `docs/agent/meta-progression.md` — review achievement hook pattern.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
