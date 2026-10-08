# TID-697: Swim stamina, currents & drowning

**Goal:** GID-172
**Type:** agent
**Status:** done
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

1. `Swimming.gd`: stamina rules (`step`, `drain_rate`, `depth_at`, `against`), current push, LOW, WASHED_UP_FRAC (user decision: wash up at 1 HP, no other penalty).
2. `Coastline`: stamina tick, river current → `Player.current_push`, low warning, wash-ashore transition, meter.
3. `scenes/world/SwimMeter.gd`: stamina bar projected above the hero (WorldHUD is lint debt — kept out of it).
4. Player: `current_push` added to the target velocity while swimming.
5. Tests: stamina / range / helpers in `test_swimming`; new `tests/swim_smoke.gd` real-scene smoke (added to CI).

## Changes Made

- `game_logic/world/Swimming.gd`: stamina constants + `step`, `drain_rate`, `depth_at`, `against`.
- `scenes/world/modules/Coastline.gd`: `stamina`, current push, `_wash_ashore()` (TransitionManager wipe → `Rivers.nearest_dry`, HP → 1/30, stamina full), `_show_meter`.
- New `scenes/world/SwimMeter.gd`.
- `Player.gd`: `current_push`.
- Tests: `test_swimming` +3; new `tests/swim_smoke.gd`, added to `.github/workflows/tests.yml` scene smokes.
  Suite 3070 pass / 0 SCRIPT ERROR; world, chunk, in-world-battle, swim smokes clean; gdlint + unsafe-hits clean.
- No gasp SFX (no such asset); the low warning is the flashing meter + toast. Logged nothing new.

## Documentation Updates

`docs/agent/camera-and-player.md` (Swimming: stamina table), `world-generation.md` pointer, CLAUDE.md Coastline row.
