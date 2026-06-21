# TID-303: Add lerp smoothing to camera follow

**Goal:** GID-084
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`WorldScene.gd:1028` sets `_camera.position = _player.position + Vector3(20, 20, 20)` directly each `_process` frame. On 90/120 Hz displays, this samples the physics body position between ticks, causing micro-stutter.

Fix: maintain a `_smooth_camera_target: Vector3` and lerp toward it each frame with a high speed factor (e.g. 20.0 × delta), so the camera glides smoothly at any refresh rate. Never touch camera rotation per CLAUDE.md.

## Plan

## Changes Made

## Documentation Updates
