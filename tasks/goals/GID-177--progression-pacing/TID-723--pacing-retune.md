# TID-723: Re-tune quest / kill XP and gold to the new curve; pacing test

**Goal:** GID-177
**Type:** agent
**Status:** done
**Depends On:** TID-721, TID-722

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make the whole starter chain land on the pacing targets and keep training affordable.

**Pacing targets (user, 2026-10-08):**
- Levelling is much slower; there's no rush to level 10.
- Level 1 takes about **10 minutes** of play, and each level after takes longer ("graduating up"). Working model: +5 min per level, so L1 10, L2 15, L3 20 … L9 50 min, about 4.5 h to level 10. Confirm the step when the first numbers are in.
- From level 3 on, a level takes **a few quests** (about 3–4) plus the kills along the way.

## Research Notes

- From TID-719: the Madrian camps now sit at levels 1–5, but the authored starter quests for levels 6–9 (`SideQuests`: East Copse min 6, … South Road Wreck min 9) still send the player to them. A level-9 player at a level-4 camp is grey (no XP). Move those quests' kill targets to road-zone camps (TID-722), or re-gate them. `test_side_quests` now grinds camp kills between quests (bound: 40 kills) as a stop-gap.
- `tests/unit/test_side_quests.gd` `test_starter_chain_paces_levels_and_gold` simulates the chain with quest + camp kill XP (`StarterZone.camp_for_level`, `ZoneLevels.scaled_xp`) and asserts that each UnlockLadder training is affordable when its quest asks for it, and level 6 + companion gold at the end. Rework it into a time-based pacing check against the targets (L1 ≈ 10 min, +5 min / level) using the TID-721 time model.
- Gold: UnlockLadder costs (15 … 1000) must still be affordable at each level given the slower pace, since players get more kills per level now. Re-check coin rewards.
- Docs: starter-zone-and-training.md (pacing table), save-system (migration).

## Plan

Medium complexity, so I proceeded without an approval stop.
1. A pacing simulation on the real save API with an explicit time model.
2. Iterate the authored quest XP and the camp-quest share until each level lands near its target.
3. A time-based pacing test (mutation-checked).
4. Docs.

## Changes Made

- New `tests/support/pacing_sim.gd`: a scripted Chapter 1 player on the real `SaveManager` / `SaveQuests` with a time model (kill 60 s, quest 90 s + 90 s travel, other objective 60 s).
- `autoloads/save_manager/SaveQuests.gd`: `clock_override` (simulated time); `_now()` became an instance method.
- `game_logic/quests/SideQuests.gd`: quest XP retuned (rats 200, bruised 260, chanting 230, raise 170, spark 180, east_copse 280, west_crossing 350, board 400, after_dark 420, wreck 450); `CAMP_QUEST_XP_SHARE` 1/6 → 0.09.
- Measured: L1 9.5, L2 17.5, L3 21, L4 23, L5 22, L6 36, L7 35, L8 48, L9 44 min (targets 10 … 50); 4.3 h to level 10; 2–4 quests per level from level 3.
- New `tests/unit/test_pacing.gd` (4): per-level time ±30 %, total hours, quests per level, trainings on time. Mutation-checked (camp share 0.3 fails three levels and the total).
- Gold: about 2 400 coins at level 10 vs about 755 of trainings. Training never stalls; gold is now plentiful (no sinks yet), which is a separate topic.
- `test_starter_chain_paces_levels_and_gold` kept as a chain-integrity check.
- Validation: full suite PASS with 0 SCRIPT ERROR; world / realtime / in-world smoke tests clean; gdlint and unsafe-hits clean.

## Documentation Updates

starter-zone-and-training.md: quest-chain XP column; new "Pacing model and tuning" section.
