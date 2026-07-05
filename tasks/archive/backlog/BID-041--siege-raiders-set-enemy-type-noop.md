# BID-041: Single-player siege raiders' `.set("enemy_type", ...)` is a silent no-op

## Category

code-smell (latent bug)

## Discovered During

GID-103 / TID-384 (co-op Town Siege) research — while building the co-op wave
spawner, cross-checked the single-player precedent (`WorldScene._spawn_siege_raiders`,
GID-054) to confirm the right way to configure an `EnemyNPC` node before it can be
engaged.

## Summary

`WorldScene._spawn_siege_raiders` (single-player Town Siege) instantiates an
`EnemyNPC` and does:

```gdscript
node.set("enemy_type", enemy_type)
```

`EnemyNPC.gd` has **no `enemy_type` property** (it only ever reads
`enemy_data["enemy_type"]`, populated by `init_from_data(data: Dictionary)`) and
declares no `_set`/`_get` override. Godot's `Object.set()` on a nonexistent property
name is a silent no-op — it does not error, and does not populate `enemy_data`.

The practical effect: every single-player siege raider's `enemy_data` stays `{}`.
When the player engages one, `EnemyNPC.engage()` does
`edata.get("enemy_type", "undead_basic")`, which falls back to `"undead_basic"` for
**every** raider regardless of `stage` — so the "Martarquas Veteran" (stage 1) and
"Martarquas Warlord" (stage 2) decks described in `EnemyRegistry.gd` and
`docs/agent/town-siege.md` are never actually fought; the siege gauntlet always uses
the weakest undead deck. The difficulty-pip label above the raider's head is also
wrong (defaults to tier via `EnemyRegistry.get_difficulty_tier("")`).

The co-op siege wave spawner added in GID-103/TID-384
(`WorldScene._coop_spawn_siege_wave`) does **not** have this bug — it correctly uses
`node.call("init_from_data", {"id": eid, "enemy_type": ...})`.

## Suggested Fix

In `WorldScene._spawn_siege_raiders`, replace:

```gdscript
node.set("enemy_type", enemy_type)
```

with:

```gdscript
node.call("init_from_data", {"enemy_type": enemy_type})
```

(no `id` needed here — single-player siege raiders aren't tracked by id the way
co-op world-objects are; `_enemy_nodes[raider_id] = node` already handles the
WorldScene-side bookkeeping externally). Add/extend a headless test asserting that
a spawned raider's resolved deck matches `SiegeDefs.get_raider_deck_ids(stage)` (or
at minimum that `enemy_data.get("enemy_type", "")` is non-empty after spawn) so this
can't silently regress again.

## Impact

Single-player Town Siege (GID-054) has shipped and is marked `done`, so this is a
live gameplay bug, not a design gap — worth a small dedicated fix task.
