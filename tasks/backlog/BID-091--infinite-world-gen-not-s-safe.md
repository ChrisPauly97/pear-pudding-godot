# BID-091: InfiniteWorldGen `-s` compile (fixed) and the landmark ruin-roll mask (open)

**Category:** code-smell
**Discovered During:** GID-173 / TID-699

## Description

`game_logic/world/InfiniteWorldGen.gd` calls `IsoConst.tile_center(...)` (a function) without a file-local
`const IsoConst = preload("res://autoloads/IsoConst.gd")`. CLAUDE.md: constants resolve in `-s` runs, functions
don't. So any `godot -s` script that preloads InfiniteWorldGen fails to compile, and the SceneTree then never quits
(the run hangs until killed) — easy to mistake for a slow generator.

## Evidence

`godot --headless --path . -s <probe that preloads InfiniteWorldGen>` →
`Compile Error: Identifier not found: IsoConst at InfiniteWorldGen.gd:119`.

## Suggested Resolution

Add the file-local IsoConst preload to InfiniteWorldGen (and check `landmark_for_chunk`'s ruin-roll replica, which
masks the seed with `& 0x7FFFFFFF` while `RuinGen.has_ruin` does not — for negative chunk seeds the two can disagree,
so a landmark can land on a ruin chunk).

## Status

The `-s` compile half was fixed in TID-699 (file-local IsoConst preload). The mask half stays open: fixing it
moves landmarks in existing worlds, so it needs a decision (and maybe a save migration for discovered landmarks).
