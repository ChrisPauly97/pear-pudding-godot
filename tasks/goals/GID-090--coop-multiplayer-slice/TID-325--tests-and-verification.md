# TID-325: Unit test + headless compile + manual 2-instance verification

**Goal:** GID-090
**Type:** agent
**Status:** done
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

1. Confirm `tests/unit/test_coop_sync.gd` (added in TID-320) is auto-discovered and
   passes — no runner registration needed (runner auto-discovers `tests/unit/test_*.gd`).
2. Run the project-wide headless compile check — must be empty.
3. Write `tests/net_coop_smoke.gd` — a standalone `SceneTree` script that proves
   real ENet loopback + the actual `NetSync.gd` RPC + `AvatarSync` payload end to
   end in one process: two `SceneMultiplayer` instances (server + client) on
   127.0.0.1, two `WorldScene/NetSync` subtrees at matching relative paths, poll
   until connected, server `rpc("recv_avatar", payload)`, assert the client's
   stub world-scene receives and decodes it. Exit 0 on success.
4. Run the smoke test; record the result. If the sandbox blocks loopback sockets,
   note that and fall back to the documented manual procedure.
5. Document the manual two-instance procedure + observed/automated results in
   Changes Made for TID-326 to fold into the agent doc.

## Changes Made

- Verified `tests/unit/test_coop_sync.gd` (13 cases, added in TID-320) is
  auto-discovered and passes — no runner registration needed.
- Headless compile check (`--editor --quit`) is clean (empty output).
- Full unit suite: **1530 passed, 0 failed, 1 pending**.
- Created `tests/net_coop_smoke.gd` (+ editor `.gd.uid`) — a standalone `SceneTree`
  script that drives a **real ENet loopback session** in one process: server +
  client `SceneMultiplayer` on `127.0.0.1:24567`, two `WorldScene/NetSync`
  subtrees at matching relative paths, polls until connected, then the server
  `rpc("recv_avatar", payload)` and the client asserts it received + decoded the
  packet via the real `NetSync.gd` + `AvatarSync`. Run on demand:
  `godot --headless --path . -s tests/net_coop_smoke.gd` (exit 0 = pass).
  Result: **PASS** — "ENet loopback connected (server sees 1 peer)" and
  "avatar packet received and decoded correctly". (Needed a one-frame `await`
  so added nodes are inside_tree before RPC path resolution.)
- This automated smoke test covers the previously manual-only risks: RPC path
  matching across peers and payload round-trip over a live socket.

**Manual two-instance procedure (visual, for a human — recommended before release):**
1. `godot --path .` twice (or two exported builds).
2. Instance A → Co-op (Beta) → Host → confirm it lands in madrian.
3. Instance B → Co-op (Beta) → IP `127.0.0.1` → Join → confirm it lands in
   madrian and A's (blue-tinted) avatar appears, offset ~2 tiles.
4. Move A → B sees it walk smoothly (interpolated, correct facing, walk/idle anim);
   move B → A sees it.
5. Close one → the other frees the disconnected avatar.
Caveats: loopback/LAN only (no NAT traversal); 2 players; battles/enemies/chests
not synced.

## Documentation Updates

None in this task — `docs/agent/multiplayer-coop.md` is created by TID-326, which
will fold in the verification results and the manual procedure above.
