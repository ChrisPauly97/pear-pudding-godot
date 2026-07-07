# TID-429: UI Micro-Interactions — Button Press Feedback + Click SFX, Drag Lift, Reward Count-Up

**Goal:** GID-114
**Type:** agent
**Status:** done
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

1. Add `scenes/ui/UiFx.gd`: `attach(btn)` (idempotent scale-on-press +
   `ui_click` SFX, skips `disabled` buttons) and `pop_in(panel)` (overlay
   open scale+fade).
2. Wire `UiFx.attach()` centrally: `WorldHUD.register_action()` (covers all
   zone-registered HUD actions); the allow-listed hand-built HUD buttons
   (`_siege_btn`, `_auction_btn`, `_draft_duel_btn`, `_tournament_btn`,
   `_ranked_toggle_btn`, `_ping_btn`, `_chat_send_btn` — same set
   `test_hud_registry_guardrail.gd` tracks) explicitly; `UiUtil`'s
   `make_close_button()`/`make_rarity_selector()` factories (covers ~11
   overlay files reusing them); `BaseOverlay._attach_button_fx()` convenience
   wrapper (used by `PartyPanel`'s two button sites); `MenuScene._add_btn()`;
   `BattleScene`'s End Turn/Menu buttons; all 10 "Collect"/"Continue" buttons
   in `BattleResultUI.gd`.
3. Wire `UiFx.pop_in()` into `BaseOverlay._build_centered_panel()` — the
   single choke point ~21 overlay files build their panel through.
4. Drag lift: dim the hand panel to `modulate.a = 0.45` on drag start (in
   `_bind_card_input`'s get-drag-data lambda), scale the ghost preview to
   1.05. Restore in `BattleScene._notification()`'s `NOTIFICATION_DRAG_END`
   branch (fires on drop success, drop failure, and cancel alike) via the
   existing `_hand_panel_node()` lookup (TID-426).
5. **Correctness prerequisite found during Plan/Build:** verified
   `CardViewBuilder.update_card_view()` never resets a reused panel's
   `modulate`/`visible`/`scale` — a panel recycled by index for a *different*
   card would silently inherit the previous card's dim/hide/scale state
   forever. This was already a latent bug from TID-426's `_hide_hand_panel()`
   (sets `visible=false`, never restored on reuse), and would have made
   drag-lift's dim leak the same way. Fixed by resetting all three at the top
   of `update_card_view()` and `_setup_empty_slot_panel()`.
6. Reward count-up: `BattleResultUI.count_up_steps()` (pure, ≤8 steps,
   always ends on target) + `_animate_count_up()` (ticks a label's text with
   a `ui_click` per step); applied to the coin/XP labels in `show_victory()`
   and `show_victory_boss()`.
7. Add `tests/unit/test_ui_fx.gd` (attach idempotency/safety) and
   `tests/unit/test_battle_result_ui_count_up.gd` (count-up step generator).
8. Update `docs/agent/ui-and-scene-management.md` and
   `docs/agent/battle-system.md`.

No approval pause — research notes specified the mechanism and the fallback
options; the one design decision (global `SceneTree.node_added` listener vs.
explicit call-site wiring) was resolved in favor of explicit wiring at named
choke points, since the codebase already has several natural ones
(`register_action`, `UiUtil` factories, `BaseOverlay`) that cover the large
majority of buttons without touching node construction timing.

## Changes Made

- Added `scenes/ui/UiFx.gd` (+ `.uid`): `attach(btn)` and `pop_in(panel)`.
- `scenes/world/WorldHUD.gd`: `register_action()` calls `UiFx.attach(btn)`.
- `scenes/world/WorldScene.gd`: `UiFx.attach()` added to all 7 allow-listed
  hand-built HUD buttons right after construction.
- `scenes/ui/UiUtil.gd`: `make_close_button()` and `make_rarity_selector()`
  call `UiFx.attach()`.
- `scenes/ui/BaseOverlay.gd`: `_build_centered_panel()` calls `UiFx.pop_in()`;
  added `_attach_button_fx(btn)` convenience wrapper for subclasses.
- `scenes/ui/PartyPanel.gd`: both button sites (`_add_action_button`, roster
  friend-request button) call `_attach_button_fx()`.
- `scenes/ui/MenuScene.gd`: `_add_btn()` calls `UiFx.attach()`.
- `scenes/battle/BattleScene.gd`: End Turn/Menu buttons attach `UiFx`; drag
  lift (dim source panel to 0.45 alpha + 1.05-scale ghost on drag start,
  restored on `NOTIFICATION_DRAG_END`).
- `scenes/battle/BattleResultUI.gd`: `count_up_steps()` (pure) +
  `_animate_count_up()`; wired into `show_victory()`/`show_victory_boss()`
  coin/XP labels; `UiFx.attach()` added to all 10 result-screen buttons.
- **Bug found and fixed (not new in this task, but only surfaced by this
  task's drag-lift work):** `scenes/battle/CardViewBuilder.gd`'s
  `update_card_view()` and `_setup_empty_slot_panel()` never reset a reused
  panel's `modulate`/`visible`/`scale`. Board slot panels are stable
  per-slot identities reused indefinitely, and hand panels are reused by
  index — either recycling path could hand a transient per-instance visual
  state (drag-dim, TID-426's hidden-during-travel hand panel, an in-flight
  lunge scale) to a completely unrelated card. Fixed by resetting all three
  at the top of both functions. This retroactively fixes a real (if
  low-probability) bug introduced in TID-426 (`_hide_hand_panel` hiding a
  panel that could then be reused, permanently invisible, for a different
  card in hand).
- Added `tests/unit/test_ui_fx.gd` (+ `.uid`): attach idempotency (no
  duplicate connections on a second `attach()`), meta guard, null-safety.
- Added `tests/unit/test_battle_result_ui_count_up.gd` (+ `.uid`): 6 tests
  for `count_up_steps` (zero/negative target, last step always exact,
  step-count cap, small-target behavior, non-decreasing sequence).
- **Guardrail:** `test_hud_registry_guardrail.gd` should stay green — no new
  `_hud.add_child(<Button>)` call sites were added, only `UiFx.attach()`
  lines after existing ones.
- **Verification caveat:** same as the rest of GID-114 — the Godot headless
  binary could not be installed in this session (proxy blocks the release
  download). This task touches the widest surface area of the goal (10+
  files) for a purely additive, low-risk change (idempotent attach calls),
  but still needs a headless editor import, the full `tests/runner.gd` suite
  (especially `test_hud_registry_guardrail.gd` and the two new test files),
  and a manual pass over HUD buttons/overlays/battle drag/victory screen
  before merge.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md` — new "Button press feedback +
  overlay pop" subsection under "HUD Action Registry & Party Panel".
- `docs/agent/battle-system.md` — added a "Drag lift + reward count-up"
  bullet under "BattleScene UI".
