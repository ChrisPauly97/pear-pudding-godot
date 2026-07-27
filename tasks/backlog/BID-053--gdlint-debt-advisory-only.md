# BID-053: gdlint job is advisory-only due to pre-existing lint debt

Category: code-smell
Discovered during: GID-124 / TID-469

## Summary

`.github/workflows/tests.yml` runs `gdlint` over every tracked `.gd` file but is
marked `continue-on-error: true`, so it can never fail a build. The tree carries
too much pre-existing debt to gate on today.

## Context

Two config bugs were fixed as part of TID-469, which cut the reported problem
count from >1000 to 638:

- `constant-name` was overridden to `[A-Z][A-Z0-9_]*`, dropping the optional
  leading underscore that gdlint's own default allows — so idiomatic private
  constants like `AudioManager._POOL_SIZE` were flagged.
- `load-constant-name` was never configured, so the default rejected
  `const _SpriteRegistry = preload(...)` — the exact pattern **CLAUDE.md
  mandates** over bare `class_name` references. Every compliant file was being
  penalised for following the project's own rule.

## Remaining debt (638 problems)

| Count | Rule | Nature |
|-------|------|--------|
| 357 | `class-definitions-order` | Style — declaration ordering within a class |
| 141 | `max-line-length` | Style — mostly `EnemyRegistry.gd` data tables |
| 21 | `max-public-methods` | Design smell — oversized classes |
| 19 | `max-returns` | Style |
| 19 | `max-file-lines` | Design smell — oversized files |
| 16 | `sub-class-name` | Naming |
| 15 | `mixed-tabs-and-spaces` | False alarm — see note below |
| 12 | `unused-argument` | Dead code |
| 11 | `no-elif-return` | Style |
| 11 | `duplicated-load` | Real waste — same resource loaded twice in a file |
| 5 | `function-variable-name` | Naming |
| 4 | `no-else-return` | Style |
| 3 | `constant-name` | Naming |
| 3 | `class-variable-name` | Naming |
| 1 | `function-arguments-number` | Design smell |

### Note on `mixed-tabs-and-spaces`

All 15 were inspected individually. Every one is a **bracket-continuation
alignment** line — tab indentation followed by spaces to align a wrapped array
literal or a trailing comment, e.g.:

```gdscript
player_deck = ["ghost", "skeleton", "zombie", "ghoul",
               "ghost", "skeleton", "zombie", "ghoul"]
```

None is a genuine indentation ambiguity: GDScript's indentation sensitivity
applies to leading indentation of a *statement*, and these are all continuations
inside an open bracket. Godot parses them correctly (the suite is green).

This is a lint false positive for this codebase's style, not debt. Prefer
`disable: [mixed-tabs-and-spaces]` in `.gdlintrc` over reflowing 15 lines —
deliberately left as-is pending a call on that.

## Suggested approach

Fix in priority order, then flip `continue-on-error` off:

1. `duplicated-load` (11) — the only genuine bug smell in the list.
2. `unused-argument` (12) — prefix with `_` or remove.
3. `mixed-tabs-and-spaces` (15) — disable the rule (see note above).
4. `max-line-length` (141) — largely mechanical in `EnemyRegistry.gd`; consider
   raising the limit for pure data-table files instead of reflowing them.
5. `class-definitions-order` (357) — bulk-fixable with `gdformat`, but touches
   nearly every file, so it wants its own goal and a clean merge window.

`max-file-lines` / `max-public-methods` overlap with the open
"SceneManager as formal state machine" item in `REFACTOR_TODOS.md`.

## Acceptance

- `gdlint` runs without `continue-on-error` in CI and passes.
