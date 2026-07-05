# TID-401: Scripted Battle Framework — Fixed Deck, Deterministic Draw, Tutorial Prompts

**Goal:** GID-108
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Story-driven tutorial battles need full determinism: a fixed player deck (ignoring the player's collection), a scripted draw order so cards are introduced one at a time, a reduced opening hand, a fixed weak enemy, and per-turn guidance popups. First consumer: the rabbit-hunt battle (TID-402); second: the Chapter 2 ambush (TID-407).

## Research Notes

- **Deck/draw internals:** game_logic/battle/PlayerState.gd — `draw_deck: Array[CardInstance]`, `build_deck()` fills then calls `draw_deck.shuffle()` (~line 59), `draw_card()` does `draw_deck.pop_back()` (~line 96–102), `draw_opening_hand(count: int = 4)` (~line 114). A scripted battle needs an ordered deck with NO shuffle — note pop_back means the array must be reverse-ordered relative to the desired draw sequence — and an opening hand count of 1.
- **Precedent for seeded battles:** game_logic/battle/PuzzleData.gd is an @export Resource describing a frozen board state, consumed by `GameState.load_puzzle` (game_logic/battle/GameState.gd ~line 227, preloads PuzzleData via `const PD = preload(...)`). Model `ScriptedBattleData` on it: fields for `battle_id`, `player_deck_order: Array[String]` (draw order, first-drawn first), `opening_hand_count: int`, `enemy_deck: Array[String]`, `enemy_hero_hp: int`, `enemy_plays_scripted: bool` / per-turn enemy plays, `tutorial_steps` (e.g. Array of "turn:trigger:text" strings), `reward_card_id`, `completion_flag`.
- **Tutorial popups:** GID-031 popup tutorial guide system — scenes/ui/TutorialPopup.gd; check how existing popups are triggered (SceneManager/GameBus have tutorial references). Reuse for Maiteln's per-turn lines; key steps to turn number and simple board-state triggers (e.g. first summon, first attack available).
- **Resource sidecars:** any new .tres needs a .uid sidecar (CLAUDE.md "Godot Resource .uid Files"); new .tres must be preload()ed, never ResourceLoader.load() (Android rule). Registry pattern: preload consts iterated in `_ensure_loaded()` (see autoloads/CardRegistry.gd / EnemyRegistry.gd).
- **Battle entry:** SceneManager routes battles; enemy battles carry `enemy_deck`/`enemy_type` dictionaries (see WorldScene `_spawn_rival_at` for the edata shape and SceneManager battle-finish handling ~line 990–1020). A scripted battle should enter through the same overlay flow with a `scripted_battle_id` marker so completion sets the right flag and awards nothing from the normal drop path unless specified.
- **Validation rule:** run `godot --headless --editor --quit` after any .gd edit (CLAUDE.md); GDScript strict typing pitfalls (`:=` Variant inference) documented in CLAUDE.md.
- Add pure-logic tests in tests/ (GUT): deterministic draw order, opening hand count, no shuffle, completion flag set.

- **Co-op (up to 4 players):** this feature must follow the TID-408 design rules (shared-flag arbitration via SessionState, exactly-once beat effects, authority-broadcast narration, single synced Maiteln, no write-through to solo saves). Read TID-408--coop-story-compatibility.md before Plan.

## Plan

Model this closely on the existing Puzzle Battle Mode (`PuzzleData`/`PuzzleRegistry`/
`GameState.load_puzzle`) precedent — same shape, new determinism requirements (real
draw deck instead of a frozen board, opening-hand count, turn-keyed popups).

1. **`game_logic/battle/ScriptedBattleData.gd`** (`class_name ScriptedBattleData extends Resource`)
   + `.uid` sidecar:
   - `battle_id`, `title`
   - `player_deck_order: Array[String]` (first-drawn-first), `opening_hand_count: int = 1`, `player_hero_hp: int = 30`
   - `enemy_deck_order: Array[String]` (same convention, fixed weak enemy), `enemy_opening_hand_count: int = 1`, `enemy_hero_hp: int = 10`
   - `tutorial_steps: Array[String]`, format `"<player_turn_number>:<text>"` (split with maxsplit=1 so `text` may contain colons)
   - `reward_card_id: String`, `completion_flag: String`
   - `validate() -> Array[String]` mirroring `PuzzleData.validate()` (unknown card ids, malformed tutorial_steps, empty battle_id)

2. **`autoloads/ScriptedBattleRegistry.gd`** — same const-preload + `_ensure_loaded()` pattern as
   `PuzzleRegistry.gd`. Register in `project.godot` `[autoload]`. Add one `data/scripted_battles/scripted_test.tres`
   fixture (+ `.uid`) mirroring `puzzle_test.tres`, for tests and future dev tooling.

3. **`PlayerState.build_scripted_deck(draw_order: Array[String], dark_aligned: bool = false) -> void`**
   — same body shape as `build_deck()` minus `draw_deck.shuffle()`; appends in `draw_order`
   then `draw_deck.reverse()` so `draw_card()`'s `pop_back()` yields `draw_order[0]` first, `[1]` second, etc.
   No difficulty scaling (fixed weak enemy is authored directly via card choice, not tier scaling).

4. **`GameState.load_scripted_battle(d: Resource) -> void`** — new method alongside `load_puzzle`:
   sets `scripted_battle: bool` / `scripted_battle_id: String` (new fields, serialized in `to_dict`/`from_dict`
   for parity with `puzzle_mode`/`puzzle_data_id` even though mid-battle save is disabled for this mode too),
   sets both heroes' hp from the data, calls `build_scripted_deck` + `draw_opening_hand(count)` for both
   sides, sets `current_player_idx = 0`, `turn_number = 1`, `player_turn_numbers = [1, 0]`. No board
   pre-population (unlike puzzles) — this is a real deck-and-draw battle, just deterministic.

5. **`BattleScene.gd`**:
   - New `var scripted_data: Resource = null` (set by SceneManager before `_ready`, mirrors `puzzle_data`) and
     `var _scripted_data_ref: Resource = null` (retained reference, mirrors `_puzzle_data_ref`).
   - `_ready()` branch: `elif scripted_data != null:` → build `GameState.new()`, `_resolver.setup(_state)`,
     `_state.load_scripted_battle(scripted_data)`, `_wire_gamebus_emitter()`. Placed as a new `elif` alongside
     the existing `puzzle_data != null` / `_pvp` / `_coop_pve` / `_team_pvp` chain.
   - Skip mid-battle persistence: extend the existing `puzzle_mode_fn` Callable passed to `_pause_ui.setup()`
     to `func() -> bool: return _state.puzzle_mode or _state.scripted_battle`.
   - Skip capture-tracker init (line ~399 guard) and weather banner (~440) and battlefield info/slot highlight
     (~446) by adding `and not _state.scripted_battle` — these systems assume a normal infinite-world battle
     and would just be dead weight / visual noise on a deterministic story battle, same reasoning as the
     existing `puzzle_mode` exclusion.
   - Turn-keyed tutorial popups: after `_state.turn_ended` fires for the player (`_on_turn_ended(0)` — existing
     handler), if `_scripted_data_ref != null`, look up `_state.player_turn_numbers[0]` against
     `_scripted_data_ref.tutorial_steps`, and if a step matches, show it via a direct `TutorialPopup` instantiation
     (NOT through `GameBus.tutorial_popup_requested` / `SceneManager._on_tutorial_popup_requested`, which is
     gated by a global "seen once ever" flag keyed to a static `TutorialRegistry` dict — wrong fit for
     per-battle scripted story content). Also check turn 1's step once in `_ready()` after building state,
     since `turn_ended` only fires on `end_turn()`, never for the opening turn.
   - `_check_game_over()`: new branch `if _state.scripted_battle:` (checked before the existing
     `puzzle_mode`/`friendly_duel`/normal-reward branches, same position as the existing early-return checks)
     → win: sfx + haptic + `_result_ui.show_scripted_result(true, _scripted_data_ref.battle_id)`; loss: sfx +
     haptic + `_result_ui.show_scripted_result(false, _scripted_data_ref.battle_id)`. Both emit
     `GameBus.scripted_battle_ended(battle_id, did_win)` from the Continue button (mirrors `show_ghost_duel_result`).
     No retry-in-place loop in the framework — TID-402's specific content is responsible for "impossible to
     soft-lock" (a fixed deck that cannot lose); a loss here just returns to the world same as any other exit,
     and the trigger can be re-approached.

6. **`BattleResultUI.gd`**: `show_scripted_result(did_win: bool, battle_id: String) -> void` — same structure as
   `show_ghost_duel_result` (title/subtitle/Continue button), emits `GameBus.scripted_battle_ended(battle_id, did_win)`.

7. **`GameBus.gd`**: add `signal scripted_battle_requested(battle_id: String)` and
   `signal scripted_battle_ended(battle_id: String, did_win: bool)`, grouped near the existing
   `puzzle_requested`/`puzzle_solved` signals.

8. **`SceneManager.gd`**: connect both new signals in the same block as
   `GameBus.puzzle_requested.connect(...)`. `_on_scripted_battle_requested(battle_id)` mirrors
   `_on_puzzle_requested` (look up via `ScriptedBattleRegistry`, `TransitionManager.transition`, swap in
   `BattleScene` with `.scripted_data` set, `_state = State.BATTLE`). `_on_scripted_battle_ended(battle_id, did_win)`
   mirrors `_on_puzzle_solved`/`return_from_puzzle`: on win, look up the data by id, set `completion_flag` via
   `save_manager.set_story_flag()` if not already set and non-empty, grant `reward_card_id` via
   `save_manager.grant_card_reward(id, "rare")` if non-empty (same rarity convention as puzzle rewards); either
   way, `save_manager.save()`, free `_battle_overlay`, `_restore_world()`.

9. **Tests** (`tests/unit/test_scripted_battle.gd`, `tests/unit/test_scripted_battle_registry.gd`) mirroring
   `test_puzzle_mode.gd`/`test_puzzle_registry.gd`: deterministic draw order (draw N cards, assert exact
   sequence matches `player_deck_order`), opening hand count, no-shuffle guarantee (build twice, compare
   resulting order — no RNG involved so this is just an equality check), `scripted_battle`/`scripted_battle_id`
   set + serialization round-trip, registry lookup returns the test fixture, `validate()` catches bad data.

10. **Co-op note (per TID-408 Research Notes):** this task only builds the single-player framework. The
    TID-408 design rules already document the co-op approach (joint battle with per-seat scripted decks, or
    solo-fight-and-share-flag fallback) — no co-op wiring needed here; flagged as-is for TID-408 to consume.

11. **Docs:** add a "Scripted Tutorial Battles" section to `docs/agent/battle-system.md` (alongside the
    existing "Puzzle Battle Mode" section) describing the data model, registry, determinism mechanism, and
    entry/exit signals.

**Validation:** `godot --headless --editor --quit` is unavailable in this sandbox (no Godot binary; network
egress to github.com release downloads is blocked by org policy — confirmed via the proxy status endpoint,
not retried per instructions). This mirrors the same constraint noted in GID-103/105/110's goal notes. All
GDScript will be written with extra care against the CLAUDE.md pitfalls (Variant inference, typed arrays,
`class_name` preload discipline) and cross-checked by re-reading each edited file; the headless import and
test run should be performed by a human/CI before merge — noted in Changes Made.

## Changes Made

_Filled after Build phase._

## Changes Made

- **`game_logic/battle/ScriptedBattleData.gd`** (+ `.uid`): new `Resource` — fixed
  player/enemy deck order (first-drawn-first), opening hand counts, hero HP,
  turn-keyed `tutorial_steps` (`"<turn>:<text>"`), `reward_card_id`,
  `completion_flag`, `validate()`.
- **`autoloads/ScriptedBattleRegistry.gd`** (+ `.uid`): new autoload, const-preload
  + `_ensure_loaded()` pattern mirroring `PuzzleRegistry`. Registered in
  `project.godot` `[autoload]`.
- **`data/scripted_battles/scripted_test.tres`** (+ `.uid`): dev/test fixture,
  mirrors `puzzle_test.tres`.
- **`game_logic/battle/PlayerState.gd`**: new `build_scripted_deck(draw_order, dark_aligned)`
  — builds `draw_deck` from `draw_order` then `reverse()`s it (no shuffle) so
  `draw_card()`'s `pop_back()` yields the authored sequence exactly.
- **`game_logic/battle/GameState.gd`**: new `scripted_battle: bool` /
  `scripted_battle_id: String` fields (serialized in `to_dict`/`from_dict`); new
  `load_scripted_battle(d: Resource)` — sets both heroes' HP, builds each side's
  scripted deck, draws each side's opening hand, resets turn counters.
- **`autoloads/GameBus.gd`**: new signals `scripted_battle_requested(battle_id)`,
  `scripted_battle_ended(battle_id, did_win)`.
- **`autoloads/SceneManager.gd`**: connects both signals; `_on_scripted_battle_requested`
  mirrors `_on_puzzle_requested` (look up via registry, transition into
  `BattleScene` with `.scripted_data` set); `_on_scripted_battle_ended` mirrors
  `_on_puzzle_solved` (sets `completion_flag`, grants `reward_card_id` as
  `"rare"`, saves, restores world).
- **`scenes/battle/BattleResultUI.gd`**: new `show_scripted_result(did_win, battle_id)`
  — Continue button emits `scripted_battle_ended`.
- **`scenes/battle/BattleScene.gd`**: new `scripted_data`/`_scripted_data_ref`
  fields; `_ready()` branch builds the scripted `GameState`; extended the
  `puzzle_mode_fn` passed to `BattlePauseUI` to also skip mid-battle save for
  scripted battles; excluded capture tracker, weather banner, Battlefield
  Resonance UI, companion HUD, potion button, and the once-per-battle companion
  passives (mirrors existing `puzzle_mode` exclusions — same reasoning: these
  assume a normal infinite-world battle and would undermine determinism); the
  generic first-battle tutorial and `"tap_and_hold"` popup are skipped in favor
  of the scripted battle's own turn-keyed popups; new
  `_maybe_show_scripted_tutorial_step(player_turn_number)` shows a direct
  `TutorialPopup` for the matching `tutorial_steps` entry (deliberately not
  routed through the global "seen once ever" `TutorialRegistry` system), called
  from `_ready()` (turn 1) and `_on_turn_ended(0)` (subsequent turns), deduped
  per turn number; `_check_game_over()` has a new `scripted_battle` branch
  (checked alongside the existing `puzzle_mode`/`ghost_duel`/`friendly_duel`
  early-returns) that shows `show_scripted_result` on win or loss — no
  retry-in-place loop; a loss just returns to the world (the "impossible to
  soft-lock" guarantee is a content responsibility for TID-402, not this
  framework).
- **`tests/unit/test_scripted_battle.gd`** (+ `.uid`), **`tests/unit/test_scripted_battle_registry.gd`**
  (+ `.uid`): 21 new tests covering deterministic draw order (including
  cross-build determinism and unknown-card skipping), opening hand count and
  content, per-side scripted decks, hero HP, serialization round-trip,
  registry lookups, and `validate()`.

**Not done in this task (by design — see Research Notes / Plan):** the actual
rabbit-hunt content (deck, tutorial text, world trigger) is TID-402; co-op
seating for scripted battles is TID-408.

**Validation:** `godot --headless --editor --quit` and the unit test run could
not be executed in this sandbox — no Godot binary is installed, and network
egress to fetch the Godot 4.6 release from github.com is blocked by
organization policy (confirmed via the proxy status endpoint; not retried per
instructions). This mirrors the same constraint hit in GID-103/105/110. All
edits were re-read after writing and cross-checked against the CLAUDE.md
GDScript pitfalls (Variant inference, typed-array literals, `class_name`
preload discipline); one real bug was caught this way — an `Edit` that
under-matched `_dismiss_battle_tutorial()`'s body relocated its trailing
`set_story_flag("tutorial_battle_tip")` line into the new tutorial-step
function, which was caught on review and fixed before finishing. A human or
CI run of the headless import + `tests/runner.gd` is still recommended before
merge.

## Documentation Updates

- `docs/agent/battle-system.md`: new "Scripted Story Battles (GID-108 / TID-401)"
  section (after "Puzzle Battle Mode") covering the data resource, registry,
  determinism mechanism, BattleScene integration points, entry/exit signals,
  and the co-op note pointing to TID-408.
