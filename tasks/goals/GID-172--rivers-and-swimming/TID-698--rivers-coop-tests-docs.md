# TID-698: Co-op sync, tests & docs

**Goal:** GID-172
**Type:** agent
**Status:** done
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

Co-op: derive a remote avatar's swimming from its position (`Swimming.deep_at`; rivers and sea are fixed geography) —
no wire flag, older peers stay compatible. RemotePlayer sinks + swim/tread anims. Tests: extend `swim_smoke` with a
RemotePlayer in deep water and on land; re-run the suite, smokes, net_coop_smoke, profiler; docs.

## Changes Made

- `Swimming.deep_at(wx, wz)`; `Coastline._deep` uses it, and only looks up the swim depth while swimming
  (per-frame water checks measured 10–50 µs; depth lookup now skipped on land).
- `RemotePlayer.gd`: public `swimming`, sprite sink, `HeroAnim.pick(.., swimming)` for swim / tread.
- `tests/swim_smoke.gd`: remote avatar swims in deep water, idles on land.
- Verified: suite 3070 pass / 0 SCRIPT ERROR; world, town, swim, net_coop smokes clean; gdlint + unsafe-hits clean;
  profiler p50 6.90 ms (unchanged), p95 noisy 7.8–8.7 ms across runs.

## Documentation Updates

`docs/agent/multiplayer-coop.md` (Swimming under Remote avatars); `world-generation.md` pointer.
