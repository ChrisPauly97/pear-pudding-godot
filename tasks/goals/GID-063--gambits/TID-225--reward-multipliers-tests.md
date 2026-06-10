# TID-225: Reward multipliers + headless tests

**Goal:** GID-063
**Type:** agent
**Status:** pending
**Depends On:** TID-224

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-224 delivers the gambit catalogue, the pre-battle picker, the in-battle handicaps, and the badge. This task closes the loop: on victory with an active gambit, the coin reward is multiplied and the drop-rarity roll is boosted per the gambit's multiplier; on loss nothing extra happens (the handicap was the cost). It also adds a headless unit-test suite covering the catalogue, the handicap effects, and the reward math.

Design (from goal):
- Gambit multipliers: "Wounded Pride" ×1.5, "Slow Start" ×1.5, "Emboldened Foe" ×2, "Iron Veil" ×2 (numbers tunable in Plan phase, read from the TID-224 const table — never duplicated here).
- On victory, coin reward and drop-rarity roll are multiplied/boosted per the gambit; on loss, normal loss flow.

## Research Notes

### Coin reward computation (GID-007) — where to multiply

`autoloads/SceneManager.gd` `_on_battle_won(result: Dictionary)` (lines 253–308):
- Line 258: `var enemy_type: String = str(save_manager.pending_battle_enemy_data.get("enemy_type", ""))` — enemy context is read from `pending_battle_enemy_data` **before** `clear_pending_battle()` at line 303. The active `gambit_id` (stored inside `enemy_data` by TID-224, hence inside `pending_battle_enemy_data`) must be read at the same point, before the clear.
- Lines 290–293: coin award — `var coins: int = EnemyRegistry.get_coin_reward(enemy_type)` → `save_manager.add_coins(coins)` → `session_stats["coins_earned"] += coins`. Multiply here: `coins = int(round(coins * Gambits.get_multiplier(gambit_id)))`. `EnemyRegistry.get_coin_reward` (`autoloads/EnemyRegistry.gd` lines 55–59) returns `EnemyData.coin_reward` (`data/EnemyData.gd` line 11, `@export var coin_reward: int = 5`), falling back to 5.
- Loss path `_on_battle_lost()` (lines 310–324) needs no change — it never touches coins/drops.

### Drop rarity (GID-028) — where to boost

- `game_logic/CardDropUtil.gd`: `roll_rarity(source_tier)` (lines 16–26) does a weighted d100 against `TIER_WEIGHTS` (lines 8–13; tiers 1–4, `[common, rare, epic, legendary]`, e.g. tier 1 = `[80, 18, 2, 0]`, tier 4 = `[20, 40, 30, 10]`). `effective_rarity(template_id, rolled)` (lines 30–34) only forces legendary-class cards to legendary.
- `SceneManager._on_battle_won` computes `drop_tier` at lines 260–262: `EnemyRegistry.get_difficulty_tier(enemy_type)`, overridden to 4 for bosses. The tier feeds `CardDropUtil.roll_rarity(drop_tier)` at line 273 (single `card_reward`) and line 285 (boss `card_rewards` loop).
- **Simplest boost mechanism:** bump `drop_tier` by the gambit's rarity bonus (e.g. +1 for ×1.5 gambits, +2 for ×2 — Plan decision), clamped — `roll_rarity` already clamps via `clampi(source_tier - 1, 0, TIER_WEIGHTS.size() - 1)` (line 17), so over-bumping safely saturates at tier 4. Alternative (Plan option): a new `CardDropUtil.roll_rarity_boosted(tier, bonus)` static func if fractional boosts are wanted; prefer the tier bump for zero new probability code.
- Apply the bump once, right after line 262, so both the single-reward path (line 273) and the boss multi-reward loop (line 285) inherit it.
- Note `CardDropUtil` is a no-`class_name` static util — `const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")` is already done inline at SceneManager line 256.

### Multiplier source of truth

- Read from the TID-224 catalogue: `const Gambits = preload("res://game_logic/battle/Gambits.gd")`, `Gambits.get_multiplier(gambit_id)` returning `1.0` for `""`/unknown ids so the no-gambit path is mathematically unchanged. Suggested catalogue fields consumed here: `multiplier: float`, `rarity_tier_bonus: int`.
- CLAUDE.md Variant rules: `int(round(...))`/explicit annotations on `max/min/clamp` results; dictionary indexing returns Variant — annotate.

