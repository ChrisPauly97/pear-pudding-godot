# TID-402: Wilderness Journey Beats — Night Camp, Rabbit-Hunt Tutorial Battle, Fire-Making Morning

**Goal:** GID-108
**Type:** agent
**Status:** done
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

1. **Rabbit-hunt content** (`data/scripted_battles/rabbit_hunt.tres` + `.uid`), using the
   TID-401 `ScriptedBattleData` framework, matching `docs/human/story.md` exactly:
   - `battle_id = "rabbit_hunt"`, `title = "The Rabbit Hunt"`
   - `player_deck_order = ["ghost","skeleton","ghost","zombie","skeleton","ghoul"]`, `opening_hand_count = 1`
   - `enemy_deck_order = ["ghost","ghost"]` (a 2-card token deck), `enemy_opening_hand_count = 1`, `enemy_hero_hp = 8`
   - `tutorial_steps`: turn 1 mana/drag line, turn 2 summoning-sickness line, turn 3 attack line (verbatim from story.md)
   - `reward_card_id = ""` (this is a mandatory teaching beat, not a loot moment), `completion_flag = "chapter1_camp_night"`
   - Register in `ScriptedBattleRegistry.gd` (new const preload + add to `_ensure_loaded()`'s list).
   - **Deviation from Research Notes:** the notes suggested also creating a `wild_rabbit`
     `EnemyData` .tres in `EnemyRegistry`. Skipping this — the TID-401 framework builds
     both sides' decks directly from `ScriptedBattleData` (`enemy_deck_order`), never touching
     `EnemyRegistry`/`EnemyData` for scripted battles. An `EnemyData` resource here would be
     unused/orphaned (the exact "orphaned resource" smell already flagged and fixed once in
     this repo — see BID-004). The enemy's display identity is fully carried by
     `ScriptedBattleData.title`.

2. **New entity** `scenes/world/entities/WildernessCamp.gd` (+ minimal `.tscn`, uid embedded
   inline in the scene header per the `StoryScroll.tscn` precedent — no `.tscn.uid` sidecar
   needed). Procedural visuals in `_ready()` (shared static mesh/material, mirrors
   `StoryScroll._ensure_shared_resources()`): a small log cone + an orange flame cone +
   a warm `OmniLight3D`. Three-stage `interact()`:
   - Stage 1 (`not chapter1_camp_night`): toast flavor line (rain/rabbit/eat-raw), then
     `GameBus.scripted_battle_requested.emit("rabbit_hunt")`.
   - Stage 2 (`chapter1_camp_night` set, `not chapter1_learned_fire`): toast the
     flint-and-tinder line, `SceneManager.save_manager.set_story_flag("chapter1_learned_fire")`,
     then `queue_free()` (narrative purpose served, no reason to linger as an interactable).
   - Stage 3 fallback (both flags already set — stale node from a previous session):
     flavor-only toast, no state change. Defensive only; should be unreachable in practice
     since stage 2 frees itself.
   - Flavor lines go through `GameBus.hud_message_requested.emit(text)` (the existing toast
     signal, e.g. used for "Bag full!") rather than `WorldScene._show_dialogue()` — that method
     is scene-local and not reachable from an entity script, and a toast is sufficient for
     ambient narration here (mirrors the precedent of `StoryScroll` not opening a modal either).

3. **`WorldScene.gd`**: new `_wilderness_camp_node: Node3D = null` field; new
   `_spawn_wilderness_camp()` — called right after `_spawn_open_world_rival_enc2()` (same
   `_is_infinite` branch, same "spawn near player, once per world load" pattern — no fixed
   world position, no `MapData`/`WorldMap` changes needed, exactly mirroring the existing
   rival-encounter precedent). Gated: `chapter1_left_madrian` set, `chapter1_learned_fire` not
   yet set, no existing valid node. New `_find_nearby_wilderness_camp()` mirroring
   `_find_nearby_scroll()`. Wired into `_check_interactions()` (has_entity + `"CAMP"` label,
   satisfies the mobile-parity rule for free since it's the same generic USE-prompt/tap system
   scrolls and shrines already use) and `_handle_interact()` (calls `camp.interact()`).

4. **`game_logic/ObjectiveTracker.gd`**: insert two objectives between the existing
   `chapter1_left_madrian` and `chapter1_warned_farsyth` checks (most-advanced-first order):
   `chapter1_warned_farsyth` (unchanged, checked first) → `chapter1_learned_fire` → "Find Lord
   Farsyth" (farsyth_mansion, 49,20 — moved from the `chapter1_left_madrian` check) →
   `chapter1_camp_night` → "Learn to make fire" (wildcard, main, -1,-1) → `chapter1_left_madrian`
   → "Make camp for the night" (wildcard, main, -1,-1). Update
   `tests/unit/test_objective_tracker.gd`: change `test_left_madrian_returns_find_lord_farsyth`
   to expect "Make camp for the night" for `chapter1_left_madrian` alone; add two new tests for
   `chapter1_camp_night` → "Learn to make fire" and `chapter1_learned_fire` → "Find Lord
   Farsyth"; add the two new flags to the flag lists of all downstream tests (warned_farsyth
   onward) for narrative realism, even though the most-advanced-first check order already makes
   this a no-op for those assertions.

