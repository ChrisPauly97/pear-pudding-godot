# GID-099: Co-op Joint Battle Engine

## Objective

Generalize the battle engine so a **party of allies fights one shared enemy together**
in a single battle — each player keeps their own board/hand/mana, the enemy scales by
party size, and the boss drops a soulbound card to everyone.

## Context

`game_logic/battle/GameState.gd` is hardwired to **exactly two players**:
`players: Array[PlayerState]` is seeded with 2, `enemy()` returns
`players[1 - current_player_idx]`, and `player_turn_numbers = [1, 0]`. PvP (GID-091)
reuses this 2-player state under a host-authoritative mirror. Co-op PvE today is the
opposite of cooperative: `EnemyNPC.engage()` removes the enemy for everyone and the
engager fights the AI **solo** (GID-096 engage-locks).

The user wants real cooperative battles: the whole party in one battle vs a shared
boss. This goal builds the **engine** (state model, networking, scaling); the
**presentation** (square battlefield, cross-board cards) is GID-100.

This reuses the GID-091 host-authoritative model (no shared deterministic RNG): the
authority owns the one `GameState`, applies every player's intents, and broadcasts the
mirror. Extending from 2 to N participants is the core work.

**Out of scope:** the square-arena UI and cross-board card mechanics/content (GID-100);
PvP changes (GID-091/GID-101).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-359 | N-player co-op battle state model (N allies + shared boss) | agent | done | TID-355 |
| TID-360 | N-player host-authoritative battle networking | agent | done | TID-359 |
| TID-361 | Party-scaled enemies & shared soulbound drops | agent | done | TID-359 |

## Acceptance Criteria

- [ ] A `GameState` (or co-op battle variant) supports a party of N ally
      `PlayerState`s vs one shared enemy/boss `PlayerState`; turn order and the
      boss-acts-against-each-player loop are well-defined and unit-tested.
- [ ] 2–4 players join one shared battle from the world; intents from every client
      reach the authority and the mirror renders correctly on each (extends
      `BattleNetProtocol` / `BattleNetSync` to N acting peers).
- [ ] Enemy HP/deck/stats scale by participant count via a documented formula.
- [ ] On victory the boss drops a **soulbound** card to **every** participant; loss/flee
      semantics match the single-player rule (no persisted defeat on loss).
- [ ] Single-player, NPC-duel, PvP, puzzle, and Spire battles are unchanged — the
      2-player path hits zero new behavior. Full unit suite passes; headless import clean.
