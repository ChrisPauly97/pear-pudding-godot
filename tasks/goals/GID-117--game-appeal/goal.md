# GID-117: Game Appeal — Articulate & Prove "Why Play This"

## Objective

Answer "why would people play this game?" durably: write the appeal/positioning analysis down, verify the signature hooks actually surface in a new player's first session, and fix the gap where they don't.

## Context

The user asked "why would people play my game?" Research across the spec and 116 shipped
goals found the answer exists mechanically but not verbally, and is invisible experientially:

- **Distinctive hooks shipped:** Soulbinding — every enemy is a capturable card (GID-061);
  Card Cantrips — the deck shapes overworld traversal (GID-065); Battlefield Resonance —
  where you fight matters (GID-059); Veteran Cards — cards accrue history (GID-060);
  4-player co-op with joint battles, PvP, drafts and tournaments (GID-090…106) on a
  mobile-first indie RPG. These fuse the exploration layer and the card layer in ways that
  are rare in the genre.
- **Comfort/collector loop shipped:** Hobbit/Redwall-toned story, player home & garden,
  mounts, bestiary, night hunts, treasure maps — retention between battles.
- **Nothing articulates this.** `docs/human/specification.md` describes features, never
  appeal, audience, or differentiation. There is no elevator pitch anywhere in the repo.
- **The hooks don't surface early.** A new player's first session is menu → biome pick →
  tutorial → basic undead battle. Soulbinding and cantrips — the "why this game" systems —
  are never teased in that window.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-439 | Player appeal analysis doc (docs/agent/game-appeal.md) | agent | done | — |
| TID-440 | First-session hook audit — trace new-game → first-reward code path | agent | done | TID-439 |
| TID-441 | Surface signature hooks in first session (soulbind/cantrip teasers) | agent | done (headless run unverified in-sandbox) | TID-440 |
| TID-442 | Elevator pitch & positioning statement for specification.md | human-action | done (inserted by agent with explicit user permission) | TID-439 |
| TID-443 | New-game baseline fix + optional Head Start toggle (BID-049) | agent | done (headless run unverified in-sandbox) | — |

## Acceptance Criteria

- [x] `docs/agent/game-appeal.md` exists: player motivations served, target player profiles, unique hooks vs. genre neighbors (Hearthstone-likes, Zelda-likes, monster-collectors), and honest weaknesses — each claim grounded in a shipped GID
- [x] The first-session audit documents, with file/line references, when each signature hook (soulbinding, cantrips, resonance, veterancy, co-op) first becomes visible to a brand-new player; gaps logged as backlog items (BID-049 — resolved by TID-443; BID-050)
- [x] At least one signature hook is teased within the first session (soulbinding popup on first uncaptured-signature victory; cantrips popup on first visible cantrip button), with mobile/desktop parity per CLAUDE.md (both reuse the GID-031 TutorialPopup pipeline)
- [x] A drafted elevator pitch + positioning statement was presented to the user and, with their explicit permission, inserted into `docs/human/specification.md` (TID-442)
- [ ] All tests pass headless; headless import shows no parse/compile errors after any `.gd` edit — **unverified in-sandbox** (no Godot binary; proxy blocks the release download). Run `godot --headless --editor --quit` and `godot --headless --path . -s tests/runner.gd` in CI or a Godot-capable session; new suites: `test_hook_teasers.gd`, `test_new_game_baseline.gd`
