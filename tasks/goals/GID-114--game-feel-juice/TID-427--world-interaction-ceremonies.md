# TID-427: World Interaction Ceremonies — Chest Open, Enemy Engage Beat, Pickup Flourishes

**Goal:** GID-114
**Type:** agent
**Status:** done
**Depends On:** TID-425

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The reward moments of exploration currently resolve with near-zero ceremony:

- **Chest open** (`scenes/world/entities/Chest.gd`): `mark_opened()` →
  `_show_opened()` swaps the body material to a darker brown. No lid motion,
  no particles, no pause. (WorldScene.gd:5050 already plays `chest_open` SFX +
  a 40ms haptic — both currently silent/fine.)
- **Enemy engage** (`scenes/world/entities/EnemyNPC.gd:43 engage()`): the enemy
  sets itself dead, emits `GameBus.enemy_engaged`, and `queue_free()`s itself
  in the same call. The battle transition starts with no alert beat — no "!"
  marker, no micro-pause, no sense of *being caught*. Proximity auto-engage
  (`_on_body_entered`) makes this worse: battles feel like they ambush the
  player out of nowhere.
- **Scroll pickup** (`scenes/world/entities/StoryScroll.gd:42`),
  **dig success**, **door enter**, **waystone travel**: toast + (silent) SFX
  only.

These are the moments that should feel like little rewards; right now they are
state flips.

## Research Notes

**Chest ceremony:**
- `Chest.gd` builds from shared static `BoxMesh` resources (body + gold lock).
  Add a lid: a thin `BoxMesh` `MeshInstance3D` on top; on `mark_opened()`, tween
  its rotation (hinge back ~70° over ~0.3s, `TRANS_BACK` EASE_OUT) — per-instance
  node, so no shared-resource mutation. Then a one-shot `GPUParticles3D` gold
  burst (`one_shot = true`, `emitting = true`, small amount ~12, upward cone,
  gold `Color(0.9, 0.75, 0.1)`) — copy the particle setup pattern from
  `Player.gd:130-148` (`_dust_particles`). Free the particles node after
  lifetime via `get_tree().create_timer`.
- Chests restored as already-opened (`init_from_data` with `opened=true`) must
  show the *final* state without animation — keep `_show_opened()` as the
  instant path, add `animate_open()` only from `mark_opened()`.
- Co-op: `_coop_mark_chest_opened_node` (WorldScene.gd:1520) calls
  `mark_opened()` on peers — the animation plays for them too, which is
  desirable and free.

**Enemy engage beat:**
- In `EnemyNPC.engage()`: before emitting `enemy_engaged`, show an alert —
  a small "!" `Label3D` (billboard, red, positioned above the sprite) popping
  in with a scale tween, plus `AudioManager.play_sfx("enemy_alert")`
  (key registered by TID-425; see BID-045), then a short beat
  (~0.4s `await get_tree().create_timer`) before `GameBus.enemy_engaged.emit`
  + `queue_free()`. Guard re-entry: `engage()` already flips `_alive = false`
  first, so double-fire is safe; keep it that way.
- Caution: `WorldScene` interact path (WorldScene.gd:5021 `enemy.engage()`)
  and proximity path both call the same method — one implementation covers
  both. `Player.gd:44` cancels tap-to-move on `enemy_engaged`; the added delay
  means the player keeps walking ~0.4s during the beat — acceptable (reads as
  "noticed you"), but freeze enemy `tracking` movement during the beat.
- Do NOT touch the co-op siege engage race (BID-044) — same signal, existing
  ordering must be preserved; only delay the *emission*, not reorder listeners.

**Pickup flourishes:**
- StoryScroll: on pickup, tween the scroll sprite upward + fade before
  `queue_free` (currently instant). Same ghost-sprite approach as chest lid —
  animate, then free.
- DigSpot success (`scenes/world/entities/DigSpot.gd`): small dirt-colored
  one-shot particle burst + `dig_success` SFX (new key from TID-425).
- Waystone travel: `waystone_travel` SFX at teleport; the scene fade from
  `TransitionManager` (autoloads/TransitionManager.gd, 0.2s fade) already
  covers the visual.
- Doors: `door_enter` SFX exists at WorldScene.gd:4999/5321/5401 —
  audible once TID-425 lands; no extra work unless trivial.

**Constraints:**
- Node3D has NO `modulate` — tween `Sprite3D`/`Label3D` children only
  (CLAUDE.md "Nocturnal enemy despawn fade" learning).
- All new nodes built in code: viewport-relative sizing rules don't apply to
  3D, but keep `Label3D` `pixel_size` consistent with existing sprites (~0.04).
- Every dict-tracked node read-back must go through
  `WorldScene._valid_node3d()` (CLAUDE.md freed-instance rule).
- Haptics: reuse the existing pattern `Input.vibrate_handheld()` gated on
  `get_setting("haptics", true)` + `OS.has_feature("mobile")`
  (WorldScene.gd:5051, BattleFx.gd:268).
- Run headless import after edits; `Chest.gd`/`EnemyNPC.gd` are preloaded
  transitively by WorldScene — a parse error blues-screens the world.

**Tests:** unit-test what's pure (e.g. engage() still emits `enemy_engaged`
exactly once with the same payload after the beat — await in test via
`await` on the signal). Existing enemy/chest tests in `tests/` must stay green.

## Plan

