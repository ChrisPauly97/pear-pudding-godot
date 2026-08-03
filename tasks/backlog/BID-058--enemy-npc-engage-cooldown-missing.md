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
