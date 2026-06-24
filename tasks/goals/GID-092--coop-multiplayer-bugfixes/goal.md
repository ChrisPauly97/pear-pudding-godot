# GID-092: Co-op Multiplayer Bug Fixes

## Objective

Make the co-op slice reliably playable end-to-end: every player has a usable deck, the host button works on repeat presses, and launching a co-op PvP battle never crashes the other player.

## Context

Co-op (GID-090) and PvP card battles (GID-091) shipped as a vertical slice. Hands-on
testing surfaced three breakages that make the feature feel broken on first contact:

1. Launching co-op cold from the main menu drops you into madrian with **no deck**, so
   the "Challenge to Battle" flow refuses to start ("deck too small").
2. The **Host Game** button only works the first time — re-hosting after a prior session
   silently fails, forcing players to use Find Games instead.
3. When a co-op PvP battle is launched, the **other player crashes**.

See `docs/agent/multiplayer-coop.md` for the architecture these fixes touch.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-335 | Co-op session loads a usable deck | agent | done | — |
| TID-336 | Fix client crash when a co-op PvP battle launches | agent | done | — |
| TID-337 | Host button reliability — reset stale session before re-hosting | agent | done | — |

## Acceptance Criteria

- [ ] Launching co-op (host or join) from the menu lands both players in madrian with a
      non-empty, valid deck; the challenge flow starts without a "deck too small" block.
- [ ] Pressing **Host Game** works repeatedly within a session lifetime — re-hosting after
      leaving a prior session succeeds without needing Find Games.
- [ ] Accepting a co-op battle challenge launches the PvP battle on **both** peers with no
      crash; the client mirrors host state and plays to completion.
- [ ] Single-player battles, NPC duels, puzzles, and Spire runs are byte-for-byte unchanged.
