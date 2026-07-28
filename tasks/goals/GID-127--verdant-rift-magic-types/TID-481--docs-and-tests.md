# TID-481: Agent Docs + Regression Tests

Goal: [GID-127](goal.md) · Type: agent · Status: done

## Problem

Four agent docs describe the magic system as binary, and nothing guards the new
tables against drift — a branch listed under a type but missing a colour, or a
skill whose `magic_branch` matches no known branch, would both fail silently.

## Changes Made

### Tests

- **`tests/unit/test_magic_types.gd`** (new):
  - Every type in `TYPES` has a non-empty display name, tagline, exactly 2
    branches, and a `cross_currency` of `corruption` or `redemption`.
  - Every branch listed under a type has a `BRANCH_COLORS` entry, and every
    `BRANCH_COLORS` key belongs to exactly one type — the drift guard in both
    directions.
  - `type_for_branch()` round-trips against `branches_for()`.
  - Each type has exactly one signature branch in `CURRENCY_BRANCHES`, and that
    branch's currency equals its type's `cross_currency`.
  - Every `magic_branch` used by a `SkillRegistry` skill is a known branch; every
    branch has at least one skill and at least one cross-purchasable skill (so no
    type can ship with an empty Cross-Magic contribution).
  - Every non-empty `magic_branch` on a `CardRegistry` card is a known branch,
    and its card's `magic_type` matches `type_for_branch()` — the check that
    catches a card tagged `verdant`/`dusk`.
  - Light/Dark regression: `branches_for("light") == ["ember", "dawn"]`,
    `cross_currency("light") == "corruption"`, and the dark equivalents.

- **`tests/unit/test_battlefield_rules.gd`** — added affinity cases: Bloom −1 in
  Forest and full price elsewhere, Fracture −1 in Scorched, Thorn and Flux never
  discounted, and Bloom in Grasslands stacking correctly with the first-card
  discount. Existing dawn/dusk cases were left untouched and still pass, which is
  the point.

### Docs

- **`docs/agent/magic-system.md`** — rewritten from "two axes" to four. Added
  Verdant and Rift lore, the four new sub-branch profiles, the `MagicTypes.gd`
  table reference, the affinity axis explanation, and the new card roster.
- **`docs/agent/skill-trees.md`** — four types, eight branches, 48 skills; the
  generalized cross-magic rules and the alignment → currency table.
- **`docs/agent/battle-system.md`** — updated the `magic_type` / `magic_branch`
  value lists and the branch cost-discount rule.
- **`docs/agent/art-sprites.md`** — four new rune PNGs listed as an asset
  requirement, with the fallback behaviour that makes them optional.
- **`CLAUDE.md`** — added the "Magic types: MagicTypes is the source of truth"
  section, in the same spirit as the existing `IsoConst` and `TerrainMath` rules.

## Verification

Headless import clean. Full suite run via `tests/runner.gd`.
