# TID-501: FXAA / TAA Edge Smoothing

**Goal:** GID-131
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

MSAA misses alpha-cut sprite edges and shader-drawn edges.

## Research Notes

`GraphicsQuality.apply()` writes viewport MSAA. Add `screen_space_aa` (Viewport.SCREEN_SPACE_AA_FXAA; all renderers) and `taa` (Forward+ only → FORWARD_PLUS_ONLY).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
