# GID-139: Combat Momentum — Always a Button to Press

## Objective

Make real-time combat feel active (WoW-like) instead of watching timers: every
global cooldown should have a meaningful press, and cards should feel like
payoffs rather than the only thing you can afford every 15 s.

## Context

User (2026-09-27): real time feels like being a passive observer; turn-based is
slow. Diagnosis: 400 max mana at 20/s with a 2 s spend pause meant a 3-cost card
every ~15 s; Strike was the only filler (6 s cooldown), so ~2/3 of GCDs were
idle while auto-attacks, Ally timers and minions did the work. User chose:
auto-attack as a toggle, mana earned by fighting (essence siphon), combo charges
spent by cards, occasional free-cast procs.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-576 | Auto-Attack Toggle & Essence Siphon | agent | done | — |
| TID-577 | Combo Charges Spent by Cards | agent | done | TID-576 |
| TID-578 | Essence Surge Free-Cast Procs | agent | done | TID-576 |
| TID-579 | Telegraphed Heavy Enemy Attacks | agent | todo | — |
| TID-580 | Hit Feel — Hit-Stop & Shake in Real Time | agent | todo | — |

## Acceptance Criteria

- [x] Strike is a free, cooldown-less filler; the GCD (1.2 s) is the only gate
- [x] Auto-attack toggles (button + F); on = siphon, off = faster vein regen
- [x] Skill hits build combo; the next card spends it for mana, full = instant
- [x] Procs make the next card free and instant, with a hand glow
- [ ] Enemies wind up heavy attacks worth Kicking or Guarding
- [ ] Your hits land with hit-stop / shake
