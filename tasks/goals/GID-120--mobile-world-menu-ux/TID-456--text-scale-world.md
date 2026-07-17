# TID-456: text_scale Outside Battle + Tiny-Font Sweep

**Goal:** GID-120
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

GID-119 wired `text_scale` into the battle UI only. `UiUtil.make_title_label` /
`make_body_label` (used across overlays), WorldHUD text (dialogue, tips, coins,
labels), and AchievementToast (desc at 1.7% vh) ignore it.

## Plan

1. `UiUtil.text_scale()` static helper — resolves SaveManager via
   `Engine.get_main_loop()` root lookup (safe in static context), clamped 0.5–2.0.
2. Multiply in `make_title_label` / `make_body_label`.
3. WorldHUD: scale font sites through a `_font(pct)` member helper.
4. AchievementToast: desc font raised to 2% vh and scaled.

## Changes Made

- `UiUtil.text_scale()`; title/body helpers scaled.
- `WorldHUD._font()` + all its font-size overrides converted.
- `AchievementToast` fonts raised/scaled.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md`: text_scale coverage note updated.
