# TID-017: Pixel-Art Card Frame Shader and BattleScene Integration

**Goal:** GID-008
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