5. **Docs:** update `docs/agent/story-implementation.md`'s "Planned Flags" and
   "Objective Tracking" tables with `chapter1_camp_night` / `chapter1_learned_fire` and the two
   new objective rows; add a short "Wilderness Camp" entry describing the entity/trigger.

6. **Co-op note (per TID-408):** `set_story_flag("chapter1_camp_night" / "chapter1_learned_fire")`
   calls go through `SceneManager.save_manager.set_story_flag()` directly — the same
   unwrapped path every existing Chapter 1 flag site already uses (verified: `chapter1_left_madrian`
   is set the same direct way in `WorldScene._handle_interact()`'s door branch). There is no
   separate co-op-aware wrapper yet anywhere in the codebase; TID-408 is the task that will add
   shared-flag arbitration across all Chapter 1/2 sites at once, not per-task. No co-op-specific
   code added here, consistent with TID-401's precedent.
   Scripted-battle-in-co-op seating (TID-408 rule 2, joint-battle-or-solo-fallback) is likewise
   out of scope for this task — the rabbit hunt currently always fights solo via
   `GameBus.scripted_battle_requested`, which is the documented v1/fallback behavior.

**Validation:** same sandbox constraint as TID-401 — no Godot binary, network egress to fetch
one is blocked by org policy. Careful manual review in place of headless import; a human/CI
run is recommended before merge.

## Changes Made

- **`data/scripted_battles/rabbit_hunt.tres`** (+ `.uid`): the Chapter 1 tutorial battle,
  content matching `docs/human/story.md` exactly (6-card scripted player deck, 2-card fixed
  weak enemy deck, 3 turn-keyed tutorial popups, `completion_flag = "chapter1_camp_night"`).
  Registered in `ScriptedBattleRegistry.gd`.
- **`scenes/world/entities/WildernessCamp.gd`** (+ `.tscn`, `.gd.uid`): new interactable —
  procedural unshaded log/flame visuals (no light, per the `WorldItem.gd` "all geometry is
  unshaded" note); three-stage `interact()` (start rabbit hunt / learn fire + free self /
  stale-node fallback).
- **`scenes/world/WorldScene.gd`**: new `_wilderness_camp_node` field; `_spawn_wilderness_camp()`
  (called alongside `_spawn_open_world_rival_enc2()`) and `_find_nearby_wilderness_camp()`;
  wired into `_check_interactions()` (`"CAMP"` label) and `_handle_interact()`.
- **`game_logic/ObjectiveTracker.gd`**: inserted `chapter1_camp_night` → "Learn to make fire"
  and moved "Find Lord Farsyth" to gate on the new `chapter1_learned_fire` (was
  `chapter1_left_madrian`, which now maps to "Make camp for the night").
- **`tests/unit/test_objective_tracker.gd`**: updated `chapter1_left_madrian` expectation,
  added two new tests for the inserted objectives, threaded the two new flags through all
  downstream tests for narrative realism.
- **`docs/agent/story-implementation.md`**: Planned Flags + Objective Tracking tables updated;
  new "Wilderness Camp" subsection.

**Deviation from Research Notes:** did not create a `wild_rabbit` `EnemyData`/`EnemyRegistry`
entry — the TID-401 scripted-battle framework builds both decks directly from
`ScriptedBattleData`, never touching `EnemyRegistry`, so the resource would be unused/orphaned
(see BID-004 precedent for exactly this smell). Noted inline in `rabbit_hunt.tres`'s Plan entry
and in the doc update.

**Not done in this task:** Maiteln's physical companion presence during the camp beat is
TID-403. Co-op seating for the rabbit hunt and shared-flag arbitration for the two new flags
is TID-408 (not yet landed) — both flags are set through the same unwrapped
`SceneManager.save_manager.set_story_flag()` path every existing Chapter 1 flag already uses.

**Validation:** same sandbox constraint as TID-401 (no Godot binary, network egress to fetch
one blocked). Careful manual review in place of headless import — one real bug was caught this
way: an `Edit` whose `old_string` didn't include `_find_nearby_scroll()`'s trailing `return null`
left that line orphaned as unreachable dead code inside the new `_find_nearby_wilderness_camp()`
function; found and fixed on review, along with the missing `return null` this dropped from
`_find_nearby_scroll` itself. A human/CI headless run is still recommended before merge.

## Documentation Updates

- `docs/agent/story-implementation.md`: Planned Flags table (`chapter1_camp_night`,
  `chapter1_learned_fire`), Objective Tracking table (two new rows), new "Wilderness Camp"
  subsection describing the entity/trigger/battle wiring.
