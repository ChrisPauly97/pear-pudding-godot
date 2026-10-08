# TID-722: Enough quests for 3–4 per level from L3: repeatable camp quests

**Goal:** GID-177
**Type:** agent
**Status:** pending
**Depends On:** TID-721

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

From level 3, a level should take a few quests. The starter chain (`SideQuests`) has about one quest per level, so more quest supply is needed, or players are left grinding.

**Pacing targets (user, 2026-10-08):**
- Levelling is much slower; there's no rush to level 10.
- Level 1 takes about **10 minutes** of play, and each level after takes longer ("graduating up"). Working model: +5 min per level, so L1 10, L2 15, L3 20 … L9 50 min, about 4.5 h to level 10. Confirm the step when the first numbers are in.
- From level 3 on, a level takes **a few quests** (about 3–4) plus the kills along the way.

## Research Notes

- `game_logic/quests/SideQuests.gd`: authored chain (`min_level` 1–9, rewards xp / coins / cards / gear choice; objective types kill / use_skill / learn / talk / flag / explore / open …). Quest tracking: QuestLog, QuestTracker module, QuestZones (camp areas).
- **Cheapest content:** repeatable, generated quests per starter camp ("Cull the Old Orchard: slay 6", "Clear North Barrow") offered by a camp-side board or a town NPC, with level = the camp level (TID-719), a daily / cooldown reset, and XP sized by XpCurve so 3–4 quests ≈ one level. The existing bounty board (`BountyGen`, gated by `feat_bounties` at L8) is the model; consider unlocking camp quests from L3.
- Keep authored story / side quests as they are; these are filler supply.
- Tests: for each level 3–9 enough quests are available (authored + generated) to cover ≥ 3 per level; repeatables respect their cooldown.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
