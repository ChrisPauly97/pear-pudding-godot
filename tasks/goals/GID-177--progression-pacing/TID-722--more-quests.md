# TID-722: Camps and repeatable quests across Chapter 1's zones (3–4 quests per level from L3)

**Goal:** GID-177
**Type:** agent
**Status:** pending
**Depends On:** TID-721, GID-176 / TID-719

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

- **Widened (user, 2026-10-08):** Chapter 1 spans levels 1–10 over story-route zones (TID-719): Madrian outskirts 1–5, South road and wilds 4–7, Farsyth lands and Isfig road 6–9, Blancogov approach 8–10. Levels 5–10 happen on the road, so **every Chapter 1 zone needs camps and repeatable quests**, not only Madrian's.
- **Road camps:** generalise `StarterZone` camps into per-zone camp sets. Placed along the route between story sites (RealmLayout roads / sites), with clearings and set dressing via CampDressing, reserved ground in RealmLayout, respawn via the StarterCamps module (or a generalised `ZoneCamps`). Camp level is derived from the zone (TID-719); types use the zone-appropriate enemy sub-ranges. Keep chunk generation pure.
- **Repeatable quests:** per camp (or per zone board / road NPC: a waystone keeper, a traveller at the wilderness camp, Farsyth's steward), sized so 3–4 quests + kills ≈ one level at that level (TID-721 curve).
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
