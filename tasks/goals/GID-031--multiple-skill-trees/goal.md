# GID-031: Multiple Skill Trees per Magic Branch

## Objective

Replace the single generic skill tree with four branch-specific trees (ember, dawn, dusk, ash), gate each player to their home magic type's two trees, and introduce corruption/redemption point currencies earned via dialogue choices that unlock select cross-magic skills.

## Context

GID-030 shipped a single 3×5 skill tree with 10 generic skills. The magic system (GID-010, GID-018) defines two magic types — light (ember + dawn) and dark (dusk + ash) — but skill progression has no connection to a player's magic identity. This goal makes skill trees an extension of the player's magic path: you specialise in your two home branches, but dark dialogue choices slowly corrupt a light-aligned player (or redeem a dark one), giving access to select opposing skills.

Earn logic for corruption/redemption points is stubbed (SaveManager methods + GameBus signals). Actual dialogue wiring is deferred to a future goal when story dialogue is extended.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-116 | Extend SkillData + SaveManager data model | agent | done | — |
| TID-117 | Create 24 branch-specific skill .tres files | agent | done | TID-116 |
| TID-118 | Player magic type selection flow | agent | pending | TID-116 |
| TID-119 | Update SkillTreeScene: home tabs + cross-magic tab | agent | pending | TID-116, TID-117, TID-118 |
| TID-120 | Stub corruption/redemption earn hooks | agent | pending | TID-116 |
| TID-121 | Update agent documentation | agent | pending | TID-119, TID-120 |

## Acceptance Criteria

- [ ] `SkillData` has `magic_branch` (ember/dawn/dusk/ash) and `alt_cost` fields
- [ ] SaveManager v13 migration adds `magic_type`, `corruption_points`, `redemption_points` with 0/empty defaults
- [ ] 24 skill `.tres` files exist across 4 branches (6 per branch) with `.uid` sidecars; the 10 old generic skills are removed
- [ ] First time the player opens the skill tree (or if `magic_type` is unset), a one-time modal prompts light vs. dark selection
- [ ] SkillTreeScene shows two tabs for the player's home branches; a third "Cross-Magic" tab shows only the alt-cost skills from the opposing magic type
- [ ] Home-branch skills cost 1 skill point; cross-magic skills display their corruption/redemption cost and spend that currency
- [ ] All three currency balances (skill points, corruption, redemption) are visible in the skill tree header
- [ ] `SaveManager.add_corruption_points(n)` and `add_redemption_points(n)` exist; each emits a `GameBus` signal
- [ ] `docs/agent/skill-trees.md` is created and up to date
