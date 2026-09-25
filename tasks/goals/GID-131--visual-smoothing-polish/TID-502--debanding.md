# TID-502: Debanding

**Goal:** GID-131
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

8-bit phone screens show stepped gradients in sky, fog, mist.

## Research Notes

`Viewport.use_debanding` (Forward+ and Mobile). Knob `debanding` in GraphicsQuality, applied in `apply()`.

## Plan

One knob applied to the viewport.

## Changes Made

- `GraphicsQuality`: `debanding` (off/on/on) → `viewport.use_debanding`.
- Tests: viewport assert + monotonic list.

## Documentation Updates

visual-polish.md: knob row.
