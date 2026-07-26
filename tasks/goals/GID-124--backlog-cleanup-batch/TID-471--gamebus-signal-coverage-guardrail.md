# TID-471: `exited_to_world` Emission + GameBus Coverage Guardrail

Goal: [GID-124](goal.md) · Backlog: BID-056 · Type: agent · Status: done

## Problem

`GameBus.exited_to_world` was declared but never emitted anywhere. It is the
counterpart to `entered_named_map`, which *is* emitted from `WorldScene._ready()`
and logged by `AppLog` — so a subscriber saw the player enter named maps and
never come back out.

A declared-but-silent signal is worse than a missing one: it connects fine and
simply never fires, so a consumer looks correct while under-reporting.

## Correction Made During This Task

BID-056 originally named three dangling signals. Two were false positives from
my own audit grep, which matched only the typed `GameBus.<name>.emit(...)` form.
`world_event_started` / `world_event_ended` are emitted from
`WorldEventManager.gd:99,116` via the string form on a cached reference
(`_game_bus.emit_signal("world_event_started", id)`) and both have live `AppLog`
subscribers. Only `exited_to_world` was real. The backlog file was corrected
before archiving.

## Changes Made

- `scenes/world/WorldScene.gd` — emit `exited_to_world` on the `_is_infinite`
  branch of `_ready()`, as the `else` of the existing named-map branch.
- `autoloads/AppLog.gd` — subscribe and log `"Map: overworld"`, symmetric with
  the existing `entered_named_map` subscriber.
- `tests/unit/test_gamebus_signal_coverage.gd` (new) — guardrail.

## The Guardrail

Static source-text scan over `autoloads/`, `ai/`, `game_logic/`, `scenes/`,
following the precedent of `test_hud_registry_guardrail.gd` (GameBus's
collaborators have scene-tree dependencies unsuited to headless instantiation).
Four assertions:

1. GameBus declares at least one signal — guards against the scan silently
   parsing nothing and making everything below vacuous.
2. **Every declared signal is emitted somewhere.** Recognises both
   `X.emit(...)` and `emit_signal("X", ...)`. Has an `_ALLOWED_UNEMITTED`
   allow-list, currently empty, so a deliberate exception must be justified in
   code rather than silently tolerated.
3. **Every `GameBus.<name>.connect/emit/...` reference is declared.** This is
   the dangerous direction — per CLAUDE.md's "Dead signal connect aborted
   `_ready`" learning, referencing a removed signal throws, and a throwing
   statement at the tail of `_ready` silently kills everything after it.
4. **Every string-form `emit_signal("name")` on the bus names a declared
   signal.** The string form is not compile-checked, so a typo emits nothing and
   raises nothing.

## Verification

Both new assertions were canary-tested rather than assumed:

- Appended `signal bid056_canary_never_emitted` to `GameBus.gd` → assertion 2
  failed with the canary named. Reverted.
- Typo'd `WorldEventManager`'s emission to `"world_event_startd"` → assertion 4
  failed with the typo named. Reverted.

Suite green afterwards: **2213 passed / 0 failed** (up from 2209).

## Documentation Updates

None needed — the guardrail documents itself in its header comment, and
`docs/agent/signals-and-constants.md` already describes the GameBus pattern.
