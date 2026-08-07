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

## Progress

Suggested items 1-3 fixed for real; item 4 (`max-line-length`) investigated and
left as noted debt; item 5 (`class-definitions-order`) deliberately untouched
per this item's own scoping (still wants its own dedicated goal/merge window).

`gdlint` is unpinned in CI (`pip install gdtoolkit`), so re-running it today
(gdtoolkit 4.5.0, the current latest) surfaced a fuller/drifted picture than
this file's original table — most notably `class-definitions-order` (357→430)
and `max-line-length` (141→428) grew substantially, while the three items this
pass targeted matched or were close to the original count. Counts below are
gdlint's own report, before this pass's edits vs. after.

| Rule | Before (this pass) | After | Delta | Status |
|------|--------------------:|------:|------:|--------|
| `duplicated-load` | 9 | 0 | -9 | **Fixed** — all real dupes deduped |
| `unused-argument` | 12 | 0 | -12 | **Fixed** — all 12 args underscore-prefixed |
| `mixed-tabs-and-spaces` | 15 | 0 | -15 | **Fixed** — rule disabled in `.gdlintrc` (false positives, see note above) |
| `max-line-length` | 428 | 428 | 0 | **Left as noted debt** — see below |
| `class-definitions-order` | 430 | 431 | +1 | **Untouched by design** — the +1 is `scenes/world/coop/CoopActivities.gd` gaining one more line in an already-100%-flagged const block (a pre-existing `var _world` declared before the `const` block puts every const in that file out of order per this rule); adding the new `_SiegeDefs` const to dedupe a load added one line to that pre-existing violation. No new *class* of ordering issue was introduced. |

Total gdlint problem count (`gdlint $(git ls-files '*.gd')`): **1003 → 968**
(-35 net: -36 from the three fixed rules, +1 from the explained
`class-definitions-order` side effect below).

### 1. `duplicated-load` (9 found, not 11 — some had already been fixed
   elsewhere before this pass started)

All genuine duplicate `preload()`s of the same resource path within one file.
Fixed by keeping a single file-level `const` and pointing every call site at
it (hoisting a function-local duplicate into the existing top-of-file const
block), rather than leaving two names for the same script:

- `autoloads/SaveManager.gd` — `CardRegistry` duplicate inside a migration
  lambda now reuses the file-level const; `UpgradeDefs` was preloaded
  separately in `upgrade_weapon()` and `salvage_weapon()`, now a single
  file-level const.
- `autoloads/SceneManager.gd` — `CardDropUtil`/`CardRegistry` locally
  reloaded in `_apply_siege_victory_rewards()`; now reuses the file-level
  consts declared at the top of the file.
- `scenes/battle/BattleResultUI.gd` — `UiUtil` was declared twice
  (`UiUtil` and `_UiUtil`, same path); kept `_UiUtil` (used 39x vs. 2x) and
  repointed the two `UiUtil.rarity_color()` call sites.
- `scenes/world/WorldScene.gd` — `SiegeDefs` reloaded locally in both
  `_check_siege_spawn()` and `_spawn_siege_raiders()`; hoisted to a new
  file-level `_SiegeDefs` const.
- `scenes/world/coop/CoopActivities.gd` — `SiegeDefs` reloaded locally in
  three separate functions (`_coop_spawn_night_hunt`, `_coop_spawn_siege_wave`,
  `_on_siege_boss_phase_received`); consolidated into the file's existing
  alphabetized file-level const block as `_SiegeDefs`.
- `tests/unit/test_potion_recipes.gd` — `CraftingRegistry` reloaded in two
  test functions; hoisted to the file's top-level const block.

### 2. `unused-argument` (12)

Every flagged argument is genuinely unread in its function body. All are
either free functions or signal/RPC handlers called positionally (verified
each with a grep for call sites before renaming), so a plain `_`-prefix
rename is behavior-preserving. `scenes/world/coop/*.gd`'s RPC handlers
already had a `_sender` convention in several other handlers in the same
files — the newly-fixed ones now match it:

- `autoloads/SceneManager.gd`: `_on_pack_purchased` → `_pack_id`
- `scenes/ui/BountyBoardScene.gd`: `_get_state` → `_bounty_id`;
  `_on_claim_pressed` → `_reward`
