# TID-402: Wilderness Journey Beats — Night Camp, Rabbit-Hunt Tutorial Battle, Fire-Making Morning

**Goal:** GID-108
**Type:** agent
**Status:** pending
**Depends On:** TID-401

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Story beats 2–3 (night camp with rabbit hunt; fire-making lesson next morning) exist only as text in docs/human/story.md. This task makes them playable: a scripted campfire event on the open-world road after leaving Madrian, containing the game's first battle — the rabbit-hunt tutorial (fixed deck, 1-by-1 draw) — followed by the fire-making morning dialogue.

## Research Notes

- **Beat definitions:** docs/human/story.md — "Chapter 1: Into the Wild World" beats 2–3 and "Wilderness Encounters (Between Named Maps)" (rabbit hunt = weak enemy encounter; fire tutorial = simple dialogue, no combat).
- **Open-world scripted spawn precedent:** scenes/world/WorldScene.gd `_spawn_open_world_rival_enc2()` (~line 2897) — gates on story flags, spawns near the player at a tile offset, uses `_spawn_rival_at` with an edata Dictionary (id, x, z, enemy_type, enemy_deck, pre_battle_dialogue). The camp event should follow the same gating pattern: after `chapter1_left_madrian`, before `chapter1_camp_night`, when the player is in the open world (`map_name == "main"`).
- **New enemy:** create a `wild_rabbit` EnemyData .tres in data/enemies/ (8 hero HP, 2-card token deck that plays one weak minion per turn), preload-registered in autoloads/EnemyRegistry.gd (const preload + registry dict, same as existing enemies). Needs .uid sidecar.
- **Scripted battle:** create the rabbit-hunt ScriptedBattleData .tres using the TID-401 framework: player deck order ghost → skeleton → ghost → zombie → skeleton → ghoul (6 cards, all existing base card IDs in CardRegistry), opening hand 1, Maiteln tutorial popup lines (turn 1: play the ghost / mana; turn 2: summoning sickness; turn 3: attacking; then finish).
- **Flags:** victory sets `chapter1_camp_night`; the next-morning fire-making dialogue interaction sets `chapter1_learned_fire`. Set via `SceneManager.save_manager.set_story_flag(...)`; extend game_logic/ObjectiveTracker.gd to insert these two steps between `chapter1_left_madrian` ("Make camp for the night", wildcard coords -1,-1) and the existing `chapter1_warned_farsyth` objective. Update tests/unit/test_objective_tracker.gd for the new progression order.
- **Camp presentation:** campfire = simple Node3D prop (CPU ArrayMesh or Sprite3D, see visual-polish patterns in docs/agent/visual-polish.md); interactable pattern: see StoryScroll (scenes/world/entities/StoryScroll.gd) for a tap/interact entity with dialogue.
- **Day/night:** the game has a day/night cycle (SaveManager time of day); the beat may simply narrate nightfall rather than forcing clock changes — keep scope small.
- Mobile parity rule (CLAUDE.md): any interaction needs a tap target, not just a key.

- **Co-op (up to 4 players):** this feature must follow the TID-408 design rules (shared-flag arbitration via SessionState, exactly-once beat effects, authority-broadcast narration, single synced Maiteln, no write-through to solo saves). Read TID-408--coop-story-compatibility.md before Plan.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
