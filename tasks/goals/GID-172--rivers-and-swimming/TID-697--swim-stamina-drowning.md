# TID-697: Swim stamina, currents & drowning

**Goal:** GID-172
**Type:** agent
**Status:** pending
**Depends On:** TID-696

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Swimming far out must be risky: the hero tires and can drown.

## Research Notes

- Pure `game_logic/world/SwimStamina.gd`: drain/s grows with distance from shore (`Coast.depth`, river distance to bank) and with swimming against `Rivers.flow`; regen on land. All tuning as consts at the top.
- River current drags the swimmer downstream (add flow × k to velocity in Player).
- HUD: stamina bar shown only while swimming / refilling — mirror HeroHealth's HP bar (`scenes/world/modules/HeroHealth.gd`); low-stamina pulse + gasp SFX. Sizes relative to viewport.
- Exhaustion (user decision): screen fade, hero washes up on the nearest shore (`Coast.to_land` for sea; nearest bank tile for rivers) with HP set to 1 via `HeroVitality`, no gold/item loss; short toast "You washed ashore, exhausted."
- Not persisted (resets on land) — no SaveManager field needed.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
