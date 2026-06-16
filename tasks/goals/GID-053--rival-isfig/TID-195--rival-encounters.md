# TID-195: Rival Encounters — Spawning, Dialogue, Battle Wiring

**Goal:** GID-053
**Type:** agent
**Status:** done
**Depends On:** TID-194

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Wires the three rival framework decks into the story's named maps at the correct beats, with gating logic and dialogue, reusing the standard enemy-engagement flow.

## Research Notes

- **Story flag sequence** (cite **docs/agent/story-implementation.md** line 35–45):
  - `story_intro_complete` — set after Maiteln dialogue in Madrian
  - `chapter1_left_madrian` — set when player exits Madrian map (Encounter 1 available after this)
  - `chapter1_warned_farsyth` — set when player speaks to Lord Farsyth in farsyth_mansion
  - `chapter1_received_letter` — set when Isfig open-world encounter triggers (currently non-combat; will become Encounter 2)
  - `chapter1_reached_blancogov` — set when player enters blancogov map (Encounter 3 available after this)
  - `chapter1_temple_council` — set when player speaks to King Eldar in blancogov_temple (final showdown unlocks after both this AND prior encounter wins)

- **Encounter 1: After `chapter1_left_madrian`** — trigger on entry to `maykalene` map.
  - Isfig spawns as an ENEMY entity in the maykalene map (not as an NPC; he is hostile).
  - Map entity line: `ENEMY x z rival_isfig_1` (cite **docs/agent/named-maps-and-dungeons.md** for entity syntax; worldmap parser passes enemy type to EnemyNPC instantiation).
  - Pre-battle dialogue: "You again? Let's see if you're worth the effort, wee warrior." (single line shown before the enemy is engaged, cite **enemies-and-npcs.md** line 70–80 EnemyNPC.get_dialogue or add a _pre_battle_dialogue field if NPC dialogue is for TownspersonNPC only).
  - Battle trigger: standard **GameBus.enemy_engaged** flow (cite **autoloads/GameBus.gd** line 4 and **enemies-and-npcs.md** line 83 for engagement).
  - On win: increment SaveManager.rival_encounters_won to 1 (wired in SceneManager._on_battle_won, cite line 253 where enemy_type extracted at line 258 — rival battles will have enemy_type="rival_isfig_1" or similar; detect via `enemy_type.starts_with("rival_")`).
  - Defeat prevention: rival enemies must NOT enter `defeated_enemies` on loss (cite **enemies-and-npcs.md** line 108–112 spawn persistence and SceneManager line 264 mark_enemy_defeated). Add a flag to EnemyData or check the type at line 264: `if not enemy_type.starts_with("rival_"): save_manager.mark_enemy_defeated(...)`.
  - On loss: no message; player can retry (enemy remains in place for next entry).

- **Encounter 2: `chapter1_received_letter` flag** — merge into the existing open-world encounter currently scripted as "Isfig delivers a letter on the road."
  - This beat is between Maykalene (farsyth_mansion) and Blancogov. Check if it's implemented as a named map (cite `assets/maps/*.txt` files) or as a scripted trigger in WorldScene.
  - If it's a named map: add ENEMY directive; if it's a scripted event: replace the NPC dialogue with battle engagement.
  - Pre-battle dialogue (if the encounter can show text before battle): "Maiteln's sent word of the Martarquas. I aim to warn him you're no mere apprentice." (mocking but respectful).
  - On win: increment SaveManager.rival_encounters_won to 2.
  - On loss: retry enabled.

