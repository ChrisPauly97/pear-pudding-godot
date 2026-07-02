# TID-407: Chapter 2 Flags, Objectives, Beat Wiring & Scripted Ambush Battle

**Goal:** GID-108
**Type:** agent
**Status:** pending
**Depends On:** TID-405, TID-406

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With the maps (TID-406) and the Chapter 1 ending (TID-405) in place, this task wires the seven approved Chapter 2 beats (docs/human/story.md "Chapter 2: The Road to Larik") into playable progression: flags, objectives, the scripted spell-tutorial ambush, the story-triggered siege at Marsax hold, the war-camp dungeon boss, and the chapter cliffhanger ending.

## Research Notes

- **Beats (docs/human/story.md):** 1 council's charge (blancogov_temple dialogue after chapter1_complete) → 2 return to Larik (hidden-letter scroll) → 3 scouts in the grass (scripted ambush battle) → 4 Marsax hold besieged (siege system) → 5 traitor's seal (scroll) → 6 war-camp dungeon (boss) → 7 cliffhanger (narration overlay, sets chapter2_complete).
- **Proposed flags (in progression order):** chapter2_charged, chapter2_reached_larik, chapter2_found_letter, chapter2_ambush_survived, chapter2_siege_won, chapter2_traitor_seal, chapter2_warcamp_cleared, chapter2_complete. Extend game_logic/ObjectiveTracker.gd (reverse-progression order, most-advanced first — see existing table) and tests/unit/test_objective_tracker.gd. Flags persist automatically via SaveManager.story_flags.
- **Scripted ambush (beat 3):** uses the TID-401 ScriptedBattleData framework — introduces spell cards (GID-076 added 40 spell cards; pick 2–3 low-cost ones from CardRegistry) with per-turn popups; triggered on the open-world road west of Blancogov after chapter2_reached_larik logic — reuse the open-world scripted spawn pattern (WorldScene.gd `_spawn_open_world_rival_enc2`, ~line 2897). New enemy type: Martarquas scout — EnemyData .tres in data/enemies/, preloaded in EnemyRegistry; consider reusing spec "Planned Enemy Types" stats rather than inventing new ones.
- **Story siege (beat 4):** town siege system from GID-054 — game_logic/SiegeDefs.gd, tests/unit/test_siege_trigger.gd show trigger conditions (it currently keys off chapter1 flags — read carefully). Trigger a scripted siege on marsax_hold entry when chapter2_ambush_survived && !chapter2_siege_won; victory sets chapter2_siege_won.
- **War-camp dungeon (beat 6):** DungeonGen procedural dungeon behind a DOOR (TID-406); boss uses the GID-021 boss framework (check goal GID-021 tasks — boss framework TID-070 done; boss encounters partially pending). Warband-leader boss: EnemyData boss-tier deck; clearing sets chapter2_warcamp_cleared.
- **Cliffhanger ending (beat 7):** reuse the TID-405 narration-overlay ending mechanism with Chapter 2 pages; sets chapter2_complete; returns to playable world.
- **Rival hook (optional, keep scope tight):** Isfig's finale dialogue ("Perhaps it's time I stood beside him") leaves room for a Ch2 cameo — note for a future goal, do not implement here.
- Headless import + full test run after every script edit (CLAUDE.md).

- **Co-op (up to 4 players):** this feature must follow the TID-408 design rules (shared-flag arbitration via SessionState, exactly-once beat effects, authority-broadcast narration, single synced Maiteln, no write-through to solo saves). Read TID-408--coop-story-compatibility.md before Plan.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
