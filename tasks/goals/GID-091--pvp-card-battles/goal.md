# GID-091: PvP Card Battles over Co-op

## Objective

Two players in a co-op session can challenge each other to a real TCG card battle, reusing the existing battle engine and the GID-090 networking, synced under a host-authoritative model.

## Context

GID-090 shipped a thin co-op slice: two players share the named map **madrian**
and see each other's avatar move. Battles were explicitly out of scope. This goal
extends that slice so the two players can actually fight a **card battle against
each other** — the first networked use of the TCG engine.

The battle engine is already a clean two-player model: `GameState.players[0]` is
the local human and `players[1]` is the opponent, normally driven by `BasicAI`.
For PvP we replace the AI with the remote human's relayed inputs. Rather than
lockstep (which would require deterministic shared RNG for shuffles/draws), we use
**host-authoritative state mirroring**, which reuses the existing
`GameState.to_dict()` / `from_dict()` serialization (built for GID-034 mid-battle
save/resume):

- The co-op **host** (`NetworkManager.is_host()`) owns the one canonical
  `GameState`. From the host's side `players[0]` = host, `players[1]` = client.
- The **client** never simulates authoritatively. It sends *intents*
  (play card / attack / end turn / hero power / potion / surrender) over a
  **reliable** RPC. The host validates against the canonical state, applies them,
  then broadcasts the serialized `GameState` back.
- The client renders the received mirror **from its own perspective**
  (`_local_player_idx == 1`): its own board/hero at the bottom, the host's at the
  top, and input is gated to its own turn.

Initiation reuses the interact/duel pattern: walk up to the other player and a
"Challenge to Battle" prompt appears; both must accept. Outcomes are **duel-style**
— no card drops, no coins, no enemy-defeat tracking (this avoids loot
duplication/desync); winning is bragging rights. The co-op session is preserved and
both players return to madrian. A mid-battle disconnect is an auto-forfeit for the
leaver.

Everything is **additive and guarded**: single-player and NPC battles are
byte-for-byte unchanged when no PvP session is active.

**Explicitly out of scope:** rewards/wagers, >2 players, spectating, reconnection
into an in-progress battle, NAT traversal (LAN/loopback only, inherited from
GID-090), and the Steam transport (still stubbed).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-328 | PvP action wire protocol (pure logic + unit tests) | agent | done | — |
| TID-329 | Battle RPC relay node + host-authority scaffolding | agent | done | TID-328 |
| TID-330 | BattleScene PvP perspective, input gating & AI disable | agent | done | TID-329 |
| TID-331 | Challenge handshake & SceneManager PvP routing | agent | done | TID-330 |
| TID-332 | PvP result, rewards policy & disconnect forfeit | agent | done | TID-331 |
| TID-333 | Loopback PvP smoke test & agent docs | agent | done | TID-332 |
| TID-334 | Spec update: multiplayer no longer out-of-scope | human-action | pending | — |

## Acceptance Criteria

- [ ] A pure `BattleNetProtocol` encodes/decodes every PvP intent (play_card_at_slot, play_card spell, attack, end_turn, hero_power, potion, surrender) and the full-state mirror payload, with passing unit tests.
- [ ] A fixed-name `BattleNetSync` relay node under BattleScene carries **reliable** RPCs (`send_intent`, `sync_state`, `pvp_ended`) resolving to the same path on both peers; the host is the co-op host via `NetworkManager.is_host()`.
- [ ] In a PvP battle, `BasicAI` never runs; the host applies the client's relayed intents to the canonical `GameState` and broadcasts `to_dict()`; the client renders the mirror from `_local_player_idx == 1` and can only act on its own turn.
- [ ] Walking up to the other co-op player shows a "Challenge to Battle" prompt; on mutual accept both peers enter a PvP `BattleScene`, and both return to the shared madrian world when it ends.
- [ ] PvP outcomes award no cards/coins and don't mark enemies defeated; a synced victory/defeat overlay shows on both peers; an opponent disconnect mid-battle ends the battle as a forfeit win for the remaining player.
- [ ] Single-player and NPC battles are unchanged (verified); a loopback two-peer smoke test exercises an intent round-trip + state mirror; `tests/runner.gd` exits 0 and a headless editor import reports no parse/compile errors.
- [ ] `docs/agent/multiplayer-coop.md` and `docs/agent/battle-system.md` document the PvP system; the human spec's multiplayer "out of scope" line is updated (TID-334).
