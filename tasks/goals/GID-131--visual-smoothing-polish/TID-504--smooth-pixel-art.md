# TID-504: Smooth Pixel-Art Sprite Filtering

**Goal:** GID-131
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Nearest-filtered sprites at non-integer scale shimmer/jag as the camera moves.

## Research Notes

`SpriteRegistry` sets `TEXTURE_FILTER_NEAREST` + `ALPHA_CUT_OPAQUE_PREPASS` (depth-sorted, see CLAUDE.md mount learning). Options: linear-with-mipmaps filter, or a fat-pixel shader.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
