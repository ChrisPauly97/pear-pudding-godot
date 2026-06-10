# TID-232: Battle rules fixes

**Goal:** GID-064
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The audit found multiple battle-rules bugs: two purchased passives and two legendary
cards are completely non-functional, the BasicAI can corrupt game state, and two rules
asymmetries favor the AI. User decisions: the AI's +1 mana edge is a **bug** (equal ramp),
and AI minions **do take hero retaliation** on face attacks.

## Research Notes

1. **`starting_mana`/`passive_mana` wiped (high).**
   `game_logic/battle/HeroState.gd:35-37` `gain_mana_for_turn()` unconditionally sets
   `max_mana = min(10, turn); mana = max_mana`, so the bonuses applied at
   `scenes/battle/BattleScene.gd:192-194, 212-215` are erased by
   `_state.players[0].start_turn(1)` at :151 before the player acts. Fix: add a
   `bonus_mana` field to HeroState, include it inside `gain_mana_for_turn`, serialize it
   in to_dict/from_dict.

2. **`bonus_draw` consumed once (high).** `game_logic/battle/PlayerState.gd:84-87` +
   BattleScene.gd:128-129, 218-219: dawn_clarity ("draw 1 extra card each turn",
   data/skills/dawn_clarity.tres) is applied only at battle start; `start_turn()` never
   reads it. Fix: loop `bonus_draw` extra `draw_card()` calls in `start_turn`.

3. **Dead legendary spells (high).** `spell_effect = "extra_turn"` (time_warp.tres) and
   `"destroy_all_draw_3"` (soul_harvest.tres) have no case in `_resolve_spell_effect`'s
   match (`scenes/battle/BattleScene.gd:1258-1376`); both are `auto_resolve` so they
   silently do nothing. Fix: implement both handlers (extra_turn: skip the AI's next
   turn / re-run player turn; destroy_all_draw_3: kill all minions both boards into
   discard, draw 3).

4. **BasicAI double-discard corruption (high).** `ai/BasicAI.gd:43-53`: attack Callables
   capture `tgt` at planning time; two attackers on the same minion → second closure
   attacks a corpse, takes retaliation from it (:46), and `discard.append(tgt)` (:50)
   appends the same CardInstance twice. After reshuffle (PlayerState.gd:47) one object
   exists twice in `draw_deck` → two board slots, double serialization. Fix: re-check
   `tgt.is_alive()` and re-select targets at execution time.

5. **AI planning is stale (medium).** `ai/BasicAI.gd:14-30`: the attack list is built
   before queued plays execute, so AI Surge minions never attack the turn they're
   played; `can_play` is checked against full mana per hand card, so later plays
   silently fail after earlier ones spend mana (yet BattleScene plays an attack SFX per
   action at :1215). Fix: decide plays/attacks incrementally at execution time —
   combines naturally with fix 4.

6. **Equal mana ramp (user decision: bug).** `game_logic/battle/GameState.gd:31-34` +
   `HeroState.gd:35-36`: `turn_number` is shared, incremented every half-turn, and
   mana = min(10, turn) → P1 ramps 1/3/5/7 while AI gets 2/4/6/8. Fix: per-player turn
   counter so both ramp 1/2/3… **Update `tests/test_game_state.gd:99-116`** which
   codifies the old behaviour. Serialize the new counter for pause/resume.

7. **Retaliation symmetry (user decision: AI takes it too).**
   `scenes/battle/BattleScene.gd:1150-1151` vs `ai/BasicAI.gd:36-37`: player minions
   attacking the enemy hero take `hero.attack` retaliation; AI minions attacking the
   player hero take none. Fix: add `mc.take_damage(state.opponent().hero.attack)` (and
   death/discard handling) in the AI hero-attack path so `passive_atk` matters on
   defense.

8. **Hero power bypasses damage pipeline (medium).** `BattleScene.gd:524-527`
   `active_damage_all` mutates `card.health -=` directly (ignores Shroud/armor) and
   killed minions are removed but not appended to `discard` — they vanish from reshuffle
   and `resurrect_last`. Fix: use `take_damage()` and mirror kill handling at
   :1117-1119.

9. **AI auto-spells never resolve (medium, latent).** `_flush_auto_spells`
   (BattleScene.gd:1380-1384) is only called for player 0; AI-drawn `auto_resolve` cards
   pile up in `pending_auto_spells` (PlayerState.gd:53-55) and AI `play_card` never
   resolves spell effects. All 4 current enemy decks are minion-only, but fix it now:
   flush/resolve for player 1 in `_execute_ai_actions`.

10. **Empty-board targeted spells are dead plays (low).** `BattleScene.gd:370-383`:
    targeted spells auto-resolve when the board is empty — mana spent, card discarded,
    no effect. Fix: refuse the drop (return card to hand).

Tests: test_basic_ai, test_game_state, test_player_state, test_hero_state assert current
behaviour — update alongside. Add a regression test for the double-discard case (two
attackers, one target) and for bonus_mana/bonus_draw across turns. No test currently
covers Ward/Surge/Shroud at BattleScene level (out of scope here; noted in BID-012).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
