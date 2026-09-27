# TID-547: Real-Time Combat — Full Mode

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-546

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Take the prototype to the default combat mode after user playtest: fill the known gaps and tune timings.

## Research Notes

- Gaps listed in `docs/agent/combat-model.md` → Known prototype gaps: periodic pulse for status effects /
  per-turn passives / weather / gambits; per-unit swing bars and a real cast bar (BattleFx); mid-battle save of
  timers (`to_dict`); enemy ability cards (with TID-541); tutorials (`BattleTutorials.gd`, TutorialRegistry) rewritten
  for real time; make real time the default for solo PvE; decide PvP/co-op (host-authoritative tick over
  `BattleNet` is feasible later).
- Card costs in mana points (`CardData.cost` ×100 in `.tres` + migration) so costs like 150 are possible;
  show costs as points on card faces / inspect overlay (`CardInspectOverlay` shows template cost).
- Replace `BattlePacing` turn budgets with real-time budgets (GCD, cast time, swing interval) and keep the guard test.

## Plan

Full-mode TID-547 originally listed several gaps (see Research Notes). By the time this session
ran, several had already shipped as their own tasks: card costs in mana points and per-unit
swing/cast bars (TID-546 follow-ups), tutorials rewritten for real time (TID-552/553), real-time
already the default flow for a fresh solo PvE fight, and mana points already landed. This session
scopes to the one gap still open and explicitly named in `docs/agent/combat-model.md` → Known
prototype gaps: **"Turn-keyed effects don't tick: status durations (poison/freeze/stun),
once-per-turn passives, weather per-turn effects, gambit per-turn rules."** Enemy ability cards,
mid-battle save/resume of real-time state, and PvP/co-op real time stay out of scope (separate
tasks — TID-541, and a save-format task respectively).

1. Audit every turn-keyed hook: `CardInstance.start_turn()` (attack_count/summoning_sick reset,
   stun/`out_of_play` decay), `BattleFx.process_start_of_turn_statuses()` (poison damage+decay,
   freeze decay, hero poison), `PlayerState.start_turn()` (`grasslands_card_played` first-card
   discount reset — draw/mana already excluded, real time owns those), `BattleModifiers.
   _apply_desert_scorch()` (desert biome leftmost-minion damage). Gambits have no periodic
   per-turn rule in code today (only turn-1 one-offs at battle setup), so there is nothing there
   to replicate.
2. Add a per-side "combat round" pulse to `RealtimeCombat.gd`, on a new `CombatTuning` knob
   (`round_seconds`, default 6 s) rather than a bare constant — this file already reads every
   other timing from `tune` (TID-549), so a bare constant would be the one number the in-battle
   Tune panel couldn't touch. Each side pulses independently (mirrors the existing per-side
   GCD/mana/draw timer pattern), since sides now act asynchronously and (with adds, TID-551)
   there can be more than two.
3. On a side's pulse, run that side's upkeep in the same order the turn-based path runs it (reset
   attack_count/summoning_sick + decay stun, *then* tick poison/freeze, then the discount reset,
   then desert scorch) — pure logic in `RealtimeCombat.gd`, unit-testable without a scene.
4. Turn-based fights are untouched: nothing in `GameState`, `PlayerState`, `CardInstance`,
   `BattleFx`, or `BattleModifiers` changes, so their behaviour stays byte-identical.
5. One deliberate improvement over the turn-based original: a card poisoned to 0 HP is removed
   from the board immediately (the turn-based `_tick_statuses_on_card` leaves a 0-HP corpse on
   the board until something else removes it — a pre-existing quirk, not touched here since
   turn-based must stay byte-identical; real time has no later turn boundary to lazily clean it up
   on, and a lingering corpse would otherwise block that slot for the rest of the fight).

## Changes Made

- `game_logic/battle/CombatTuning.gd`: new `round_seconds` knob (6 s default, 1–15 s range,
  "Status effects" group) — editable live from the in-battle Tune panel like every other timing.
- `game_logic/battle/RealtimeCombat.gd`: added a per-side `_round_timer` (grown in `_init_side`,
  so a joining add — TID-551 — gets one too). `advance()` calls a new `_tick_round(side, ...)` for
  every alive side, emitting a `{"type": "round", "side": side}` event when a side's timer elapses.
  `_run_round_upkeep(side)` runs, in order: `CardInstance.start_turn()` for every board card
  (attack_count/summoning_sick reset, stun/out_of_play decay — unchanged method, called from the
  new site), `_tick_card_status()` (poison damage+decay, freeze decay — mirrors `BattleFx.
  _tick_statuses_on_card`, plus removes a card poisoned to death), `_tick_hero_status()` (hero
  poison — mirrors `BattleFx._tick_statuses_on_hero`), the `grasslands_card_played` reset, and
  `_scorch_leftmost()` (desert biome — mirrors `BattleModifiers._apply_desert_scorch`, applied to
  that side's own board on that side's own pulse rather than both boards on every turn-end as the
  turn-based version quirkily does — one scorch tick per side per `round_seconds`, not two per
  full round).
- `tests/unit/test_realtime_combat.gd`: added coverage for the round pulse firing per side
  independently, poison ticking (and removing a dead card) on a unit, poison ticking on a hero,
  freeze/stun decay, the first-card discount reset, desert scorch applying only in the desert
  biome and only in daylight, and the `round_seconds` tuning knob actually changing the pulse
  period. Added `# gdlint: disable=max-public-methods` (the file's test count now exceeds
  gdtoolkit's 30-method ceiling, same pragma other large test files already carry).
- `game_logic/battle/RealtimeCombat.gd` also picked up `# gdlint: disable=max-file-lines` — it
  crossed 500 lines with this change (tracked debt per CLAUDE.md, not a new file).

## Documentation Updates

- `docs/agent/combat-model.md`: removed "Turn-keyed effects don't tick" from Known prototype gaps
  and added a "Round pulse (TID-547)" subsection describing `round_seconds`, what it runs, and the
  poisoned-to-death cleanup difference from the turn-based path.
