# TID-265: Extract pause & victory overlay managers

**Goal:** GID-071
**Type:** agent
**Status:** pending
**Depends On:** TID-264

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Approximately 360 lines of pause/settings/menu-return and victory/defeat overlay construction are embedded in BattleScene. This includes pause UI (button, settings drawer, return-to-menu confirmation), victory overlays (standard, boss single-phase, boss phase-2, duel victory, duel loss), and associated screen scaffolding. This task extracts these UI flows into two focused manager modules, deduplicates shared overlay scaffolding, and leaves BattleScene responsible only for orchestrating when to show/hide overlays.

## Research Notes

**Pause cluster:** BattleScene.gd:476–703 (~227 lines):
- Pause button setup (480–495): Visible button in HUD that toggles _paused state.
- _show_pause_overlay/_hide_pause_overlay (546–637): Creates/destroys the pause menu panel with Resume/Settings/Return buttons.
- _open_settings_from_pause (639–704): Nested settings overlay (audio/music sliders, save, brightness) and close button.

**Victory cluster:** BattleScene.gd:1390–1685 (~295 lines):
- _show_boss_banner/_check_boss_phase2 (1390–1449): Boss defeat banner, phase transition logic.
- _check_game_over (1450–1488): Checks win/loss state, calls appropriate victory/defeat path.
- _show_victory_overlay (1490–1543): Standard victory (treasure chest UI, new deck count, card selection).
- _show_victory_overlay_boss (1545–1602): Boss-specific victory (epic banner, boss rewards, treasure selector).
- Duel victory/loss overlays (1604–1643): Simpler overlays for duel mode (just result banner + Return button).

**Overlay scaffolding deduplication:** The three victory builders (_show_victory_overlay, _show_victory_overlay_boss, duel overlays) share:
- Black backdrop (CanvasLayer with semi-transparent black rect).
- Central panel (PanelContainer or ColorRect with border).
- Title label.
- Button layout (stack of buttons or single button).
- Tween positioning and modulate alpha for fade-in.

Extract a shared _build_backdrop() and _build_panel(title, content_node, buttons) helper. **NOTE:** GID-073 (UI Overlay Framework) is building a shared BaseOverlay/UiUtil — if it has landed by the time this task runs, build on it; otherwise dedupe locally and leave a note in Research Notes for future cleanup.

**Suggested files:**
- scenes/battle/BattlePauseUI.gd: Owns pause button, pause menu, and nested settings overlay. Called by BattleScene._show_pause_overlay / _hide_pause_overlay.
- scenes/battle/BattleResultUI.gd: Owns victory, defeat, boss victory, duel victory/loss overlays. Called by BattleScene after _check_game_over determines result.

Preload both, don't rely on class_name.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
