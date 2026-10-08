# TID-722: Camps and repeatable quests across Chapter 1's zones (3–4 quests per level from L3)

**Goal:** GID-177
**Type:** agent
**Status:** done
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

- From TID-719: the Madrian camps now sit at levels 1–5, but the authored starter quests for levels 6–9 (`SideQuests`: East Copse min 6, … South Road Wreck min 9) still send the player to them. A level-9 player at a level-4 camp is grey (no XP). Move those quests' kill targets to road-zone camps (TID-722), or re-gate them. `test_side_quests` now grinds camp kills between quests (bound: 40 kills) as a stop-gap.
- **Widened (user, 2026-10-08):** Chapter 1 spans levels 1–10 over story-route zones (TID-719): Madrian outskirts 1–5, South road and wilds 4–7, Farsyth lands and Isfig road 6–9, Blancogov approach 8–10. Levels 5–10 happen on the road, so **every Chapter 1 zone needs camps and repeatable quests**, not only Madrian's.
- **Road camps:** generalise `StarterZone` camps into per-zone camp sets. Placed along the route between story sites (RealmLayout roads / sites), with clearings and set dressing via CampDressing, reserved ground in RealmLayout, respawn via the StarterCamps module (or a generalised `ZoneCamps`). Camp level is derived from the zone (TID-719); types use the zone-appropriate enemy sub-ranges. Keep chunk generation pure.
- **Repeatable quests:** per camp (or per zone board / road NPC: a waystone keeper, a traveller at the wilderness camp, Farsyth's steward), sized so 3–4 quests + kills ≈ one level at that level (TID-721 curve).
- `game_logic/quests/SideQuests.gd`: authored chain (`min_level` 1–9, rewards xp / coins / cards / gear choice; objective types kill / use_skill / learn / talk / flag / explore / open …). Quest tracking: QuestLog, QuestTracker module, QuestZones (camp areas).
- **Cheapest content:** repeatable, generated quests per starter camp ("Cull the Old Orchard: slay 6", "Clear North Barrow") offered by a camp-side board or a town NPC, with level = the camp level (TID-719), a daily / cooldown reset, and XP sized by XpCurve so 3–4 quests ≈ one level. The existing bounty board (`BountyGen`, gated by `feat_bounties` at L8) is the model; consider unlocking camp quests from L3.
- Keep authored story / side quests as they are; these are filler supply.
- Tests: for each level 3–9 enough quests are available (authored + generated) to cover ≥ 3 per level; repeatables respect their cooldown.

## Plan

**Approved by the user (2026-10-08).** high complexity, with content and design choices.

1. **Road camps:** a `ZoneCamps` table (same shape as `StarterZone.CAMPS`), 8 camps 10–15 tiles off the route, level from the zone (TID-719).
   - South Road: Wolf Hollow, Shade Thicket, Mire Edge.
   - Farsyth Lands: Stag Glade, Drowned Mill, Old Watchtower.
   - Blancogov Approach: Martarquas Outpost, Scout Ridge.
   - New level ranges: wolf_pack 4–6, forest_shade 5–8, bog_hag 6–8, imbued_stag 7–9, martarquas_scout 8–10.
   - The StarterCamps module, RealmLayout reserved ground, CampDressing (reused themes) and QuestZones read one camp list.
2. **Repeatable "bonus objectives":** entering a camp's area auto-starts that camp's "Cull: defeat 5" quest, which auto-completes and restarts after a 10-minute cooldown.
   - Covers every Chapter 1 camp; Madrian's from level 3.
   - Needs: `repeatable` + `cooldown_s` in SideQuests (generated defs); a new PERSISTED field + migration for the next-allowed times; a camp-enter trigger in StarterCamps; auto turn-in.
   - Rejected alternative: boards or NPC givers (new interactables, about 3× the work).
3. **Re-point quests:** the authored level 6–9 starter quests (east_copse, west_crossing, board_by_the_well, south_road_wreck) move to road camps of matching level.
4. **Tests:** camps inside zones and on clear ground; ≥ 3 quests for each level 3–9; cooldown; auto-start; quest targets within ±2 levels.

Out of scope: final XP / gold sizing (TID-723).

## Changes Made

- `game_logic/world/StarterZone.gd`: 7 road camps appended to `CAMPS`: Wolf Hollow L5, Shade Thicket L6, Mire Edge L7, Stag Glade L7, Old Watchtower L8, Martarquas Outpost L9, Scout Ridge L10. Each has a `dress` key. Camps now cover levels 1–10. Planned 8; the South Road strip has no valid level-4 site (coast / rivers / Maykalene), and Madrian has three level-4 camps.
- `autoloads/EnemyRegistry.gd`: level ranges for wolf_pack 4–6, forest_shade 5–8, bog_hag 6–8, imbued_stag 7–9, martarquas_scout 8–10.
- `game_logic/world/CampDressing.gd`: a camp without its own layout reuses its `dress` camp's.
- `game_logic/quests/SideQuests.gd`: generated `camp_quests()` (repeatable, auto, giver-less "Cull" per camp). `all()` merges them. Repeatables can be re-offered after completion. `offers_for` / `upcoming_for` ignore giver "". The level 6–9 quests are re-pointed to road camps (new titles and text; ids kept).
- `autoloads/save_manager/SaveQuests.gd`: `auto_start(id, now)`, auto-complete on ready, repeatable turn-in sets the cooldown instead of `quests_completed`; `npc_states` skips giver-less quests.
- `autoloads/SaveManager.gd`: new PERSISTED field `quest_repeat_at`.
- `scenes/world/modules/StarterCamps.gd`: `_maybe_start_bonus` within a camp's clearing.
- Tests: new `tests/unit/test_camp_quests.gd` (6); `test_side_quests` / `test_starter_zone` skip giver-less quests where they check givers.
- Validation: full suite PASS with 0 SCRIPT ERROR; all 12 CI smoke tests clean; gdlint and unsafe-hits clean.
- Not verified: how the road camps look in game (headless only); camp sites were chosen by a probe over road / reserved / water distances.

## Documentation Updates

starter-zone-and-training.md: new "Chapter 1 road camps and camp bonus objectives" section; quest-chain table rows 6–10 re-pointed.
