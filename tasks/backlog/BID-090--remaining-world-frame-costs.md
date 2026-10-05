# BID-090: Remaining per-frame world costs after GID-164

**Category:** code-smell
**Discovered During:** GID-164 / TID-685

## Description

After GID-164 the largest steady overworld costs are:

- `WalkCycle._process` on ~96 enemies (~125 µs/frame): every enemy steps its walk cycle every frame,
  including ones far off-screen.
- `quest_tracker.refresh` (~424 µs every 250 ms), mostly `_refresh_npc_marks`.
- `_check_interactions` (~203 µs at ~7 Hz).

## Evidence

`godot --headless --path . -s tools/profile_world.gd -- --frames 900` (GID-164 results table in its goal.md).

## Suggested Resolution

- Tick enemy walk cycles from EnemyNPC only while within the view radius (like TownLife's FAR_RADIUS
  round-robin), using `WalkCycle.tick(dt)` with the skipped time.
- Diff NPC marks against the last state per NPC instead of recomputing every mark each refresh.
