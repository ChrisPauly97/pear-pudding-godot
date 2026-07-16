# TID-443: New-Game Baseline Fix + Optional Head Start Toggle (BID-049)

**Goal:** GID-117
**Type:** agent
**Status:** done (headless import + test run unverified in-sandbox — no Godot binary, download blocked by session proxy)
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Promotes BID-049. `SaveManager.new_game()` currently hardcodes `xp = 11250`, `level = 15`,
`skill_points = 14`, `coins = 3000` — leaked debug state (PR #290 / GID-092 merge) that
skips the entire early progression arc for every new player. User direction (2026-07-13):
fix the default to a true level-1 start, but **keep the boosted start available as an
opt-in option** ("keep the debug of lvl 15 and 5k gold as an option for me").

## Research Notes

- `autoloads/SaveManager.gd::new_game()` (~line 329) — the hardcoded values.
- XP math: `xp_for_level(lvl) = lvl² · 50`; `_compute_level(11250) == 15`, so
  `xp = 11250 / level = 15 / skill_points = 14` is a self-consistent boosted state.
  `_compute_level(0) == 0` but `add_xp` only levels up when `new_level > level`, so
  `level = 1, xp = 0` is a safe baseline (first level-up at 200 XP → level 2).
- Callers: `SceneManager.start_new_game_with_biome(biome_id)` (biome-select flow, line
  ~275) and `SceneManager.start_new_game()` (plain fallback, line ~272).
- New-game UI: `scenes/ui/BiomeSelectionScene.gd` — fully procedural layout, `ref`-relative
  sizing (`ref = min(vh, vw)`), bottom bar holds the Back button; `_on_biome_chosen` calls
  `SceneManager.start_new_game_with_biome(biome_id)`.
- No test depends on the old debug values (grepped 3000/11250 across tests/unit).
- Baseline coins: pre-debug value unrecoverable (truncated clone history); use a small
  float (50 — a couple of cheap shop cards; tier-1 battles pay 5).
- User said "5k gold" for the option; current debug value is 3000 — use 5000 per the
  user's words.

## Plan

1. `SaveManager.new_game(head_start: bool = false)` — baseline `xp = 0, level = 1,
   skill_points = 0, coins = 50`; head start `xp = 11250, level = 15, skill_points = 14,
   coins = 5000`.
2. `SceneManager.start_new_game_with_biome(biome_id: int, head_start: bool = false)` —
   thread the flag through to `new_game()`.
3. `BiomeSelectionScene` — `CheckButton` "Head Start (debug)" in the bottom bar
   (ref-relative sizing, touch-operable = mobile parity); pass its state on biome choose.
4. New `tests/unit/test_new_game_baseline.gd` — baseline and head-start values, plus
   `_compute_level` consistency for both states.
5. Resolve BID-049 (archive + index), update `docs/agent/save-system.md` and
   `docs/agent/game-appeal.md` §7 incidental note.

## Changes Made

- `autoloads/SaveManager.gd` — `new_game(head_start: bool = false)`: baseline is now
  `xp = 0, level = 1, skill_points = 0, coins = 50`; head start restores the boosted state
  with `coins = 5000` (user asked for "5k gold"; the leaked debug value had been 3000).
- `autoloads/SceneManager.gd` — `start_new_game_with_biome(biome_id, head_start = false)`
  threads the flag through; plain `start_new_game()` keeps the level-1 default.
- `scenes/ui/BiomeSelectionScene.gd` — "Head Start (debug): Lv 15, 5000 coins"
  `CheckButton` in the bottom bar (ref-relative sizing, touch-operable — mobile parity),
  read in `_on_biome_chosen`.
- `tests/unit/test_new_game_baseline.gd` — new suite: level-1 defaults, head-start values,
  `_compute_level(11250) == 15` curve consistency, and first level-up at 200 XP grants a
  skill point from a default start.
- Resolved **BID-049** (moved to `tasks/archive/backlog/`, index row moved to Resolved).
- **Verification caveat:** as with TID-441, no Godot binary is available in this sandbox
  (proxy blocks the release download), so headless import + test run must happen in CI or
  a Godot-capable session. Validated by diff review and control-flow trace.

## Documentation Updates

- `docs/agent/save-system.md` — New Game section rewritten: accurate signature (the old
  text described a nonexistent `new_game(biome: String)`), baseline values, Head Start
  toggle, and the seed/biome ordering note.
- `docs/agent/game-appeal.md` §7 — incidental finding marked resolved by this task.
