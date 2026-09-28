# TID-590: Trainer Flow — Themed Trainers, Level-Up Notice, Learn-for-Gold

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** TID-588, TID-589

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User: "force the player to go to a trainer to get the new ability, make them cost gold so they are forced to read it."
Level-up only makes training *available*; learning happens at a trainer, for gold, after reading the how-to text.

## Research Notes

- Existing trainer (GID-136 / TID-537): `NpcInteractions.show_trainer_panel()` (L155) + `_trainer_row()` (L179), npc
  `trainer_madrian` at madrian (78,44) with `training_dummy_madrian` (81,44); prompt label "TRAIN" in
  `WorldScene._NPC_PROMPT_LABELS`. Panel header text "Strike, Mend and Kick are yours already" must change.
- Generalise to a trainer id: `show_trainer_panel(trainer)` lists `UnlockLadder` rows for that trainer: learned (✓),
  available (full `how_to` text + "Learn — N gold"), locked (grey "Level N"). Learning calls `SaveManager.learn_ability`
  and emits `feature_learned`. Build via `_world._build_modal` + `_UiUtil` factories; long text in a scroll
  (`BaseOverlay._build_scroll` pattern) — sized by viewport fractions.
- Themed trainers (named-map NPCs in `assets/maps/madrian.tres`, place with `WorldMap.pick_free_tile_near_spawn()` if
  injected; update `tests/unit/test_named_map_npcs.gd` counts): combat trainer (existing), Maiteln (magic type,
  companion, skills tab — Maiteln's npc type is story-driven, add a "Training" option rather than replacing dialogue),
  gravedigger (Dig/Phase), stablemaster (mount — existing stable, `Mounts.gd`), bounty master (bounty board NPC).
- Level-up notice: on `training_available`, toast "New training: Mend — see the Combat Trainer" (existing toast path
  used by QuestTracker "New objective" tip) and add a "!" on that trainer: `scenes/world/modules/QuestTracker.gd`
  owns NPC "!"/"?" marks (TID-586) — add trainer-pending marks there. Optionally make the pending training a tracked
  pseudo-quest so compass/beacon/minimap point at the trainer (QuestLog in `game_logic/quests/QuestLog.gd`).
- After learning: spotlight the new button/tab using the TID-553 spotlight (`BattleOnboarding` first-time tips) or
  the world equivalent; first-use tip from `TutorialRegistry` (entries exist for soulbinding, cantrips, tap_to_cast,
  spire_intro, night_hunts — reuse, add missing ones: minions, companion, bounties).
- Soulbinding/veterancy (appeal §7) are not ladder features but should be *mentioned* in the relevant how_to text
  (minions/spells) so the hook is visible early.
- Mobile parity: trainer panel is tap-first; "USE"/interact already reaches NPCs.
- Tests: trainer panel smoke (build with a stub save at several levels), learn deducts coins + adds id, cannot learn
  when broke/underlevel.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
