# BID-023: Branch HEAD did not compile under Godot 4.6 (3 parse errors)

**Category:** code-smell / CI-gap
**Discovered During:** GID-094 / TID-341 (headless import check)
**Status:** resolved (fixed in TID-341)

## Problem

Running the mandated headless import check (`godot --headless --editor --quit`)
on this branch's HEAD (post-merge #296) surfaced **three** pre-existing GDScript
parse errors that prevent the whole project from compiling under Godot 4.6 — the
version CI builds on (GID-087). Because parse errors cascade through `preload`
chains, `SaveManager`, `Player`, `EnemyNPC`, and `WorldScene` all failed to load.

| File | Error | Cause |
|---|---|---|
| `game_logic/TextureGen.gd:177,178,202` | `Expected expression after "/" operator` | Python-style `//` integer-division (`i//2`, `sx*sx//3`) — GDScript has no `//`; `/` on ints is already integer division |
| `autoloads/CardRegistry.gd:165,166` | `Too many arguments for "get()" call` | `res.get("card_class", "")` on a Resource — `Object.get()` takes one arg; the 2-arg default form only exists on `Dictionary` |

These are surfaced by Godot 4.6's stricter analyzer; an earlier GDScript parser
let them through, so they slipped past before the 4.6 alignment (GID-087).

## Fix (applied in TID-341)

- `TextureGen.gd`: `//` → `/` (integer-division semantics preserved).
- `CardRegistry.gd`: 1-arg `Object.get()` with an explicit `!= null` guard,
  mirroring the existing `id` lookup two lines above.

## Follow-up

CI should fail the build when the editor-import grep finds any
`Parse Error|Compile Error|Failed to load script` line so a non-compiling HEAD
cannot merge again. Logged here for that process gap; the code itself is fixed.
