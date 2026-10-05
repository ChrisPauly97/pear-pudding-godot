# BID-089: No profiler for battle / UI / save paths

**Category:** doc-gap
**Discovered During:** GID-164 research

## Description

`tools/profile_world.gd` measures only the overworld. Battle HUD, card refresh, deck builder and save-flush costs
can't be measured, so GID-164's battle/UI/save changes are verified by review and tests only.

## Evidence

Audit findings for `BattleRealtime.gd:487`, `CardViewBuilder.gd:490,664`, `InventoryScene.gd:324`,
`SaveManager.gd:453` were read-only, no measurements.

## Suggested Resolution

Add `tools/profile_battle.gd` (drive a scripted realtime battle N frames, report `_process` cost per module and
allocations / orphan nodes), and a save-flush micro-benchmark.
