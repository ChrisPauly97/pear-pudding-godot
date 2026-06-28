# GID-100: Co-op Battle Design — Square Battlefield & Cross-Board Cards

## Objective

Give the co-op joint battle a distinctive presentation — a **square/diamond arena**
showing every party member's board plus the shared boss — and a **cross-board card
mechanic** where cards can affect *allies'* boards and heroes, backed by a set of new
support cards.

## Context

GID-099 builds the N-player battle **engine** (state, networking, scaling). This goal is
the **design/UX payoff** the user specifically asked for: a battlefield that visibly
shows your co-op friends' boards, and cards that let you help them (shield their board,
heal their hero, buff their minion, lend mana).

`BattleScene` today is a fixed two-zone stack: `$EnemyArea/EnemyBoardView` (top) and
`$PlayerArea/PlayerBoardView` (bottom), with a perspective swap via `_local_player_idx`.
A co-op battle needs to render N ally boards + the boss simultaneously — a different
layout — and card targeting must be able to reach an ally's board, which no card can do
today (spells target `{hero}` / `{side, slot}` on the two-player axis only).

**Out of scope:** the engine/state/networking (GID-099); non-co-op battle layouts
(2-player PvP/NPC/puzzle/Spire keep their existing UI).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-362 | Square battlefield arena UI — render all ally boards + boss | agent | pending | TID-360 |
| TID-363 | Cross-board card targeting — affect allied boards & heroes | agent | pending | TID-359 |
| TID-364 | Co-op support card content — ally-affecting cards | agent | pending | TID-363 |

## Acceptance Criteria

- [ ] In a co-op battle the screen shows a square/diamond arena: the boss at the head,
      each party member's board (with their name/color) around the edges, and the local
      player's hand at the bottom. Scales/reflows for 2, 3, and 4 players and is
      viewport-relative + mobile-usable.
- [ ] A card/spell can target an **ally's** minion or hero; targeting UI lets the player
      pick which board, and the effect is networked through the host-authoritative mirror
      (uses the per-player target field from TID-360).
- [ ] A content set of co-op support cards exists (e.g. ally shield, ally heal, ally
      buff, mana gift, revive) as `.tres` with `.uid` sidecars, registered in
      `CardRegistry` via `preload`.
- [ ] The standard 2-player battle UI and all existing cards are unchanged; headless
      import clean; full unit suite passes.
