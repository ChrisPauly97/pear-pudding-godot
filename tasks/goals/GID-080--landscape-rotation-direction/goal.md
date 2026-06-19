# GID-080 — Landscape Rotation Direction

## Problem
On Android, the game is locked to a single landscape orientation because `project.godot` has no `display/window/handheld/orientation` setting. Without it, Godot defaults to one specific landscape direction, preventing players from rotating their device to the other landscape orientation.

## Goal
Add `window/handheld/orientation="sensor_landscape"` to `project.godot` so Android allows both landscape-left and landscape-right.

## Tasks

| Task | Title | Status |
|------|-------|--------|
| [TID-295](TID-295--set-sensor-landscape-orientation.md) | Set sensor_landscape orientation in project.godot | done |
