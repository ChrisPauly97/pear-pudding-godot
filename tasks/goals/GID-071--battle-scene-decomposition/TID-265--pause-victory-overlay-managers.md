# TID-265: Extract pause & victory overlay managers

**Goal:** GID-071
**Type:** agent
**Status:** done
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

1. Create `scenes/battle/BattlePauseUI.gd` — owns pause button, pause menu CanvasLayer, Resume/Settings/Flee/Return buttons, nested SettingsScene drawer, confirm-return dialog. API: `setup(parent, vh, float_layer, make_save_fn)`, `add_pause_button(side_panel)`, `is_paused()`, `toggle()`, `show_pause()`, `hide_pause()`.
2. Create `scenes/battle/BattleResultUI.gd` — owns boss banner, phase-2 banner, and all victory/defeat overlays. Delegates rarity color to `UiUtil.rarity_color()`. API: `setup(parent, vh, float_layer, collect_veterancy_fn)`, `show_boss_banner(enemy_data)`, `show_phase2_banner()`, `start_banner_fade(banner)`, `show_victory(...)`, `show_victory_boss(...)`, `show_soulbind(...)`, `show_duel_victory(wager)`, `show_duel_loss(wager)`, `show_puzzle_fail_overlay(hint_text)`, `show_puzzle_victory_overlay()`.
3. Update `BattleScene.gd` — preload both modules; initialize in `_ready()`; replace all extracted method calls with delegating calls; fix stale-state bug in `_show_puzzle_fail()` (call `_resolver.setup(_state)` + `_view.set_battle_state(_state, enemy_data)` after reset); remove all extracted methods.
4. Create .uid sidecars for both new files.

## Changes Made

- **NEW** `scenes/battle/BattlePauseUI.gd` — manages pause button, pause CanvasLayer overlay, Resume/Settings/Flee/Return buttons, SettingsScene drawer, confirm-return dialog
- **NEW** `scenes/battle/BattlePauseUI.gd.uid` — sidecar UID
- **NEW** `scenes/battle/BattleResultUI.gd` — manages boss banner, phase-2 banner, all victory/defeat/puzzle overlays; delegates rarity color to `UiUtil.rarity_color()`; accepts `hero_hp` param for Spire run HP persistence
- **NEW** `scenes/battle/BattleResultUI.gd.uid` — sidecar UID
- **MODIFIED** `scenes/battle/BattleScene.gd`:
  - Added preloads for BattlePauseUI and BattleResultUI; removed SettingsScene preload
  - Removed member vars `_paused`, `_pause_overlay`, `_boss_banner`, `_BOSS_BANNER_DURATION`
  - Added `_pause_ui: BattlePauseUI` and `_result_ui: BattleResultUI` member vars
  - `_ready()`: instantiate and setup both managers right after resolver creation; wire `_menu_btn` → `_pause_ui.confirm_return_to_menu`; call `_pause_ui.add_pause_button($SidePanel)` instead of `_add_pause_button()`; replace `_show_boss_banner()` → `_result_ui.show_boss_banner(enemy_data)`
  - `_input`: `_toggle_pause()` → `_pause_ui.toggle()`
  - `_notification`: `_show_pause_overlay()` → `_pause_ui.show_pause()`; checks `_pause_ui.is_paused()` guard
  - `_check_boss_phase2`: phase-2 banner inline removed → `_result_ui.show_phase2_banner()`
  - `_check_game_over`: all overlay calls delegated to `_result_ui.*`; `hero_hp_win` captured for Spire HP
  - `_show_puzzle_fail`: state reset + `_resolver.setup(_state)` + `_view.set_battle_state(...)` retained; overlay delegated to `_result_ui.show_puzzle_fail_overlay(hint_text)`
  - `_show_puzzle_victory`: kept `GameBus.puzzle_solved.emit(...)`; overlay delegated to `_result_ui.show_puzzle_victory_overlay()`
  - Removed methods: `_add_pause_button`, `_toggle_pause`, `_show_pause_overlay`, `_on_flee_pressed`, `_hide_pause_overlay`, `_open_settings_from_pause`, `_confirm_return_to_menu`, `_show_boss_banner`, `_start_banner_fade`, `_show_victory_overlay`, `_rarity_color`, `_show_soulbind_overlay`, `_show_victory_overlay_boss`, `_show_duel_victory_overlay`, `_show_duel_loss_overlay`

## Documentation Updates

- `docs/agent/battle-system.md`: added BattlePauseUI and BattleResultUI subsections before "BattleScene UI"; documented all public APIs, wiring, stale-state fix for puzzle reset, hero_hp parameter rationale
