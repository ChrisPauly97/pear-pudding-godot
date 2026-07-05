# TID-407: Chapter 2 Flags, Objectives, Beat Wiring & Scripted Ambush Battle

**Goal:** GID-108
**Type:** agent
**Status:** done
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

All 8 flags wired in progression order via reuse of existing mechanisms wherever one already
fits — no new sub-systems built where an existing one (scripted battle framework, siege
gauntlet, scroll collection, King Eldar's custom dialogue, `ChapterEndingOverlay`) already does
the job.

1. **Beat 1 (council's charge):** extend `WorldScene._handle_king_eldar_interaction()` with a
   5th state — `chapter1_complete` set but `chapter2_charged` not yet → sets it, shows a new
   charge line (no exact quote given in story.md's terse beat table; authored in-register),
   falls through to the existing epilogue line on subsequent talks.
2. **Beat 2 (return to Larik):** `chapter2_reached_larik` set on first entry to `map_name == "larik"`
   (mirrors the existing `chapter1_reached_blancogov` on-map-enter pattern). Collecting
   `scroll_larik_letter` (already placed by TID-406) sets `chapter2_found_letter` — a small
   scroll-id special case added to `WorldScene._on_scroll_collected()` (no generic
   flag-on-collect schema exists on `MapScroll`/`ScrollRegistry`; two one-off hooks don't justify
   adding one).
3. **Beat 3 (scripted ambush):** new `data/scripted_battles/scout_ambush.tres` — the TID-401
   framework, deck showcasing 2 low-cost GID-076 spell cards (`ember_cinder`, `dawn_soothing_touch`)
   among minions, `completion_flag = "chapter2_ambush_survived"`. New minimal entity
   `scenes/world/entities/ScoutAmbush.gd` (+ `.tscn`) — same tap-to-interact-then-
   `scripted_battle_requested` shape as `WildernessCamp`, not generalized into a shared base
   (matches this codebase's existing pattern of many small single-purpose entity scripts rather
   than a premature shared abstraction). `WorldScene._spawn_scout_ambush()`
   (mirrors `_spawn_wilderness_camp()`/`_spawn_open_world_rival_enc2()`), gated on
   `chapter2_found_letter` set and `chapter2_ambush_survived` not set. No new `EnemyData` (same
   reasoning as `rabbit_hunt`/TID-402 — the framework never touches `EnemyRegistry`).
4. **Beat 4 (siege):** reuses the GID-054 gauntlet wholesale instead of building a parallel story
   siege system. Adds `"marsax_hold"` to `SiegeDefs.TOWN_GATES`; a new
   `WorldScene._check_story_siege_trigger()` calls `save_manager.start_siege("marsax_hold")` once
   on map entry when `chapter2_ambush_survived` is set, `chapter2_siege_won` is not, and no siege
   is already active — called just before the existing `_check_siege_spawn()` so the raiders
   spawn in the same `_ready()`. `SceneManager._on_battle_won`'s final-stage-victory branch sets
   `chapter2_siege_won` when the completing siege's town is `"marsax_hold"`.
   - **Opportunistic bug fix (BID-041), required for this beat to look right:**
     `_spawn_siege_raiders()` called `node.set("enemy_type", enemy_type)` — `EnemyNPC` has no
     such property, so this was a silent no-op and every raider always fell back to
     `"undead_basic"` regardless of stage or town. Replaced with a proper `init_from_data(edata)`
     call (mirrors `_spawn_rival_at`'s exact pattern) so marsax_hold's raiders are actually
     Martarquas-themed (`martarquas_raider_1/2/3`, already existing `EnemyData`), not undead.
     Fixes the bug for the existing random single-player town sieges too, not just this beat.
5. **Beat 5 (traitor's seal):** collecting `scroll_traitor_seal` (already placed by TID-406) sets
   `chapter2_traitor_seal` — same `_on_scroll_collected()` special case as beat 2's letter.
   **Simplification, not fixed:** the scroll is collectible immediately, not gated behind
   `chapter2_siege_won` first — `MapScroll.flag_key` exists on the resource but was never wired
   to anything enforcing it anywhere in the codebase (checked: no read site), and wiring
   enforcement for a one-off narrative nicety is out of scope here.
6. **Beat 6 (war-camp dungeon boss):** new `data/enemies/martarquas_warleader.tres`
   (`is_boss = true`, boss-tier deck + `phase2_deck`, per the GID-021 boss framework — real
   `EnemyRegistry` entry this time, unlike the scripted-battle enemies, because a dungeon boss
   uses the normal `enemy_engaged` pipeline). `DungeonGen` has **no boss-room concept at all**
   (grepped — confirmed) and adding one is out of scope for a single fixed-seed dungeon, so
   `WorldScene._ready()`'s dungeon-load branch gets a `map_name == "dungeon_731906"` special
   case that appends one boss enemy dict directly to the freshly-generated `WorldMap.enemies`
   before chunk distribution — the existing enemy-spawn pipeline handles the rest with zero new
   spawn code. Persists correctly on revisit since `DungeonGen.generate()` already
   `save_to_file()`s the result (boss included) and later visits just reload that save.
   `chapter2_traitor_seal` gates the dungeon door itself (`MapDoor.flag_key`, confirmed enforced
   in `_find_nearby_door` — locked doors are simply excluded from interaction). Defeating the
   boss (checked by `enemy_type == "martarquas_warleader"` in `SceneManager._on_battle_won`)
   sets `chapter2_warcamp_cleared` and triggers beat 7.
7. **Beat 7 (cliffhanger):** reuses `scenes/ui/ChapterEndingOverlay.gd` verbatim (preloaded from
   `SceneManager.gd` this time, not `WorldScene.gd` — the trigger point is the boss-victory
   handler, not a world NPC interaction; the overlay class itself has no scene-specific
   dependency). Shows story.md's three cliffhanger pages immediately after `_restore_world()`;
   `closed` sets `chapter2_complete`.
8. **`game_logic/ObjectiveTracker.gd`**: 7 new most-advanced-first branches inserted before the
   existing `chapter1_complete` check. **Breaking change to two existing TID-405 tests**:
   `chapter1_complete` alone no longer returns `{}` — Chapter 2 continues from there
   (`"Speak to King Eldar"`, i.e. go get charged with the westward ride). Updated
   `test_chapter1_complete_returns_empty` → renamed/repointed and
   `test_chapter1_complete_alone_returns_empty` accordingly, added 7 new tests for the Chapter 2
   objective chain.

**Co-op note (per TID-408):** every new flag site uses the same unwrapped
`SceneManager.save_manager.set_story_flag()` path as every existing Chapter 1 flag (no co-op
arbitration exists anywhere yet); the story siege and boss trigger are local-only. TID-408 owns
adding shared-flag arbitration and joint-battle seating across all of Chapters 1 & 2 at once.

**Explicitly out of scope (per research notes):** the Isfig Chapter 2 cameo hook — noted for a
future goal, not implemented here.

**Validation:** same sandbox constraint as TID-401–406 (no Godot binary, network egress
blocked). This task touches the most existing files of any in this goal (`SceneManager.gd`,
`SiegeDefs.gd`, `WorldScene.gd`, `ObjectiveTracker.gd` all get non-additive edits to existing
functions) — extra care taken re-reading each diff in full before considering it done.

## Changes Made

- **`data/enemies/martarquas_warleader.tres`** (+ `.uid`) + `EnemyRegistry.gd` entry (both the
  preload-for-APK-packaging const and the hardcoded dict, matching this registry's existing
  dual-representation convention): the war-camp dungeon boss.
- **`data/scripted_battles/scout_ambush.tres`** (+ `.uid`) + `ScriptedBattleRegistry.gd`
  registration: the Chapter 2 spell-tutorial ambush.
- **`scenes/world/entities/ScoutAmbush.gd`** (+ `.tscn`, `.gd.uid`): new trigger entity.
- **`scenes/world/WorldScene.gd`**: `_spawn_scout_ambush()`/`_find_nearby_scout_ambush()` +
  interact wiring; `chapter2_reached_larik` on map-enter; two scroll-id special cases in
  `_on_scroll_collected()`; extended `_handle_king_eldar_interaction()` with the beat-1 charge
  state; new `_check_story_siege_trigger()`; **BID-041 fix** in `_spawn_siege_raiders()`; new
  `_inject_warcamp_boss()` called from the dungeon-load branch of `_ready()`.
- **`game_logic/SiegeDefs.gd`**: `"marsax_hold"` added to `TOWN_GATES`.
- **`autoloads/SceneManager.gd`**: `chapter2_siege_won` hook in the siege-victory branch of
  `_on_battle_won`; `chapter2_warcamp_cleared` + `_show_chapter2_cliffhanger()` hook at the end
  of the normal battle-won path.
- **`assets/maps/marsax_hold.tres`**: war-camp dungeon door gated with
  `flag_key = "chapter2_traitor_seal"`.
- **`game_logic/ObjectiveTracker.gd`**: 7 new Chapter 2 branches; `chapter1_complete` now
  returns "Speak to King Eldar" instead of falling through to the (still-present)
  `chapter1_temple_council` branch.
- **`tests/unit/test_objective_tracker.gd`**: updated the two now-incorrect TID-405 tests
  (`chapter1_complete` no longer means "empty"), added 9 new Chapter 2 tests.
- **`tests/unit/test_scripted_battle_registry.gd`**: 5 new tests (rabbit_hunt + scout_ambush
  registration/validation/completion-flag/spell-card coverage — rabbit_hunt had no registry
  tests yet either, added alongside).
- **New `tests/unit/test_chapter2_content.gd`** (+ `.uid`): 7 tests for the boss `EnemyData`,
  the `SiegeDefs` town gate, and the dungeon-door gating.
- **`tasks/backlog/BID-041...md`** moved to `tasks/archive/backlog/`; `tasks/index.md` updated
  (moved from Backlog to Resolved Backlog).

**Documented simplifications/risks (not fixed, out of scope for this pass):**
- War-camp boss placement (tile 70,30) is a room-layout *heuristic*, not a hard guarantee —
  see the code comment on `_inject_warcamp_boss()`. Worth a visual check once Godot is
  available in a sandbox that has it.
- `scroll_traitor_seal` is collectible immediately, not gated behind `chapter2_siege_won` first.
- No Isfig Chapter 2 cameo (explicitly deferred by the research notes).
- No co-op arbitration anywhere in this task — TID-408's job.

**Validation:** same sandbox constraint as TID-401–406 (no Godot binary, network egress
blocked). This task touched the most existing call sites of any task in the goal
(`SceneManager.gd`, `SiegeDefs.gd`, `WorldScene.gd`, `ObjectiveTracker.gd`); re-read every diff
in full rather than trusting the edit tool's success — no edit-boundary defects found this
round (the class of bug caught in TID-401/402). A human/CI headless run + a playtest of the
Chapter 2 flow (especially the war-camp boss placement) is recommended before merge.

## Documentation Updates

- `docs/agent/story-implementation.md`: new "Chapter 2: The Road to Larik" subsection covering
  all 7 beats, the flag chain, and every documented simplification/deferral above.