- `scenes/ui/InventoryScene.gd`: `_on_filter_btn` → `_btn` (kept 3-arg
  signature — it's bound via `Callable.bind()`)
- `scenes/ui/MapViewOverlay.gd`: `_build_fast_travel_panel` → `_vp`
- `scenes/world/WorldHUD.gd`: `_create_nav_buttons` → `_vh`;
  `_init_zones` → `_btn_h`
- `scenes/world/coop/CoopActivities.gd`: `_on_loot_roll_request_submitted` →
  `_sender`; `_on_party_bounty_update_received` → `_payload`
- `scenes/world/coop/CoopSession.gd`: `_on_story_flag_submitted` → `_sender`
- `scenes/world/coop/CoopSocial.gd`: `_on_ping_received` → `_sender`;
  `_on_trade_confirm_submitted` → `_sender`

### 3. `mixed-tabs-and-spaces` (15)

Re-inspected all 15 (line contents match the original investigation);
confirmed every one is a bracket-continuation alignment inside an open
array/dict literal or a trailing-comment alignment, not a real indentation
ambiguity — Godot parses every one fine (full suite is green both before and
after). Per this file's own recommendation, added
`disable: [mixed-tabs-and-spaces]` to `.gdlintrc` with a comment explaining
why, rather than reflowing 15 correct lines to satisfy a linter false
positive.

### 4. `max-line-length` — investigated, left as noted debt (not fixed)

This item's premise ("largely mechanical in `EnemyRegistry.gd`", 141
problems) no longer holds. Re-running gdlint today reports **428** problems
(gdtoolkit is unpinned in CI, so this is likely rule-behavior/version drift
since the file was written, not a regression introduced by other work).
`EnemyRegistry.gd` is still the single largest contributor (53), but the
remaining ~375 are spread across 30+ files — `InventoryScene.gd` (33),
`BattleResultUI.gd` (30), `WorldScene.gd` (22), `BattleScene.gd` (22),
`ShopScene.gd` (18), `SceneManager.gd` (16), and more — most of which is
ordinary application code, not data tables.

Checked both possible fixes named in the BID:

- **Per-file/per-directory override**: not supported by gdtoolkit 4.5.0's
  config format. Read `gdtoolkit/linter/__init__.py` and `__main__.py`
  directly — `.gdlintrc` is a single flat key/value config
  (`_find_config_file` locates exactly one file, `_load_config_file_or_default`
  loads it as one dict); there is no glob/path-scoped override section, only a
  global `excluded_directories` list that fully excludes a path from every
  rule (too blunt — would silence *all* lint on those files/dirs, not just
  raise one threshold).
- **Raise the global limit**: checked the actual char lengths of all 428
  flagged lines (not byte length — the codebase's prose comments use em
  dashes/curly quotes, which inflated a naive byte-length pass to 636). The
  worst offenders are prose-heavy dialogue/tutorial tables
  (`ScrollRegistry.gd` up to 350 chars, `TutorialRegistry.gd` up to 287), not
  numeric stat tables. Modeled the remaining-problem count at several
  candidate limits:

  | New limit | Problems remaining |
  |-----------|--------------------:|
  | 130 | 301 |
  | 140 | 213 |
  | 150 | 163 |
  | 160 | 130 |
  | 180 | 80 |
  | 200 | 50 |

  No limit that is still a reasonable project-wide readability ceiling
  resolves a meaningful majority of the backlog; a limit that would (250+)
  is not a defensible general line-length rule. A modest bump (130-140)
  changes little (majority still flagged) while being a project-wide style
  change every future file inherits.

Left `max-line-length` at 120 and the 428 problems un-reflowed, per this
task's own instruction not to mass-reflow hand-written data/dialogue tables
for mechanical lint compliance. This — like `class-definitions-order` —
remains real, filed debt for a future dedicated pass (candidates: split the
long prose tables into external resource files, or a project decision to
adopt a higher limit specifically for `autoloads/ScrollRegistry.gd` /
`game_logic/TutorialRegistry.gd` / `autoloads/EnemyRegistry.gd` via
`excluded_directories`, accepting the full-exclude tradeoff).

### Verification

- `godot --headless --editor --quit` → no parse/compile errors.
- `godot --headless --path . -s tests/runner.gd` → `RESULT: PASS`, 2355
  passed, 0 failed, 1 pending (unchanged from baseline).
- `godot --headless --path . -s tests/world_scene_smoke.gd` → PASS, 18/18
  checks (run because `WorldScene.gd` and three `scenes/world/coop/*.gd`
  modules were touched).
- Per-file/per-rule diff of the full gdlint report before vs. after confirms
  no rule regressed anywhere except the explained `class-definitions-order`
  +1 in `CoopActivities.gd`.
