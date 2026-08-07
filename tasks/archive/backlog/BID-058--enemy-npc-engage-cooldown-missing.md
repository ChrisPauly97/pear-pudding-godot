# BID-058: `EnemyNPC.engage_cooldown` documented but does not exist in code

**Category:** code-smell / doc-gap
**Discovered during:** GID-113 / TID-420

## Summary

`docs/agent/enemies-and-npcs.md`, `docs/agent/battle-system.md`,
`docs/agent/ui-and-scene-management.md`, and TID-420's own research notes
(written from those docs) all describe an `EnemyNPC.engage_cooldown: float`
field, ticked down in `_process(delta)`, that prevents instant re-engagement
after a flee or post-battle respawn (GID-069 / TID-250, TID-251):

> "`EnemyNPC.engage_cooldown: float` prevents re-engagement immediately after
> a flee or respawn. Ticked down in `_process(delta)`; `_on_body_entered()`
> exits early while `engage_cooldown > 0`. SceneManager sets it to 3.0 s
> after flee/respawn."

As of this task, `scenes/world/entities/EnemyNPC.gd` has **no `_process()`
method and no `engage_cooldown` field at all** (confirmed by reading the full
file and grepping the whole repo — `SceneManager.gd` has no
`engage_cooldown` references either). It was apparently dropped by a later
refactor (the TID-427 async `engage()` rewrite is the most likely point,
since that's the last time `engage()`'s control flow changed significantly)
without updating the three docs or `SceneManager`'s flee/respawn path.

## Impact

The only remaining protection against instant re-engagement after a
flee/respawn is `SceneManager.can_proximity_engage()`'s 2 s
`_proximity_engage_blocked` post-battle immunity window — which is real and
still wired, but is a *global* "just left battle" guard, not a *per-enemy*
cooldown keyed to the specific enemy that was fled from. If the flee/respawn
path (`SceneManager._on_defeat_respawn()` per
`docs/agent/ui-and-scene-management.md`) still tries to call
`engage_cooldown` setters on the nearest `EnemyNPC`, that call is a silent
`has_method`-guarded no-op today (needs verification — not confirmed as part
of this task, out of scope).

## Suggested Fix

1. Verify whether `SceneManager`'s flee/respawn path still attempts to set
   `engage_cooldown` on an `EnemyNPC` (via `has_method`/`set` or a direct
   call) — if so, it's currently a no-op and flee/respawn re-engagement
   protection beyond the global 2 s window is broken.
2. Either restore the `engage_cooldown` field + `_process()` tick (now that
   TID-420 added the file's first real `_process()`, for chase movement, a
   natural place to also tick it), or update the three docs to remove the
   stale description if the global 2 s window is judged sufficient by design.

Not fixed as part of TID-420 — that task's scope was chase movement, not
restoring a possibly-intentionally-removed flee/respawn mechanic.

## Resolution

Investigated per the suggested fix:

1. Confirmed `scenes/world/entities/EnemyNPC.gd` has no `engage_cooldown`
   field. It does now have a real `_process(delta)` (added this session for
   chase/pursuit movement) and a real `_on_body_entered()`, but neither
   references any cooldown — matching the BID's finding.
2. Resolved the BID's open question: `grep -rn "engage_cooldown"` across the
   whole repo returns **zero matches outside this BID file and the three
   docs**. `SceneManager.gd`'s actual flee/respawn paths were read in full:
   - `_on_defeat_respawn()` (the respawn path referenced by
     `docs/agent/ui-and-scene-management.md`) sets
     `_proximity_engage_blocked = true` for 2 s via a `SceneTreeTimer` — it
     does **not** look up the nearest `EnemyNPC` at all, let alone call/set
     `engage_cooldown` on it (guarded or otherwise).
   - `_on_battle_fled()` → `_restore_world()` does the identical thing: sets
     the same global `_proximity_engage_blocked` flag for 2 s.
   - So this is not a silent `has_method`-guarded no-op as the BID worried —
     `SceneManager` has no per-enemy targeting logic of any kind. The global
     2 s `_proximity_engage_blocked` window (`can_proximity_engage()`) is the
     entire, and only, live protection against instant re-engagement after a
     flee or respawn, and it was already working exactly as designed.

**Decision: corrected the docs, did not restore the field.** Since nothing in
`SceneManager` attempts to call or set `engage_cooldown` today, restoring a
per-enemy field + `_process()` tick + `_on_body_entered()` check would add
code with no live caller — new dead functionality, not a fix to a broken
call site. That would be the "half-working mechanic" outcome the task
description explicitly wanted to avoid, just shifted from
"docs describe code that isn't there" to "code exists but nothing sets it
above its zero default, so it stays permanently 0 and does nothing." The
existing global 2 s window already covers the described symptom (instant
re-engagement after flee/respawn); it is coarser (blocks *all* nearby
enemies, not just the specific one fled from) but that has been the actual
shipped behavior since at least the TID-427 `engage()` rewrite with no
reported regressions, so it is treated as sufficient by design.

Updated the three docs that described the non-existent field
(`docs/agent/enemies-and-npcs.md`, `docs/agent/battle-system.md`,
`docs/agent/ui-and-scene-management.md`) to describe the real mechanism
(`SceneManager._proximity_engage_blocked`, global, 2 s) instead, and to note
explicitly that no per-enemy `engage_cooldown` field exists, so a future
reader doesn't re-discover this same gap.

No `.gd` files were changed. `godot --headless --editor --quit` parse/compile
check is clean, and `godot --headless --path . -s tests/runner.gd` passes
(2355 passed / 0 failed / 1 pending, `RESULT: PASS`).
