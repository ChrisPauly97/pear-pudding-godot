# TID-212: Battlefield rules data model + capture biome/time at enemy_engaged

**Goal:** GID-059
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battles are currently identical regardless of where or when the encounter happens. This task builds the foundation of Battlefield Resonance: a data-driven rules table in `game_logic/battle/` mapping each biome to one board rule, capture of biome + time-of-day at the moment `GameBus.enemy_engaged` fires, and the game-logic implementation of all five biome rules plus the day/night Dawn/Dusk cost modifier. TID-213 adds the UI surface on top; TID-214 balances and tests.

Rules:
- **Grasslands (0)** — first card played each turn costs 1 less (floor 0).
- **Forest (1)** — board slots 0 and 4 (edges) grant Shroud to minions placed there.
- **Desert (2)** — at turn start during daytime, the leftmost minion on each board takes 1 scorch damage.
- **Scorched (3)** — all damage is +1.
- **Mountains (4)** — center slot (index 2) grants Ward to minions placed there.
- **Time:** at night, `magic_branch == "dusk"` cards cost 1 less (floor 0); during day, `magic_branch == "dawn"` cards cost 1 less.

Named maps / dungeons (no biome) use a neutral "dungeon" ruleset or no rule — decide in Plan phase.

## Research Notes

**Engagement flow (verified):**
- `GameBus.enemy_engaged(enemy_data: Dictionary)` declared at `autoloads/GameBus.gd` line 4.
- Emitted by `EnemyNPC.engage()` — `scenes/world/entities/EnemyNPC.gd` lines 73–87. It duplicates `enemy_data`, adds `enemy_deck` / `is_boss` / `boss_hp` / `phase2_deck` from `EnemyRegistry`, then `GameBus.enemy_engaged.emit(edata)` at line 86. `engage()` is called from `scenes/world/WorldScene.gd` line 1179 (`enemy.engage()` in the interact path). **`enemy_data` does NOT currently carry position, biome, or time** — only `id`, `enemy_type`, `alive`, plus the fields added in `engage()`. (GID-057 mimic chests and GID-054 sieges also emit `enemy_engaged` with hand-built dicts — they will fall through to the neutral path unless context is added centrally.)
- Listener: `SceneManager._on_enemy_engaged(enemy_data)` — `autoloads/SceneManager.gd` lines 226–244. Guards deck size, calls `save_manager.set_pending_battle(enemy_data)` (SaveManager line 656 — duplicates the dict, and `pending_battle_enemy_data` is persisted in the save file, line 427), then instantiates BattleScene and sets `_battle_overlay.enemy_data = enemy_data`.
- Resume path: `WorldScene.gd` line 239 re-emits `GameBus.enemy_engaged.emit.call_deferred(SceneManager.save_manager.pending_battle_enemy_data)` — so context fields stored inside `enemy_data` automatically survive mid-battle save/resume. **Recommended: stamp `battlefield_biome: int` and `battlefield_is_night: bool` (or raw `battlefield_time: float`) into the dict.** Best stamping point is `SceneManager._on_enemy_engaged()` (central — covers EnemyNPC, mimics, sieges, but must skip re-stamping when the dict already has context from a resumed battle) or `EnemyNPC.engage()` (misses other emitters). Decide in Plan.

**Where biome lives (verified):**
- `WorldScene._current_biome: int` — `scenes/world/WorldScene.gd` line 62, initialised −1, updated in `_update_chunks()` line 544: `InfiniteWorldGen.biome_for_chunk(pcx, pcz, WORLD_SEED)`.
- `InfiniteWorldGen.biome_for_chunk(p_cx, p_cz, world_seed) -> int` — static, `game_logic/world/InfiniteWorldGen.gd` line 51. Safe zone (Manhattan dist ≤ 5) returns `forced_start_biome` or GRASSLANDS.
- Biome ids: `game_logic/world/BiomeDef.gd` — `GRASSLANDS=0, FOREST=1, DESERT=2, SCORCHED=3, MOUNTAINS=4, COUNT=5`.
- Named-map detection: `WorldScene._is_infinite: bool` — line 37, set at line 182: `(map_name == "infinite" or map_name == "main")`. On named maps `_current_biome` stays −1. Use −1 (or a dedicated `BIOME_NONE`) as the neutral/dungeon key.
- SceneManager can reach the world scene: it already does `var scene := get_tree().current_scene; if scene.has_method(...)` (lines 88–89, 221–224). Add e.g. `WorldScene.get_battlefield_context() -> Dictionary` returning `{ "biome": _current_biome if _is_infinite else -1, "time_of_day": _time_of_day }`.

