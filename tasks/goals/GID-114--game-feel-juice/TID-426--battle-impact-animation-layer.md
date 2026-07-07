# TID-426: Battle Impact Animation Layer — Lunge, Hit-Stop, Death & Card-Travel Tweens

**Goal:** GID-114
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battle already has GID-023's feedback layer (floating damage numbers, hit
flash, screen shake, haptics — all in `scenes/battle/BattleFx.gd`), but the
*motion* layer is missing: state changes apply instantly and the board rebuilds
in the same frame. Attacks feel like spreadsheet updates with a red flash. In
reference TCGs (Hearthstone per the spec's inspirations), the attacker
physically slams into the target — that collision is the core satisfaction
beat of the genre.

Concretely today:
- `_execute_attack()` (scenes/battle/BattleScene.gd:1719) applies damage, then
  `_fx.spawn_float_labels/check_shake` and `_refresh_all()` — all synchronous.
  No attacker movement, no impact pause.
- Dead minions are removed from `ZoneState` and simply absent from the next
  `_refresh_all()` panel rebuild — they vanish with no death animation.
- Playing a card from hand teleports it to the board (panel destroyed in hand,
  recreated in board container). Only dual-face cards get any tween
  (`_trigger_dual_face_flip`, BattleScene.gd:1615 — a `TRANS_BACK` scale-in,
  a good easing reference).
- Enemy AI turns pace themselves with fixed `await` delays (GID-069/TID-254
  added a fast-mode setting that halves them).

## Research Notes

**Where to put it:** extend `scenes/battle/BattleFx.gd` (already owns panels,
`get_card_panel()`, snapshot/diff FX, `_scene_root`). Add async helpers that
BattleScene awaits before mutating state / refreshing:

- `animate_attack(attacker_panel: Control, target_pos: Vector2) -> void`
  (async): tween panel toward target ~60% of the way with `TRANS_QUAD`/EASE_IN
  (~0.12s), then back with EASE_OUT (~0.15s). Raise the panel's `z_index`
  during travel. Because `_refresh_all()` rebuilds panels, run the lunge
  *before* `take_damage()` + refresh — the snapshot/FX flow at
  BattleScene.gd:1719-1750 already captures positions first via
  `_fx.snapshot()`, so the ordering slot exists.
- `animate_death(panel: Control) -> void` (async): scale to 0.1 + fade + slight
  rotation over ~0.25s, then let refresh remove it. Needs to run between
  "target died" detection and `_refresh_all()`; duplicate the panel into
  `_float_layer` (CanvasLayer, BattleFx.gd:11) as a ghost so the live container
  can rebuild immediately — same trick avoids fighting the container layout.
- `animate_card_travel(from_rect: Rect2, to_pos: Vector2, card) -> void`
  (async): spawn a ghost via the existing `_make_card_ghost()` pattern
  (BattleScene.gd:1528 uses it for drag previews) in `_float_layer`, tween
  position+scale hand→slot (~0.2s, TRANS_BACK EASE_OUT), free ghost, refresh.
  Hook into `_do_play_card` (BattleScene.gd:636) and `_do_play_card_at_slot`
  (BattleScene.gd:1049) — note both player-drag and AI paths route through
  these.
- Hit-stop: a ~0.06s `await get_tree().create_timer(...)` at the lunge apex
  before the return tween, only for lethal hits or damage ≥ 5 (same threshold
  `check_shake` uses, BattleFx.gd:311).

**Pacing / settings integration:**
- GID-069/TID-254's battle-speed setting: find the existing delay scalar
  (grep `battle_speed` / `fast` in BattleScene.gd) and multiply every new tween
  duration by it. Fast mode should roughly halve durations.
- All helpers must be safe when panels are freed mid-tween (PvP mirror
  rebuilds, battle end): guard with `is_instance_valid` in every callback —
  see CLAUDE.md freed-instance rules.
- PvP client (`_is_pvp_client()`, BattleScene.gd:1704): state mirrors arrive
  wholesale from the host; keep animations host/solo-side only in the first
  pass, or drive them from the same snapshot-diff BattleFx already uses for
  floats (diff-based death detection works client-side for free).
- Co-op PvE boss turns (`_coop_pve`) reuse `_execute_attack`-adjacent paths
  (`_resolve_remote_attack`, BattleScene.gd:2617) — apply the same lunge there
  or accept flash-only for remote attacks; note the choice in the task.

**Ordering caution:** `_execute_attack` currently emits sounds, mutates state,
and refreshes synchronously; making it `async` means callers
(`_attempt_attack`, AI turn loop) must `await` it. Audit call sites — the AI
loop already awaits between actions so this slots in naturally.

**Tests:** headless tween assertions are brittle; test the pure parts (e.g.
duration-scalar function honors fast mode; death-diff detection returns the
right instance ids from snapshots). Keep animation code paths crash-safe under
headless (no viewport size assumptions — `_vh` is already injected).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
