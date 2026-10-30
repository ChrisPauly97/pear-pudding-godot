# GID-188: Vertical Slice — Prove the Core Loop

## Objective

Carve a 30–45 minute vertical slice out of the shipped game and polish it until it proves the core loop is fun:
**explore → real-time card fight → soulbind the enemy into the deck → the deck changes the next fight and opens the
world (Dig)**. Out-of-slice systems are hidden behind one gate, never deleted, so the full game returns by flipping it.

## Context

- User (2026-10-30): "What's the MVP poc of this game to prove it's fun to play, can we build and polish that version
  so the scope doesn't explode" — approved the breakdown below.
- 187 goals already shipped; the slice is a cut, not new systems. **Feature freeze inside the slice:** new ideas go to
  the backlog; a slice change only lands if it improves the core loop.
- **In:** Madrian + starter camps (grassland/forest), levels 1–10, real-time battles, Strike / Mend / Kick, Allies,
  spells, companion, soulbinding, Deck Table, damage-school matchups, Dig as the one deck-unlocks-world moment,
  Maiteln intro, a slice boss + completion screen.
- **Out (hidden):** co-op, PvP, map editor, turn-based / puzzle / scripted modes, skill tree, bounties, night hunts,
  Phase, rifts / Spire, packs, professions, riding, deck-rule rows (tech slot, hand size, quick draw, redraw), other
  towns, sea / rivers / caves, Chapters 1–2 past the intro.
- **Pacing (user, 2026-10-30): not compressed** — ~4.5 h to level 10; fun is judged on the first 30 min via
  telemetry (TID-799). No hard region edge (levels 6–10 use the Chapter 1 road camps).
- Single source of truth: `game_logic/SliceRules.gd`; on/off via project setting `pear_pudding/slice_mode`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-794 | Slice gate + SliceRules table | agent | done | — |
| TID-795 | Fit starter-zone content to levels 1–10, slice boss + completion screen | agent | done | TID-794 |
| TID-796 | Capture moment polish (card reveal, deck-impact callout) | agent | done | TID-794 |
| TID-797 | Combat feel polish pass (hit-stop, impact, cast-bar readability) | agent | todo | TID-794 |
| TID-798 | First-30-minutes walkthrough audit + fixes | agent | todo | TID-795 |
| TID-799 | Playtest telemetry for fun metrics (AppLog) | agent | todo | TID-794 |
| TID-800 | Android build + performance check of the slice | agent | todo | TID-795 |
