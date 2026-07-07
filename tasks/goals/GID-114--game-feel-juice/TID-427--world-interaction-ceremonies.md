# TID-427: World Interaction Ceremonies — Chest Open, Enemy Engage Beat, Pickup Flourishes

**Goal:** GID-114
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
