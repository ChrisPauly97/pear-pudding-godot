# TID-017: Pixel-Art Card Frame Shader and BattleScene Integration

**Goal:** GID-008
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Cards in BattleScene (hand row and board slots) are plain `StyleBoxFlat` coloured panels. This task adds a `canvas_item` shader that draws a pixel-art card frame overlay on top of the card background, and wires it into the BattleScene card creation helpers.

## Research Notes

**Relevant files:**
- `scenes/battle/BattleScene.gd` — `_make_card_panel()` (or equivalent helper) creates card UI nodes; this is where the frame material is applied
- `assets/shaders/` — location for the new `card_frame.gdshader` + its `.uid` sidecar
- `resources/cards/` — `CardData` resource; add `illustration: Texture2D` export field (nullable)
- `docs/agent/battle-system.md` — card rendering description

**Approach:**
1. Create `assets/shaders/card_frame.gdshader` — a `canvas_item` shader that:
   - Draws a coloured fill in the card interior
   - Draws a pixel-art border (thick outer edge, inner bevel) using UV distance from card edges
   - If an `illustration` uniform texture is provided, blends it into the upper ~60% of the card
2. Create companion `assets/shaders/card_frame.gdshader.uid` sidecar (per CLAUDE.md UID rules)
3. In `BattleScene._make_card_panel()`, create a `ShaderMaterial` from the shader, set `base_color` uniform from `CardData` colour, and assign to the card panel's `material`
4. Add `@export var illustration: Texture2D` to `CardData.gd` (nullable — no breaking change)

**UID generation:** `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`

**Card sizing:** cards in hand are sized relative to viewport (already viewport-relative per existing code); shader uses UV coords so sizing is automatic.

## Plan

1. Create `assets/shaders/card_frame.gdshader` — canvas_item shader with `base_color` uniform, pixel-art outer border (dark, ~6% UV) and inner bevel (light top/left, dark bottom/right). Optional illustration sampler in upper 55% of card interior, gated by `has_illustration` bool. `selected` bool flips border to yellow.
2. Create `assets/shaders/card_frame.gdshader.uid` sidecar.
3. Add `@export var illustration: Texture2D` to `data/CardData.gd`; add to `to_template_dict()`.
4. Refactor BattleScene card views from `PanelContainer` to plain `Control` root with two children: `ColorRect` ("FrameRect") with ShaderMaterial, and `MarginContainer` ("ContentMargin") wrapping the VBox.
5. Update `_apply_card_style` to set shader parameters instead of StyleBoxFlat.
6. Update `_update_card_view` to find VBox via named nodes.
7. Fix all type annotations (`PanelContainer` → `Control`) in `_make_card_ghost`, `_refresh_zone`, `_update_card_view`.

## Changes Made

- **`assets/shaders/card_frame.gdshader`** (new) — canvas_item shader with `base_color`, `selected`, `illustration`, `has_illustration` uniforms; draws dark outer border (6.5% UV), light top/left bevel, dark bottom/right bevel, optional illustration in upper 55% of interior
- **`assets/shaders/card_frame.gdshader.uid`** (new) — UID sidecar `uid://mw4yodtyuquy`
- **`data/CardData.gd`** — added `@export var illustration: Texture2D` and wired it into `to_template_dict()`
- **`scenes/battle/BattleScene.gd`** — added `_CardFrameShader` preload; refactored card views from `PanelContainer` to plain `Control` with `FrameRect` (ColorRect + ShaderMaterial) and `ContentMargin` (MarginContainer) children; replaced `_apply_card_style` StyleBoxFlat logic with shader parameter updates; updated all type annotations (`PanelContainer` → `Control`); added `_add_card_frame_children` helper

## Documentation Updates

- **`docs/agent/battle-system.md`** — added "Card Frame Rendering" subsection to BattleScene UI section; updated Asset Requirements table to include shader and illustration fields
