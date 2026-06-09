# TID-197: Siege Model & State

**Goal:** GID-054
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The pure data model and logic for siege triggering, gauntlet progression, hero HP carry-over between battles, and save persistence. All state is managed in SaveManager with a new autoload helper (`SiegeDefs.gd`) containing pure static predicates and enemy roster.

## Research Notes

- **New script:** `game_logic/SiegeDefs.gd` (no class_name, used via preload). Pure static helpers; no instance state:
  - `should_trigger(flags: Dictionary, days_elapsed: int, last_siege_day: int, world_seed: int) -> bool` — evaluates the three conditions:
    1. **Gating flag:** `flags.get("chapter1_warned_farsyth", false)` must be true (matches the real mid-chapter flag from **docs/agent/story-implementation.md** line 41, which is set when the player speaks to Lord Farsyth in `farsyth_mansion`). Before this flag, zero sieges fire.
    2. **Cooldown:** `days_elapsed - last_siege_day >= 4` (at least 4 in-game days since the last siege; `last_siege_day` is initialized to 0 on new game, so the first siege can trigger on or after day 4).
    3. **Determinism:** `hash(world_seed ^ days_elapsed) % 100 < SIEGE_SPAWN_CHANCE` (currently 8 = ~8% per-day probability, seeded via the world seed XOR'd with the current day to make the same save+day always trigger the same outcome — matches the pattern used in **InfiniteWorldGen.seed_rng()** for chunk determinism, verified in **docs/agent/world-generation.md**).
  - Returns true only if all three are satisfied. Called on map load (from WorldScene when entering a town).
  - `get_raider_deck_ids(stage: int) -> Array[String]` — returns the card IDs for raider deck stage 0/1/2 (increasing difficulty: tier 1 → 2 → 3). Uses seeded RNG via world_seed to shuffle the pool so different saves get different decks.
  - `get_stage_name(stage: int) -> String` — returns `"Wave 1 of 3"`, `"Wave 2 of 3"`, or `"Wave 3 of 3"` for interstitial text.
  - `SIEGE_SPAWN_CHANCE: int = 8` — probability %.

- **Three raider EnemyData resources** in `data/enemies/`:
  - `martarquas_raider_1.tres` — difficulty_tier 1, deck pool of 4–5 mid-tier ghoul/undead cards, ~40 HP total.
  - `martarquas_raider_2.tres` — difficulty_tier 2, 5–6 cards, ~60 HP total.
  - `martarquas_raider_3.tres` — difficulty_tier 3, 6–7 cards, ~80 HP total.
  - All three are registered in **autoloads/EnemyRegistry.gd** via preload + array registration (follow the existing pattern in EnemyRegistry; cite the exact registration lines when implementing).
  - Create companion `.uid` files for each `.tres` (format: `uid://[12 lowercase alphanumeric]`, generated via `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`). See **CLAUDE.md: Godot Resource .uid Files** section.

- **SaveManager fields** (append to existing structure around line 100):
  - `siege: Dictionary = {}` — active siege state; structure: `{ town: String, stage: int, hero_hp: int, day_started: int }`. Empty dict `{}` means no active siege.
  - `last_siege_day: int = 0` — the `days_elapsed` value when the last siege ended (win or loss); used in cooldown check.
  - Add both to `_migrate()` (e.g., after line 121 in **autoloads/SaveManager.gd**) with defaults: `siege = {}`, `last_siege_day = 0`.
  - **Migration version:** Next version is 15 (current is 14, line 106 of SaveManager.gd). Add comment `# v15: siege, last_siege_day` in the migration history table (insert new row after line 106).
  - Methods:
    - `start_siege(town: String) -> void` — sets `siege = { town, stage: 0, hero_hp: 30, day_started: days_elapsed }` and marks dirty.
    - `get_active_siege() -> Dictionary` — returns `siege` (or empty dict if none).
    - `advance_siege_stage() -> void` — increments `stage` from 0 to 1 to 2 and marks dirty.
    - `set_siege_hero_hp(hp: int) -> void` — updates `siege["hero_hp"]` = hp.
    - `end_siege_victory() -> void` — sets `last_siege_day = days_elapsed`, clears `siege = {}`, marks dirty.
    - `end_siege_defeat() -> void` — same as victory; both are identical except they may trigger different outcome logic in WorldScene/SceneManager.

- **Carry-over HP injection:** The player's hero HP must be read from `siege["hero_hp"]` when building the gauntlet battle if one is active, instead of the default 30.
  - **BattleScene.gd _ready() path:** After checking `pending_battle_state` (around line 248 per **docs/agent/battle-system.md** line 246), check `save_manager.get_active_siege()`. If a siege is active:
    ```gdscript
    var siege_state = save_manager.get_active_siege()
    if not siege_state.is_empty():
        _state.players[0].hero.health = siege_state.get("hero_hp", 30)
        _state.players[0].hero.max_health = siege_state.get("hero_hp", 30)
    ```
    This ensures the player's hero starts with the carry-over HP value instead of max HP.
  - **HeroState initialization:** `HeroState.new(pid)` initializes health/max_health to 30 (lines 5–6 of **game_logic/battle/HeroState.gd**). This is the baseline; the override in BattleScene._ready() after construction is the cleanest path.

- **Gauntlet chaining via SceneManager:** When `_on_battle_won()` is called (line 253 of **autoloads/SceneManager.gd**), add a check after the standard battle rewards (after line 302) and before `clear_pending_battle()` (line 303):
  ```gdscript
  var siege = save_manager.get_active_siege()
  if not siege.is_empty():
      # Capture hero HP before clearing battle
      var hero_hp = _state.players[0].hero.health
      save_manager.set_siege_hero_hp(hero_hp)
      # Check if there are more stages
      if siege.get("stage", 0) < 2:  # stages 0, 1, 2 → more after 0 and 1
          save_manager.advance_siege_stage()
          save_manager.save()
          # Immediately re-engage the next raider
          var next_enemy_type = "martarquas_raider_%d" % (siege.get("stage", 1) + 1)
          var next_enemy = EnemyRegistry.get_enemy(next_enemy_type)
          GameBus.enemy_engaged.emit(next_enemy)
          return
      else:
          # All 3 stages won → TID-199 handles rewards
          # DO NOT clear the siege yet; TID-199 will call end_siege_victory()
          pass
  ```
  Cite **autoloads/SceneManager.gd** lines 253–308 as the context for this insertion.

- **Tests (headless):**
  - `tests/test_siege_trigger.gd` — verify `should_trigger()` with all three conditions (flag, cooldown, determinism). Test that:
    - False when chapter1_warned_farsyth is unset.
    - False when cooldown not satisfied (days_elapsed - last_siege_day < 4).
    - True when all three met, at a deterministic percentage.
    - Same world_seed + day always yields same trigger result (determinism).
  - `tests/test_siege_state.gd` — SaveManager round-trip: start siege, advance stage, set HP, serialize, deserialize, verify all fields. Test migration from v14 to v15.
  - `tests/test_gauntlet_chain.gd` — mock SceneManager._on_battle_won() with active siege, verify HP captured, stage incremented, and game state not cleared until final stage.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