**Where time-of-day lives (verified):**
- `WorldScene._time_of_day: float` — line 79; comment: `0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset`. Advanced in `_update_day_night()` (line 952) every 0.5 s.
- Persisted copy: `SaveManager.time_of_day: float` — `autoloads/SaveManager.gd` line 42 (default 0.4); flushed by `WorldScene.flush_time_of_day()` (line 378), which SceneManager invokes via `has_method("flush_time_of_day")` at SceneManager lines 88–89.
- Night predicate (established in GID-055, `tasks/goals/GID-055--night-hunts/TID-200--nocturnal-spawns.md`): night ⇔ `sin((time_of_day - 0.25) * TAU) < 0` ⇔ `time_of_day < 0.25 or time_of_day > 0.75`.

**Battle logic hook points (verified):**
- `game_logic/battle/` contains `GameState.gd`, `PlayerState.gd`, `HeroState.gd`, `ZoneState.gd`, `CardInstance.gd`, `Keywords.gd`. New rules file goes here, e.g. `game_logic/battle/BattlefieldRules.gd` (pure static const table + helpers; preload it per CLAUDE.md — do not rely on `class_name` visibility).
- **Cost checks:** `PlayerState.can_play(card)` (line 64) and `play_card(card)` (line 71) compare `hero.mana >= card.cost` and call `hero.spend_mana(card.cost)`. Both player UI and `BasicAI` (`ai/BasicAI.gd` lines 16 and 65 use `ai.can_play(card)`) go through these — so an `effective_cost(card)` helper on PlayerState (taking battlefield context + a per-turn `first_card_played` flag for Grasslands) automatically covers AI affordability. Context must therefore reach PlayerState/GameState, not just BattleScene. Suggested: store context on `GameState` (e.g. `battlefield_biome: int`, `is_night: bool`) and include it in `GameState.to_dict()/from_dict()` (lines 53–71) so mid-battle resume keeps it (resume restores `GameState.from_dict(saved)` in `BattleScene._ready()` lines 109–112 and skips `enemy_data` processing).
- **Grasslands per-turn flag:** reset point is `PlayerState.start_turn()` (line 84) or `GameState.end_turn()` (line 31). Discount applies in `effective_cost` until the first successful `play_card` of that turn.
- **Slot-based keywords (Forest/Mountains):** `ZoneState.add_card(card)` (`ZoneState.gd` line 25) places into `first_empty_slot()` — **the UI drop slot does not currently choose the board index**; placement is always lowest empty index, for both player drops and AI. Grant keyword at placement: after `board.add_card(card)` in `PlayerState.play_card()` (line 79, where Surge is already handled via `card.keywords.has(Keywords.SURGE)`), find the slot index (`board.slots.find(card)`) and if it matches the rule slots, append the keyword to `card.keywords` and (for Shroud) set `card.shroud_active = true`. Keyword constants: `game_logic/battle/Keywords.gd` — `WARD`, `SURGE`, `SHROUD`. Ward granted this way is automatically honoured by `BattleScene._get_ward_valid_targets()` and `BasicAI` `ward_targets` (see docs/agent/battle-system.md, "Keyword Game Logic (TID-094)"). Shroud semantics: `CardInstance.take_damage()` absorbs the first hit while `shroud_active`.
- **Desert turn-start scorch:** `BattleScene._on_turn_ended(player_idx)` (BattleScene.gd line 1175) already runs `_process_start_of_turn_statuses(player_idx)` wrapped in HP snapshot / float-label / flash calls (lines 1176–1181) — add the scorch tick in the same block so feedback is free. "Leftmost minion" = lowest non-null index in `ZoneState.slots`. "During daytime" uses the captured context (`not is_night`), frozen at engagement.
- **Scorched +1 damage:** damage flows through `CardInstance.take_damage()` and `HeroState.take_damage()` plus many call sites in `BattleScene.gd` (minion combat lines 1112–1113, 1150–1151; spells in `_resolve_spell_effect` line 1258; emergence line 1230; status ticks lines ~1638/1658). Plan phase must choose: a global damage-modifier hook (e.g. static `BattlefieldRules.modify_damage(base, context)` applied at attack/spell call sites) vs. inside `take_damage()` (simplest but also inflates poison ticks/scorch itself — decide scope and document it). Beware double-counting attacker/defender mutual damage.
- **GameBus from game_logic:** `GameState.end_turn()` shows the safe autoload-access pattern for RefCounted classes (lines 35–39, via `Engine.get_main_loop()`); tests run headless with autoloads available (`--path .`).

**Constraints:**
- Per CLAUDE.md: preload new scripts (`const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")`), explicit types for `max/min/clamp/array[i]`, `.uid` sidecar only needed for `.tres`/`.gdshader` (plain `.gd` is fine), never `ResourceLoader.load()` with dynamic paths. If a `BattlefieldRules` const table (not a `.tres` resource) suffices, prefer it — simpler and no sidecar.
- `effective_cost` must clamp at 0 (`maxi(0, ...)`); Grasslands + branch discount can stack — define stacking order explicitly.
- Mid-battle persistence: `CardInstance.to_dict()` already serialises `keywords` and `shroud_active`, so rule-granted keywords survive resume. Battlefield context needs explicit serialisation (GameState dict and/or enemy_data fields).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
