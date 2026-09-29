# TID-599: Anti-Spam Rewards & Rift Quests

**Goal:** GID-142
**Type:** agent
**Status:** done
**Depends On:** TID-597, TID-533

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User: "you can't just spam rifts to level up, reward the player for rifting once with a quest to reach a certain tier,
perhaps more quests later to rift in different biomes with different enemy types."

## Research Notes

- Per-run rewards: small coins + a loot roll scaling with tier (`CardDropUtil`, equipment drop path in `ChestLoot`);
  **XP only on the first clear of each (rift, tier)** — track `rift_first_clears` (Array of "rift:tier") in save.
  Enemy kills inside a rift grant 0 XP (check `BattleVictory` L124 `add_xp` path; skip when in a rift, like grey-level
  enemies in TID-536).
- Rift quests: quest `.tres` from TID-533 (`data/quests/`, const-preloaded `QuestRegistry`) with a new objective type
  `rift_tier {rift, tier}`, progressed from `end_spire_run`/tier completion via a GameBus signal (e.g.
  `rift_tier_cleared(rift_id, tier)`; literal `.emit()`). One-time big XP + coins + gear.
- Initial set: "Into the Rift" (Grasslands tier 1, given at L15 training — GID-141 TID-590 ladder row `feat_spire`),
  then per-biome "Reach tier 3 in the <Biome> Rift", later tier 5/10 follow-ups. Givers: rift keeper NPC at each
  entrance (TID-600).
- Tests: repeat clear gives 0 XP; first clear gives XP once; quest completes on tier clear.

## Plan

No XP from rift kills; per-clear coins + card; XP only on first (rift, tier) clear; `rift_tier` quest objective from the clear; Rift Warden in Madrian gives one-time rift quests (per-biome tier 3, grasslands tier 5).

## Changes Made

- `RiftDefs.gd`: reward constants, `first_clear_xp`, `clear_drop_tier`, `clear_key`.
- `SaveSpire.end_spire_run`: clear coins, guardian card, first-clear XP, `rift_tier_cleared` + quest progress.
- `SaveManager.gd`: `rift_first_clears` field. `GameBus.gd`: `rift_tier_cleared`.
- `SideQuests.gd`: 7 rift quests; `madrian.tres`: `rift_warden_madrian`.
- `SaveQuests.accept`: already-learned `learn` objectives count.
- `SceneManager._complete_rift_tier`: reward toast.
- Tests: `test_rift_defs.gd` +2 (no farming XP, quest completes on clear). Suite green, smokes clean, lint clean.

## Documentation Updates

`rifts.md` rewards + rift quests section.
