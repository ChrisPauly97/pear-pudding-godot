# TID-069: Create 6 New Enemy .tres Files

**Goal:** GID-021
**Type:** agent
**Status:** done
**Depends On:** TID-068

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Using the deck and drop pool data authored in TID-068, this task creates .tres resource files for the 6 new enemy types and their .uid sidecars.

## Research Notes

- Existing enemy .tres files live in `data/enemies/` — follow their EnemyData schema exactly
- `autoloads/EnemyRegistry.gd` loads all enemies from `data/enemies/` — verify it uses `dir.list_dir_begin()` for auto-discovery; if hardcoded, add new IDs
- Every .tres needs a companion `.uid` file (see CLAUDE.md for generation command)
- EnemyData fields (check `data/enemies/*.tres` for exact field names): id, display_name, coin_reward, deck: Array[String], drop_pool: Array[String]
- The 6 enemies: wraith (grasslands), forest_shade (forest), sand_stalker (desert), scorched_revenant (scorched), mountain_troll (mountains), stone_golem (mountains)
- Do NOT set boss=true on these — stone_golem is high-tier but not a formal boss; TID-070/071 handle actual bosses
- Use the deck compositions from story.md (TID-068 output)

## Plan

**Architecture correction (this task's research notes predate a later
refactor):** there is no `data/enemies/*.tres` and no `data/EnemyData.gd` in
the current codebase — confirmed by `ls` returning nothing for both paths.
CLAUDE.md's "Save Fields" section already documents this accurately: "Enemy
battle data lives **only** in `EnemyRegistry._ensure_loaded()` — there are
no `.tres` enemy resources." `autoloads/EnemyRegistry.gd`'s `_enemies`
dictionary (checked every existing entry: `undead_basic`, `roaming_terror`,
duelists, `martarquas_warleader`, etc.) is the single source of truth, with
static getters (`get_deck`, `get_drop_pool`, `get_display_name`,
`get_coin_reward`, `get_is_boss`, `get_boss_hp`, `get_phase2_deck`,
`get_difficulty_tier`, `get_lore_text`) reading it directly. Several of
these (`deck`, `drop_pool`, `display_name`, `coin_reward`, `is_boss`,
`boss_hp`, `phase2_deck`, `difficulty_tier`, `lore_text`) use un-guarded `[]`
indexing — every new entry needs **all** of them present or a later lookup
crashes. `ai_persona` is read with `.get(..., "basic")` (optional but set
anyway, for a correct AI). `signature_card`/`capture_condition`/
`capture_param` are optional and only exist on soulbound-capture-eligible
enemies (`sig_*` cards + `data/cards/*.tres` art) — out of scope here, same
as duelists/raiders which also omit them. No live `.tres`/`.uid` files to
create; this task instead adds 6 dictionary entries directly.

**The 6 entries** (from TID-068's authored decks/drop pools in
`docs/human/story.md`): `wraith` (tier 1), `forest_shade` (tier 2),
`sand_stalker` (tier 2), `scorched_revenant` (tier 3), `mountain_troll`
(tier 3), `stone_golem` (tier 4, `is_boss = true`, `boss_hp = 40`, has a
`phase2_deck` — flavor-wise a "mini-boss" per `specification.md`'s
suggestion, still a *regular* biome-pool spawn, not one of TID-071's two
dedicated story-boss placements). `ai_persona`: `basic` for wraith
(low-tier, readable), `aggro` for sand_stalker (rush archetype) and
scorched_revenant (burn-and-press), `control` for forest_shade (draw/value),
mountain_troll and stone_golem (grindy/tanky, matches how `undead_elite` —
the other tier-4 grinder — is also `control`).

**Verified every card ID used exists** in `data/cards/` (ls'd the directory
against every ID in the 6 decks/drop pools). `lore_text` written fresh for
each — required non-empty by `tests/unit/test_bestiary_data.gd::
test_all_bundled_enemies_have_non_empty_lore_text`, which iterates
`get_all_enemy_ids()`.

## Changes Made

- `autoloads/EnemyRegistry.gd`: added 6 dictionary entries to `_enemies`
  (`wraith`, `forest_shade`, `sand_stalker`, `scorched_revenant`,
  `mountain_troll`, `stone_golem`) with all required fields (`display_name`,
  `deck`, `drop_pool`, `coin_reward`, `is_boss`, `boss_hp`, `phase2_deck`,
  `difficulty_tier`, `ai_persona`, `lore_text`) — decks/drop pools from
  `docs/human/story.md` (TID-068), lore text written fresh per enemy.
  `stone_golem` is `is_boss = true` / `boss_hp = 40` with a `phase2_deck`
  (mini-boss flavor per the original spec suggestion), but is still a
  regular biome-pool entry, not one of TID-071's two dedicated placements.
  No `.tres`/`.uid` files created — see Plan for why.
- Verified: headless editor import clean; `tests/runner.gd` — 2355 passed
  (unchanged), 0 failed, 1 pending (pre-existing), including
  `test_all_bundled_enemies_have_non_empty_lore_text` (iterates every
  registry entry) and `test_enemy_drop_pools_have_no_signature_ids`.

## Documentation Updates

- `docs/agent/enemies-and-npcs.md` "Enemy Types" section: corrected the
  stale `.tres`-based description and fictional `type_for_biome` signature
  to match the real `_enemies` dictionary / `BiomeDef.ENEMY_POOLS` lookup
  (drift discovered while updating this section — not filed as a separate
  backlog item since it's the exact doc this task already needed to touch);
  added the 6 new enemies to the type table.