- **Encounter 3: Locked until `chapter1_reached_blancogov` AND `chapter1_temple_council` AND `rival_encounters_won >= 2`** — staged in blancogov_temple map.
  - Map entity line: `ENEMY x z rival_isfig_3` (conditional visibility — cite **story-implementation.md** line 55–60 on NPC flag-gated dialogue; check if entity-level visibility gating exists in **WorldMap** parser or **WorldScene._spawn_entities**).
  - If entity visibility gating does NOT exist: add it. Mechanism: extend map entity syntax to `ENEMY x z type FLAG:flag_key` (parallel to NPC syntax) or use a helper function in **WorldScene** to hide/show entities post-spawn based on save flags.
  - Pre-battle dialogue: "Maiteln warned me you'd come far. Perhaps it's time I stood beside him, not against."
  - On win: set SaveManager.rival_defeated = true; increment rival_encounters_won to 3 (or just set it since it's the last encounter). Proceed to TID-196 for reward logic.

- **Dialogue implementation** — EnemyNPC is currently non-interactive (cite **enemies-and-npcs.md** line 67–88 describes EnemyNPC.gd state machine; wander/track/engage). Pre-battle dialogue for rivals:
  - Option A: Add a `_pre_battle_dialogue: String` field to EnemyData and show it in WorldScene._on_enemy_engaged() before emitting `GameBus.enemy_engaged`.
  - Option B: Hard-code dialogue in EnemyNPC.gd if enemy_type.starts_with("rival_"), using a static dialogue map indexed by type.
  - Recommend Option A for data-driven consistency.

- **Battle flow** — cite **autoloads/SceneManager.gd** line 226–244 (_on_enemy_engaged) and line 253–300 (_on_battle_won):
  - Rival battles follow the same flow as standard enemy battles: GameBus.enemy_engaged → BattleScene overlays → GameBus.battle_won/lost.
  - enemy_type from pending_battle_enemy_data (line 258) will be "rival_isfig_1/2/3".
  - At line 264, add guard: `if not enemy_type.starts_with("rival_"): save_manager.mark_enemy_defeated(...)` so rivals don't enter defeated_enemies and can be re-fought.
  - On win, detect rival via type name and call `save_manager.rival_encounters_won += 1` (or directly set after checking current encounter count).

- **Retry on loss** — standard behavior; defeated_enemies not updated means enemy stays in place.

- **Tests (headless)** — in **tests/test_rival_encounters.gd**:
  - Test story-flag-to-encounter availability: `chapter1_left_madrian` set → Encounter 1 available; `chapter1_received_letter` set → Encounter 2 available; full conditions → Encounter 3 available.
  - Test NPC type detection in battle: create a mock battle_won signal with enemy_type="rival_isfig_1", verify rival_encounters_won incremented.
  - Test retry: simulate loss, verify defeated_enemies NOT updated.

## Plan

1. Add `const RivalSystem` preload to `WorldScene.gd`
2. Add `_spawn_named_map_rivals()` — checks flags, spawns rival_enc1 in maykalene and rival_enc3 in blancogov_temple
3. Add `_spawn_open_world_rival_enc2()` — spawns rival in infinite world when chapter1_warned_farsyth set and chapter1_received_letter not set
4. Add `_spawn_rival()` and `_spawn_rival_at()` helpers (instantiate EnemyNPC, register in `_enemy_nodes`)
5. Call `_spawn_named_map_rivals()` from named-map branch of `_ready()` and `_spawn_open_world_rival_enc2()` from infinite branch
6. Set `chapter1_reached_blancogov` on entry to blancogov/blancogov_temple in `_ready()`
7. Modify `_handle_interact()` to show `pre_battle_dialogue` from enemy_data before calling `engage()`
8. In `SceneManager._on_battle_won()`: add `is_rival` guard to skip `mark_enemy_defeated` + add rival win tracking
9. Create `tests/unit/test_rival_encounters.gd` (21 tests)
10. Register new test suite in `tests/runner.gd`

## Changes Made

- `scenes/world/WorldScene.gd`:
  - Added `const RivalSystem = preload("res://game_logic/RivalSystem.gd")`
  - Added `_spawn_named_map_rivals()` — flag-gated spawn of rival_enc1 in maykalene (rival_isfig_1, after `chapter1_left_madrian`, wins==0) and rival_enc3 in blancogov_temple (rival_isfig_3, after `chapter1_temple_council`, wins>=2, not defeated)
  - Added `_spawn_open_world_rival_enc2()` — spawns rival near player in infinite world when `chapter1_warned_farsyth` set and `chapter1_received_letter` NOT set
  - Added `_spawn_rival()` and `_spawn_rival_at()` helpers
  - Called `_spawn_named_map_rivals()` from named-map `_ready()` path (after waystones)
  - Called `_spawn_open_world_rival_enc2()` from infinite-world `_ready()` path (after sync inner chunks)
  - Added `chapter1_reached_blancogov` flag set on entry to blancogov/blancogov_temple
  - Modified `_handle_interact()` to show `pre_battle_dialogue` from enemy_data before `engage()` for rival enemy types
- `autoloads/SceneManager.gd`:
  - In `_on_battle_won()`: `is_rival` bool from `enemy_type.begins_with("rival_")`; rivals skip `mark_enemy_defeated`, skip `record_enemy_defeated`/bounty; capture `captured_enemy_id` before clearing
  - After coins/XP: rival win block — enc3 calls `set_rival_defeated()`, others call `record_rival_win()`; enc2 (captured_enemy_id=="rival_enc2") sets `chapter1_received_letter`; emits `GameBus.rival_encounter_won`
- Created `tests/unit/test_rival_encounters.gd` — 21 tests covering flag gate conditions, win transitions, defeat immunity, tier selection
- `tests/runner.gd` — registered `test_rival_encounters.gd`

## Documentation Updates

No new agent docs needed — rival system is covered in existing enemies-and-npcs.md and story-implementation.md context. TID-196 will add journal entry documentation.
