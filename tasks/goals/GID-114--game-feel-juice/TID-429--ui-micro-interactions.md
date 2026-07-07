# TID-429: UI Micro-Interactions — Button Press Feedback + Click SFX, Drag Lift, Reward Count-Up

**Goal:** GID-114
**Type:** agent
**Status:** pending
**Depends On:** TID-425

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every button in the game — HUD zone actions, Party panel, overlays, menus —
uses stock theme states: no press animation, no sound, no tactile
acknowledgment. During battle, the dragged hand card spawns a ghost preview
(`_make_card_ghost`, BattleScene.gd:1528) but the source panel stays fully
opaque, so it reads as a duplicate rather than a lift. Victory rewards
(GID-069/TID-252's coins/XP presentation in `BattleResultUI.gd`) render as
static labels — no count-up tick, which is the classic dopamine pattern for
reward screens. Overlays snap open; only whole-scene changes get
`TransitionManager`'s 0.2s fade.

Small individually, but this layer is touched on every single input, so it
compounds into the overall impression of a flat, unresponsive app.

## Research Notes

**Global button feedback — one wiring point, not 39 call sites:**
- GID-073 introduced a shared theme + `scenes/ui/BaseOverlay.gd`; GID-107
  introduced `WorldHUD.register_action()`. But buttons are still created in
  many places. The lowest-touch global mechanism: a small autoload-or-static
  helper (e.g. `UiFx.attach(btn)` in `scenes/ui/`) that connects
  `button_down`/`button_up` to a scale tween (pivot-centered, to ~0.93 and
  back, ~0.08s) + `AudioManager.play_sfx("ui_click")` (key from TID-425).
- Wire it centrally where possible:
  - `WorldHUD.register_action()` — covers all registered HUD actions.
  - `BaseOverlay` — add a helper applied to buttons it builds, and attach in
    its existing shared construction paths.
  - Remaining hot spots (menu scene, Party panel, battle End Turn) attach
    explicitly.
- Alternative considered: a global `SceneTree.node_added` listener that
  attaches to every `Button` — simplest coverage, but touches nodes during
  scene construction; evaluate cost during Plan. Either way the effect must be
  idempotent (guard double-attach with `has_meta`).
- Buttons with `toggle_mode` (Ranked toggle etc.) and disabled buttons: skip
  the press sound when `disabled`; `pivot_offset` must be set after sizing
  (use `resized` signal or set at press time from `size * 0.5`).

**Drag lift (battle hand):**
- In `_bind_card_input` / the drag-forwarding lambda (BattleScene.gd:1510-1533):
  on drag start, set source panel `modulate.a ≈ 0.45` and slightly scale the
  ghost preview up (~1.05); restore on `NOTIFICATION_DRAG_END` (the panel
  receives it — or track via `_hand_drag_card` clearing paths). Panels are
  rebuilt by `_refresh_all()` frequently, so restoring state must survive a
  rebuild (rebuild already resets modulate — verify, then rely on it).

**Reward count-up:**
- `scenes/battle/BattleResultUI.gd` builds the victory screen (coins, XP,
  rarity from GID-069/TID-252 — locate the labels by grepping `coins`/`xp`
  there). Replace static text with a tween-driven ticker: 0 → value over
  ~0.5s using `tween_method` writing `"Coins +%d"`, with a `play_sfx("ui_click")`
  tick every few steps (cap total ticks ~8). Respect battle fast-mode scalar
  if trivially accessible.
- Same pattern is reusable for pack-opening if cheap, but packs already have a
  flip ceremony (GID-050) — don't rework it here.

**Overlay open pop:**
- `BaseOverlay` (all overlays inherit or reuse its statics): on open, scale
  the root panel from 0.96→1.0 + fade 0→1 over ~0.12s. One change, every
  overlay benefits. Keep it subtle — mobile-first UI, no bounce that delays
  input. Make sure input isn't swallowed during the pop (don't gate
  `mouse_filter`).

**Accessibility / settings:**
- Reuse the `screen_shake` toggle? No — these are not shakes. But respect
  `haptics` for any new mobile vibration (probably none needed here), and the
  SFX volume already applies to `ui_click` via the shared pool.
- No fixed pixel sizes: all new offsets/scales are relative; fonts via
  existing vh-fraction rules (CLAUDE.md UI sizing).

**Guardrail:** `tests/unit/test_hud_registry_guardrail.gd` fails on new
unreviewed `_hud.add_child(<Button>)` in WorldScene.gd — this task adds no new
buttons, only decorates existing ones, so it should stay green; don't bypass it.

**Tests:** pure-logic pieces (count-up step sequence generator, attach
idempotency via `has_meta`) unit-tested; run full headless suite + editor
import.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
