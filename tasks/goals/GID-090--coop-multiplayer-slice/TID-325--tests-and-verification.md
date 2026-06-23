# TID-325: Unit test + headless compile + manual 2-instance verification

**Goal:** GID-090
**Type:** agent
**Status:** pending
**Depends On:** TID-323, TID-324

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Prove the slice works. Live ENet networking is hard to assert in an automated
headless run, so this task unit-tests the pure logic (TID-320's `AvatarSync`),
runs the project-wide compile check, and documents/performs the manual two-
instance loopback test that demonstrates the end-to-end feature.

## Research Notes

**Test framework:** tests run via `godot --headless --path . -s tests/runner.gd`
(exit 0 = pass, 1 = fail). New test files live in `tests/` and are registered in
`tests/runner.gd` — open it to see the registration pattern (it lists the suites
it runs). Add `tests/test_coop_sync.gd` and register it.

**What to unit-test (pure, deterministic):**
- `AvatarSync.encode(...)` → `decode(...)` round-trips x/z/flip_h/moving exactly.
- `AvatarSync.interp(current, target, delta, rate)` moves toward target, never
  overshoots (clamped factor), and returns `target` when already there.
- Edge cases: zero delta returns current; large delta clamps to target.
Preload the script under test: `const _AvatarSync =
preload("res://game_logic/net/AvatarSync.gd")`.

**Compile check (CLAUDE.md "Always Validate Compilation"):**
```bash
godot --headless --editor --quit 2>&1 | \
  grep -iE "Parse Error|Compile Error|Failed to load script" | \
  grep -viE "imported/|Make sure resources"
```
Empty output = clean. Run after all GID-090 code is in. Install Godot per CLAUDE.md
"Running Tests: Installing Godot" if the binary is absent (4.4.1-stable).

**Manual 2-instance verification (the real proof):**
1. Launch two Godot instances of the project (`godot --path .` twice, or two
   exported builds).
2. Instance A: main menu → Co-op (Beta) → Host. Confirm it lands in madrian.
3. Instance B: Co-op (Beta) → IP `127.0.0.1` → Join. Confirm it lands in madrian
   and a remote avatar for A appears.
4. Move A's player; confirm B sees A's avatar walk smoothly (interpolated, correct
   facing, walk animation while moving, idle when stopped). Move B; confirm A sees
   it too.
5. Close one instance; confirm the other frees the disconnected avatar
   (`peer_disconnected` / `session_ended` path).
Record the result (and any caveats — e.g. loopback only) in the task's Changes
Made and in the agent doc (TID-326).

**Risks to watch:** RPC path mismatch (NetSync must be same-named on both peers);
both peers must be in madrian before broadcasts start; Y recomputed locally so
terrain height must be available when the avatar spawns.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