1. `Chest.gd`: add a per-instance lid hinge (`Node3D` + `MeshInstance3D`,
   distinct name to avoid `find_child("MeshInstance3D")` ambiguity with the
   body mesh) built in `_ready()`. `mark_opened()` → `_animate_open()` tweens
   the hinge open (`TRANS_BACK`/`EASE_OUT`) and spawns a one-shot gold
   `GPUParticles3D` burst; `init_from_data()`/save-restore keeps the instant
   `_show_opened()` path (material + lid snapped open, no tween). Split the
   material swap into `_set_opened_material()` so `_animate_open()` doesn't
   also snap the lid rotation and stomp its own tween.
2. `EnemyNPC.gd`: make `engage()` async — flip `_alive=false` and show a
   billboard `"!"` `Label3D` alert + `enemy_alert` SFX first, `await` a 0.4s
   beat, then do the existing deck/boss resolution + `enemy_engage` SFX +
   `GameBus.enemy_engaged.emit()` + `queue_free()`. No movement to freeze
   (`tracking` only gates the proximity `Area3D`, there's no chase AI yet).
3. `StoryScroll.gd`: `interact()` calls `_animate_pickup()` (tween the node's
   own position/scale, not a material fade — mesh material is a shared
   static resource) before `queue_free()`.
4. `DigSpot.gd`: `dig()` grants the reward synchronously as before, then
   plays `dig_success` and `await`s a one-shot dirt-particle burst before
   `queue_free()`.
5. `SceneManager.teleport_to_waystone()`: play `waystone_travel` SFX at the
   top (covers both the `map:` and `world:` teleport branches).
6. Door SFX (`door_enter`) needed no code change — already wired, just
   silent until TID-425 landed.
7. Update `docs/agent/enemies-and-npcs.md`, `story-narration-scrolls.md`,
   `treasure-maps.md`, `waystone-fast-travel.md`, `inventory-and-deck.md`.

No approval pause — research notes fully specified each ceremony and the
existing chest/particle/tween patterns from TID-425/426/428 were direct
templates.

## Changes Made

- `scenes/world/entities/Chest.gd`: added `_lid_hinge`/`LidMesh` (per-instance,
  distinct name), `_build_lid()`, `_animate_open()` (lid swing + gold burst),
  `_spawn_gold_burst()`, `_set_opened_material()`. `_ready()` re-applies
  `_show_opened()` if the chest was restored already-opened, since
  `init_from_data()` runs *before* `_ready()` (so the lid doesn't exist yet
  when the restore path first calls `_show_opened()`).
- `scenes/world/entities/EnemyNPC.gd`: `engage()` is now async with a 0.4s
  alert beat (`_show_alert()` + `enemy_alert` SFX) before the actual battle
  transition; `_alive` still flips to `false` on the first line, so re-entry
  during the beat stays a safe no-op. Signal *emission* is delayed, not
  listener order (BID-044 co-op siege race untouched).
- `scenes/world/entities/StoryScroll.gd`: `interact()` now floats/shrinks the
  scroll via `_animate_pickup()` before freeing.
- `scenes/world/entities/DigSpot.gd`: `dig()` now bursts dirt particles via
  `_animate_dig_success()` before freeing; reward grant timing unchanged.
- `autoloads/SceneManager.gd`: `teleport_to_waystone()` plays
  `waystone_travel` SFX.
- **Bug caught and fixed during build:** the first draft of
  `Chest._animate_open()` called the (then-single) `_show_opened()` after
  starting the lid tween; `_show_opened()` also set `_lid_hinge.rotation.x`
  directly, which — because a `Tween` reads its "from" value lazily on its
  first tick, not at `tween_property()` call time — made the lid snap open
  instantly instead of animating. Fixed by splitting the material swap into
  `_set_opened_material()` (used by `_animate_open()`) separate from
  `_show_opened()` (material + instant lid snap, restore-path only).
- **Scope/testing note:** no new unit tests — every touched entity
  (`Chest`/`EnemyNPC`/`StoryScroll`/`DigSpot`) is a `Node3D` with heavy
  autoload dependencies (`AudioManager`, `SaveManager`, `GameBus`,
  `SceneManager`, `EnemyRegistry`/`CardRegistry`), which
  `test_hud_registry_guardrail.gd`'s own comment documents as unsuited to
  headless unit instantiation in this codebase (source-text scan preferred
  over live scene-tree tests for exactly this reason) — consistent with
  that precedent, this task adds no test file.
- **Verification caveat:** same as the rest of GID-114 — the Godot headless
  binary could not be installed in this session (proxy blocks the release
  download). This task in particular needs a manual playthrough (open a
  chest, engage an enemy, pick up a scroll, dig a treasure site, fast-travel)
  plus a headless editor import, since none of it is unit-testable per the
  note above.

## Documentation Updates

- `docs/agent/inventory-and-deck.md` — added a "Open ceremony (TID-427)"
  note under "Chest Card Drops".
- `docs/agent/enemies-and-npcs.md` — rewrote the `engage()` method
  description to cover the async alert beat.
- `docs/agent/story-narration-scrolls.md` — updated `interact()` description
  with the pickup flourish.
- `docs/agent/treasure-maps.md` — updated `dig()` description with the
  particle burst + delayed free.
- `docs/agent/waystone-fast-travel.md` — updated the Asset Requirements line
  (was "No audio SFX added in v1").
