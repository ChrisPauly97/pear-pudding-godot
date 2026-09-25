# TID-526: Hero Touches

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Hero lacks walk bob and interact feedback.

## Research Notes

CharacterPresence (idle breathe/bob), SpriteOutline, `_check_interactions` prompt.

## Plan

Stepped walk bob on passing frames + occasional idle breath (whole pixels); outline warms to gold and pulses while an interact prompt is up.

## Changes Made

IdleLife.hero_bob; Player.visual_bob in snap_visuals_to_pixels; SpriteOutline.set_glow/GLOW_COLOR; WorldHUD.interact_prompt_visible; CharacterPresence._update_hero (+test_hero_touches). Also fixed the Ley-Attuned chip stretching across the screen (explicit rect).

## Documentation Updates

visual-polish.md.
