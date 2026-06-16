# GID-073: UI Overlay Framework & Shared Theme

## Objective

Replace the copy-pasted overlay scaffolding and ~245 per-node theme overrides across 11 UI scenes with a shared UiUtil helper, Theme resource, and BaseOverlay class.

## Context

This goal promotes backlog item BID-009 (tasks/backlog/BID-009--shared-theme-overlay-dedup.md) into actionable work. Every UI overlay builds its whole tree node-by-node in _ready with per-node `add_theme_font_size_override` / `add_theme_constant_override` (~245 call sites total) — hundreds of allocations on the UI thread each time an overlay opens, blocking the frame on Android (the primary platform). The backdrop + centered-panel + margin scaffolding is duplicated across 11 scenes with inconsistent alphas (0.65–0.88) and margins (0.015–0.04). Close/cleanup behavior is inconsistent (some queue_free, some emit closed, some both). 

Related work: Coordinate with GID-064 TID-229 (lambda signal-connection leaks & overlay ownership) and TID-235 (UI scene fixes) — re-verify line numbers if those land first.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-270 | Create UiUtil, UiTheme resource, and BaseOverlay foundation | agent | done | — |
| TID-271 | Migrate the four largest overlays | agent | done | TID-270 |
| TID-272 | Migrate remaining overlays and standardize close/cleanup | agent | done | TID-270 |

## Acceptance Criteria

- [ ] A shared Theme resource (assets/ui_theme.tres with .uid sidecar) exists and is preload()ed in all overlay scenes
- [ ] UiUtil.gd (scenes/ui/UiUtil.gd) provides static builders for backdrop, centered panel, margins, effect summary, and rarity color
- [ ] BaseOverlay.gd (scenes/ui/BaseOverlay.gd) provides shared state (_vw, _vh), signal closed, and standard ui_cancel handling
- [ ] All 11 overlay scenes (InventoryScene, ShopScene, SkillTreeScene, CharacterScene, JournalScene, AchievementsScene, SettingsScene, TutorialPopup, CardInspectOverlay, BiomeSelectionScene, and one pilot) use BaseOverlay and UiUtil
- [ ] Per-scene add_theme_*_override call sites drop by an order of magnitude (from ~245 total to <25)
- [ ] All overlays follow one consistent close/cleanup pattern
- [ ] Visual appearance is preserved (alphas/margins may be standardized deliberately)
- [ ] UI sizing stays viewport-relative per CLAUDE.md guidelines
- [ ] All tests pass headless: `godot --headless --path . -s tests/runner.gd`
- [ ] BID-009 is moved from tasks/backlog/ to tasks/archive/backlog/ and tasks/index.md is updated
