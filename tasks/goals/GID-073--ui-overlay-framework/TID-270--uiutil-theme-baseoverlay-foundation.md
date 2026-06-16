# TID-270: Create UiUtil, UiTheme resource, and BaseOverlay foundation

**Goal:** GID-073
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** claude/GID-073--ui-overlay-framework
**Acquired:** 2026-06-16T20:10:00Z
**Expires:** 2026-06-16T20:40:00Z

## Context

Foundation task — build the shared pieces that the migration tasks consume. No scene migrations here beyond one pilot (SettingsScene, the simplest) to validate the design. This establishes the Theme resource, shared builder utilities, and the BaseOverlay class that all 11 overlay scenes will inherit from.

## Research Notes

**Scaffolding pattern duplicated in:**
- InventoryScene.gd:40–60
- ShopScene.gd:29–46
- SkillTreeScene.gd:37–55 and 181–199 (two overlays in one file)
- CharacterScene.gd:34–53
- JournalScene.gd:23–42
- AchievementsScene.gd:17–35
- CardInspectOverlay.gd (scenes/battle):49–88
- SettingsScene.gd:12–47
- TutorialPopup.gd:18–37

**Pattern structure:** ColorRect backdrop (alphas vary 0.65/0.72/0.78/0.82/0.88) + centered PanelContainer sized from viewport fractions + MarginContainer with 4 margin overrides + VBox.

**Theme overrides per scene:** ~245 total call sites of `add_theme_font_size_override`, `add_theme_constant_override`, `add_theme_color_override`, etc.

**Helper duplication to absorb:**
- CharacterScene._effect_summary (CharacterScene.gd:256–262) vs ShopScene._weapon_effect_summary (ShopScene.gd:283–293) — identical match on battle_effect_type with slightly different wording ("starting mana" vs "mana"); standardize on one wording.
- InventoryScene._rarity_color (InventoryScene.gd:300–306): common (0.80,0.80,0.80), rare (0.20,0.50,1.00), epic (0.70,0.20,1.00), legendary (1.00,0.75,0.00).

**Common sizing idioms to encode as theme/helper defaults:**
- Button: Vector2(_vw*0.08, _vh*0.065)
- Title font: int(_vh*0.032)
- Body font: int(_vh*0.022)
- List separation: int(_vh*0.008)
- 224 instances of _vw/_vh fraction math exist across scenes/ui

**CLAUDE.md constraints:**
- preload() new scripts (no bare class_name reliance)
- Viewport-relative sizing only
- Theme resources must have .uid sidecars (uid:// + 12 random lowercase alphanumerics)
- Use preload() not load() for all resources

## Plan

1. Create `scenes/ui/BaseOverlay.gd` — extends Control; declares `signal closed` and `_vh`/`_vw` vars; provides `_build_backdrop()`, `_build_centered_panel()`, `_build_margin_vbox()` helpers; `_close()` that emits closed; and `_input()` that handles `ui_cancel` → `_close()`.
2. Create `scenes/ui/UiUtil.gd` — static helper file; provides `rarity_color(rarity)`, `effect_summary(weapon)`, `make_title_label(text, vh)`, `make_body_label(text, vh)`, `make_separator()`, `make_close_button(vh, on_pressed)`.
3. Create `assets/ui_theme.tres` + `.uid` sidecar — minimal Theme resource with PanelContainer StyleBoxFlat defaults (bg_color, border, corners), Label font-color defaults.
4. Migrate SettingsScene to extend BaseOverlay (pilot to validate the design).

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
