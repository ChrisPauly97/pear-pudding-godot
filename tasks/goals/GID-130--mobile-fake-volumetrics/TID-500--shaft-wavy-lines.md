# TID-500: Fix Wavy Lines in Fake Light Shafts

**Goal:** GID-130
**Type:** agent
**Status:** done
**Depends On:** TID-495

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User report after device testing (2026-09-25): "weird wavy lines", seen once. The fake light shafts only show in the short dawn/dusk window, which fits a one-off sighting.

## Research Notes

`fake_light_shaft.gdshader` multiplied each beam by `0.75 + 0.25 * sin(UV.y * 22 - TIME * 0.7)`: 3–4 bright/dark bands per beam crawling along it, and 10 parallel beams on screen read as moving wavy stripes.

## Plan

Replace the band with one slow, low-contrast swell per beam; soften the breathe term.

## Changes Made

- `assets/shaders/fake_light_shaft.gdshader`: motes `0.92 + 0.08 * sin(UV.y * 3 - TIME * 0.25 + seed)`, breathe `0.85 + 0.15 * sin(...)`. Compile-checked on gl_compatibility.

## Documentation Updates

visual-polish.md: shaft description no longer mentions drifting motes bands.