### Headless test pattern (for the new suite)

- Runner: `tests/runner.gd` — `extends SceneTree`, a `const SUITES: Array = [preload(...), ...]` list (lines 14–29); `_initialize()` instantiates each suite, calls `run_all()`, sums `pass_count/fail_count`, `quit(1)` on any failure. **Register the new suite by adding `preload("res://tests/unit/test_gambits.gd")` to `SUITES`.**
- Framework: `tests/framework/test_case.gd` — `extends RefCounted`; discovers `test_*` methods via `get_method_list()`; hooks `before_all/after_all/before_each/after_each`; assertions include `assert_eq`, `assert_true`, `assert_false`, `assert_gt`.
- Example suite: `tests/unit/test_game_state.gd` — `extends "res://tests/framework/test_case.gd"`, preloads `GameState`/`PlayerState`/`CardInstance`, builds card templates as plain Dictionaries (`_tmpl()` helper, lines 22–27) so tests don't depend on registry contents; note header comment: `GameState.new()` requires the CardRegistry autoload, so the runner must be invoked with `--path .`.
- Run command (CLAUDE.md): `godot --headless --path . -s tests/runner.gd`; install Godot 4.4.1 per the CLAUDE.md "Running Tests" section if the binary is absent. Exit 0 = pass.
- `.gd` test files in this repo have `.uid` sidecars (e.g. `test_game_state.gd.uid`) — create one for `test_gambits.gd` (random `uid://` + 12 lowercase alphanumerics, per CLAUDE.md).

### What the tests should cover (suggested `tests/unit/test_gambits.gd`)

1. **Catalogue integrity:** every entry in `Gambits.ALL` has non-empty name/desc, `multiplier >= 1.0`, valid handicap params; `get_multiplier("")` and `get_multiplier("nonsense")` return `1.0`.
2. **Handicap application (pure state, no UI):** exercise the TID-224 application function(s) directly on `GameState`/`PlayerState`/`HeroState`:
   - Wounded Pride → `players[0].hero.health == 25` (HeroState default is 30, `game_logic/battle/HeroState.gd` lines 5–6).
   - Slow Start → with `skip_next_draw` set, `PlayerState.start_turn(1)` does not grow the hand (compare `hand.size()` before/after; normal path draws 1 via `draw_card()`, PlayerState.gd line 87); flag consumed so turn 3 draws normally.
   - Emboldened Foe → after `build_deck` with the bonus, every minion `CardInstance.attack` is base+1 (use `_tmpl()`-style dictionaries to avoid registry dependence where possible); spells unaffected.
   - Iron Veil → `players[1].hero.get_status_value("armor") == 5`; a 3-damage `take_damage` leaves `health == 30` and armor 2 (armor consumption logic at HeroState.gd lines 21–33).
3. **Serialization round-trip:** any new `PlayerState` fields (e.g. `skip_next_draw`, `minion_attack_bonus`) survive `to_dict()`/`from_dict()` (pattern: existing `bonus_draw` at PlayerState.gd lines 105/118).
4. **Reward math:** coin multiplication helper returns `int(round(base * mult))` for each gambit (e.g. 5 → 8 at ×1.5, 5 → 10 at ×2) and identity for `""`; drop-tier bump clamps (tier 4 + bonus still rolls — `CardDropUtil.roll_rarity(6)` must not crash and behaves as tier 4). If the multiplication lives only inline in `_on_battle_won`, extract a small pure static helper (in `Gambits.gd` or `CardDropUtil.gd`) so it is testable headlessly — `SceneManager._on_battle_won` itself needs a full scene tree and is not unit-testable.
5. **No-gambit default:** a `GameState` built without gambits matches today's baselines (hero 30 HP, no armor status, turn-1 draw happens).

### Constraints

- Do not change `TIER_WEIGHTS` values — only how the tier index is chosen.
- XP award (SceneManager lines 295–302) is NOT multiplied by gambits per the goal design (coins + drop rarity only); leave it untouched unless the Plan phase decides otherwise.
- Session stats: `session_stats["coins_earned"]` (line 293) must record the multiplied amount (it mirrors what was actually granted).
- Read `gambit_id` before line 303 (`clear_pending_battle()`); `clear_pending_battle_state()` (line 304) is also called there — ordering already safe if read alongside `enemy_type` at line 258.
- Docs to update after Build: `docs/agent/battle-system.md` (rewards section / integrations table rows for SceneManager and EnemyRegistry).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
