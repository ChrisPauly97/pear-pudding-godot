# GID-115: Top-Priority Bug Fixes — Co-op Desync, PvP Soft-Locks & Trade Integrity

## Objective

Fix the five highest-priority open bugs: the siege-boss solo/joint battle desync, PvP challenge soft-locks, the unenforced unique-card trade block, the overlapping Siege/Tournament HUD buttons, and the draft-duel resume deck corruption.

## Context

A triage pass over the open backlog (2026-07-08) ranked every open item by player
impact — visible desyncs and soft-locks first, then irreversible save damage, then
visible UI defects, then rarer state-corruption paths. The five selected items are all
confirmed still live in the current code (each was re-verified against HEAD during
goal research):

1. **BID-044** — the co-op siege boss engage races two `GameBus.enemy_engaged`
   listeners; the host can end up in a *solo* duel while clients enter the *joint*
   battle. Breaks a whole shipped feature (Town Siege, GID-103) in co-op.
2. **BID-034** — an unanswered PvP challenge (duel / wager / draft) leaves the
   challenger's pending state set forever, hiding buttons and blocking all further
   challenges until the peer disconnects. Soft-lock reachable by simply not answering.
3. **BID-030** — unique cards (`is_unique = true`) are documented as blocked from
   trading, but no code in the trade chain checks it. A player can irreversibly trade
   away a signature story card.
4. **BID-043** — the Siege and Tournament HUD buttons are both centered at
   `y = vp.y * 0.63` and visually overlap in a reachable state (host, siege-supported
   map, no active siege/tournament). Also finishes the GID-107 registry migration for
   the three buttons that were left behind.
5. **BID-035** — a host resuming a *draft duel* after a disconnect rebuilds its deck
   from the persistent collection instead of the transient drafted deck, silently
   corrupting the format.

Items considered and deliberately not selected: BID-036 / BID-037 (wager & tournament
economy models — design-gaps, partially deliberate choices, not correctness bugs),
BID-025 / BID-038 (host-only stats & spectator perspective — cosmetic/low impact),
BID-019 / BID-021 / BID-018-test-runner (headless-environment test failures — the
bestiary reward logic was verified as correctly wired at HEAD; these are runner
setup issues, not gameplay bugs), BID-006 (dead signals, no player impact).
BID-018 (EnemyRegistry DirAccess on Android) was found already fixed at HEAD —
see BID-046 for the backlog-hygiene follow-up.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-430 | Fix co-op siege boss engage race (solo vs joint battle desync) | agent | done | — |
| TID-431 | Add timeout to PvP challenge handshakes | agent | done | — |
| TID-432 | Enforce unique-card block in co-op trading | agent | done | — |
| TID-433 | Migrate Siege/Draft/Tournament buttons to HUD registry, fixing overlap | agent | done | — |
| TID-434 | Thread draft-deck override through PvP resume | agent | done | — |

All five tasks are independent and can be worked in any order.

## Acceptance Criteria

- [x] Engaging the co-op siege boss starts a joint battle on the host and all clients — never a solo duel on the host (TID-430)
- [x] An unanswered duel/wager/draft challenge resets the challenger's pending state after a timeout with a "No response" toast, and a new challenge can then be issued (TID-431)
- [x] A unique card cannot be offered, submitted, or transferred in a co-op trade — checked client-side and authority-side (TID-432)
- [x] Siege, Draft Duel, and Tournament buttons render via the WorldHUD zone/party-panel registry with no pixel overlap in any reachable state; the guardrail test allow-list shrinks accordingly (TID-433)
- [x] A host resuming a draft duel plays with the drafted deck, not its collection deck (TID-434) — see TID-434's Changes Made: this path is currently unreachable (only client idx 1 ever resumes; only the duel-host side consumes the override), but the override is now threaded through symmetrically end-to-end for correctness
- [ ] `godot --headless --editor --quit` reports no parse/compile errors after each task — **unverified in this sandbox**: no Godot binary available and the 4.6-stable release download is blocked by the outbound proxy (403) in every task of this goal; every edit was manually re-read post-change for brace/tab/type correctness instead. Recommend running this in CI before merge.
- [ ] Unit test suite passes (or failures are documented as pre-existing per BID-018/BID-019/BID-021) — **unverified in this sandbox** for the same reason; new suites added this goal (`test_trade_sync`, `test_scene_manager_state` additions, `test_challenge_timeout`, `test_pvp_resume`) follow the exact structure of already-passing sibling suites but have not been executed here.
