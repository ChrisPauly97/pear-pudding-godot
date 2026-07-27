# TID-471: AI Opponent GameBus Emissions

Goal: [GID-125](goal.md) · Backlog: BID-006 · Type: agent · Status: done

## Problem

BID-006 reported `GameBus.card_played` / `card_attacked` / `battle_ended` as
declared-but-never-emitted. Tracing every action path showed emissions *did*
exist in `BattleScene` for local human actions and for PvP/co-op relayed
actions — but `ai/BasicAI.gd`'s Callables mutate `PlayerState`/`CardInstance`
directly, bypassing `_do_play_card_at_slot()` / `_execute_attack()` entirely.

So in the primary single-player mode the signals fired for the player's own
actions and silently dropped every enemy action — a half-wired bus is worse than
an unwired one, because a future subscriber would look correct and under-report.

## Changes Made

`ai/BasicAI.gd` — emit `card_played` and `card_attacked` from the AI's play and
attack Callables, mirroring `BattleScene`'s emission points and signatures
exactly (spell → `("spell", -1)`, minion → `("board", slot_index)`; attack →
`(attacker_template, "hero" | target_template)`).

The play emission is gated on `ai.play_card(c)`'s return value, which is
`-> bool` (`game_logic/battle/PlayerState.gd:146`) and was previously discarded
— so a rejected play no longer reports as a play.

## No Double-Fire

`_execute_attack()` (local human), `_resolve_remote_attack()` (PvP/co-op relay)
and `BasicAI`'s Callables are three disjoint paths for three disjoint actors.
Verified none overlap for a single action.

`BasicAI` is `RefCounted`, but calling the `GameBus` autoload from a non-`Node`
script is established here (`scenes/battle/BattleFx.gd` does the same).

## Behavioural Impact

None today — no `.connect()` listeners exist for these three signals, and
`AppLog` subscribes only to a curated allowlist that excludes them. This makes
the signals truthful for future subscribers.

## Follow-up

Three *further* never-emitted GameBus signals were found by an independent audit
and are filed as **BID-056**: `exited_to_world`, `world_event_started`,
`world_event_ended`.

## Documentation Updates

`docs/agent/battle-system.md` — Integrations table; also corrected the
`battle_ended` description (it fires only on the standard single-player PvE
path; PvP/co-op/team/puzzle/scripted modes use dedicated `*_battle_ended`
signals).
