# TID-426: Battle Impact Animation Layer — Lunge, Hit-Stop, Death & Card-Travel Tweens

**Goal:** GID-114
**Type:** agent
**Status:** done
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

1. Extend `BattleFx.snapshot()` to also record `zone`/`slot_idx` per card
   entry (additive, backward compatible) so a panel can be relocated later
   even after its `CardInstance` is removed from `ZoneState.slots`.
2. Add to `BattleFx.gd`: `animate_attack()` (lunge toward target + optional
   hit-stop + return, all durations via `scaled_duration()`), `animate_death()`
   (duplicate panel into `_float_layer` as a ghost, shrink/fade/rotate, free),
   `find_panel_by_snapshot_entry()`, and two pure statics — `detect_deaths()`
   (snapshot vs. currently-alive ids → dead ids, hero-safe) and
   `scaled_duration()` (fast-mode scalar, floor at 0.01).
3. Make `_execute_attack()` async: capture pre-mutation panel/target position
   and lethality, `await animate_attack()`, *then* apply damage exactly as
   before, then `await` a shared `_animate_deaths_from_snapshot()` helper
   before `_refresh_all()`. `_attempt_attack()` awaits it.
4. Reuse `_animate_deaths_from_snapshot()` in `_execute_ai_actions()` (covers
   both regular AI and boss AI turns, which share this loop) — death beats for
   AI kills for free via the same diff mechanism; no lunge for AI attacks
   since `BasicAI`'s callables mutate state directly with no attacker/target
   panel exposed to BattleScene (documented scope decision below).
5. Add card-travel: `_hand_panel_node()`, `_hide_hand_panel()`,
   `_slot_panel_center()`, `_animate_card_travel()` in `BattleScene.gd`; wire
   into the two local-player minion-play paths (`_board_drop`'s minion branch,
   `_on_empty_slot_input`'s tap-to-play branch) — capture the hand rect and
   target slot position before the state-mutating call, hide the stale hand
   panel immediately on success, animate, then refresh.
6. Add `tests/unit/test_battle_fx_impact.gd` for the two pure pieces
   (`scaled_duration`, `detect_deaths`) — tween-driven motion itself isn't
   practically assertable headlessly.

No approval pause — research notes fully specified the approach and existing
`_trigger_dual_face_flip`/`_make_card_ghost`/snapshot-diff FX patterns gave a
proven template to extend rather than invent.

## Changes Made

- `scenes/battle/BattleFx.gd`: `snapshot()` now records `zone`/`slot_idx`;
  added `find_panel_by_snapshot_entry()`, `animate_attack()` (lunge + optional
  hit-stop + return, z_index raised during travel), `animate_death()`
  (ghost duplicate shrink/fade/rotate in `_float_layer`), and pure statics
  `detect_deaths()` / `scaled_duration()`. Added a small `get_tree()` proxy
  (`_scene_root.get_tree()`) since `BattleFx extends RefCounted` has none.
- `scenes/battle/BattleScene.gd`:
  - `_execute_attack()` is now async: lunges the attacker (with hit-stop on
    damage ≥5 or lethal hits) before applying damage, then animates any
    resulting death(s) before `_refresh_all()`. `_attempt_attack()` awaits it.
  - `_execute_ai_actions()` awaits the same death-animation helper (covers
    both regular and boss AI turns, which share this loop) — AI-caused kills
    now get the same death beat as player kills, at no extra cost, via
    snapshot diffing (no lunge for AI, see scope note below).
  - Added `_animate_deaths_from_snapshot()`, `_hand_panel_node()`,
    `_hide_hand_panel()`, `_slot_panel_center()`, `_animate_card_travel()`.
  - Wired card-travel into `_board_drop`'s minion-play branch and
    `_on_empty_slot_input`'s tap-to-play branch: hand panel hides immediately
    on a successful play and a ghost tweens from hand to board slot
    (`TRANS_BACK`/`EASE_OUT`, scaled by `_speed_scale`).
- Added `tests/unit/test_battle_fx_impact.gd` (+ `.uid`): 6 tests for
  `scaled_duration` (identity at normal speed, ~halved in fast mode, floored
  above zero) and `detect_deaths` (finds the missing id, ignores hero
  entries, empty when nothing died).
- **Scope decisions (documented per research notes' explicit allowance):**
  - AI-turn attacks get death animation (free via snapshot diff) but not the
    attacker lunge — `BasicAI.decide_turn()`'s callables mutate `GameState`
    directly via closures with no attacker/target panel surfaced to
    `BattleScene`, so there's no single hook point for the lunge without
    restructuring `BasicAI`'s action representation (left as a possible
    follow-up, not filed as a backlog item since it's a deliberate,
    documented v1 scope cut rather than a discovered defect).
  - `_resolve_remote_attack()` (PvP/co-op-PvE-boss intent application on the
    host) is untouched — it has no snapshot/refresh of its own at this call
    site; the caller mirrors whole state to clients afterward. Left
    flash-only for this pass, as explicitly sanctioned by the research notes.
  - Spell plays (`_do_play_card`, non-slot spells) don't get card-travel —
    only minion-to-slot plays have a meaningful "travel to a place" beat.
- **Verification caveat:** same as TID-425 — the Godot 4.6 headless binary
  could not be installed in this session (proxy blocks the GitHub release
  download), so the headless editor import and `tests/runner.gd` were not
  run. This task in particular touches a hot, heavily-branched file
  (`BattleScene.gd`) and converts several call chains to async — it needs a
  real headless compile + a manual playthrough of a battle (attack, minion
  death, card play) before merge.

## Documentation Updates

- `docs/agent/battle-system.md` — added an "Impact animation layer (TID-426)"
  bullet under "BattleScene UI" documenting `animate_attack`/`animate_death`/
  `detect_deaths`/`scaled_duration`, the death-diff mechanism shared by the
  player-attack and AI-turn paths, the card-travel wiring scope, and the
  explicit `_resolve_remote_attack()` scope cut.
