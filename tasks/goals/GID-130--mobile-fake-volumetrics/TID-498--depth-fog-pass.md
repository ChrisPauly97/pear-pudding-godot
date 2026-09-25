# TID-498: Depth-Fog Post Pass

**Goal:** GID-130
**Type:** agent
**Status:** pending
**Depends On:** TID-495

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A camera-attached full-screen spatial pass that reads depth and adds noise-scrolled ground fog lit toward the sun/moon — looks volumetric, costs one pass.

## Research Notes

- Depth reconstruct pattern: `night_light_pool.gdshader` (handles Compatibility NDC).
- Lives in `FakeVolumetrics`; full-screen via `POSITION` in vertex shader, `custom_aabb` to avoid culling.
- Knob `depth_fog` (off/off/on); clamped off when real `volumetric_fog` runs.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
