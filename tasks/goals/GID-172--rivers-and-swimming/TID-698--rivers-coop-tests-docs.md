# TID-698: Co-op sync, tests & docs

**Goal:** GID-172
**Type:** agent
**Status:** pending
**Depends On:** TID-695, TID-697

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Finish the goal: peers see each other swim, everything is tested and documented.

## Research Notes

- Co-op: rivers are deterministic from the session-owned world seed (already synced), so only the swim state needs syncing: add a flag to the avatar payload (AvatarSync / `RemotePlayer`) so remote avatars play swim anim.
- Tests: river determinism, swim speed, stamina drain/regen, drowning → wash ashore at 1 HP, tap-to-move routes through deep water at swim cost, bridges walkable.
- Docs: `docs/agent/world-generation.md` (Rivers section + update eastern-sea table), `camera-and-player.md` (swim state), CLAUDE.md map/module tables if a module is added; profile with `tools/profile_world.gd` before/after.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
