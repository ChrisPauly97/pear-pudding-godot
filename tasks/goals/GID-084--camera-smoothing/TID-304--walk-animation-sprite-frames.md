# TID-304: Migrate walk animation to AnimatedSprite3D/SpriteFrames

**Goal:** GID-084
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`Player.gd:72-76` manually advances a frame index each `_physics_process` tick to simulate a 4-frame walk animation. Godot's `AnimatedSprite3D` with a `SpriteFrames` resource handles frame timing natively and is the correct pattern.

The migration should preserve the existing sprite sheet layout and frame count; only the driving code changes.

## Plan

## Changes Made

## Documentation Updates
