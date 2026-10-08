# GID-178: Combat Pacing & Feel

## Objective

Real-time fights have a steady rhythm of player actions (about a few per 10 s), and the moments that matter (a card drawn, an auto-attack swing) are animated.

## Context

User (2026-10-08): "we also need to tune for actions per 10s or so, currently lvl fight feels weird cause you draw a new strike so rarely, perhaps edit how much damage it does but let it happen more often / and maybe animation for card draw, auto attack wind up or effect".

Today a technique goes to the bottom of the deck once resolved (GID-175: "deck cycling is its cooldown"), and the hand draws one card every 9 s. With a 13-card starter deck, Strike comes round once every ~2 minutes; a level-1 fight is auto-attacks and waiting.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-724](TID-724--actions-per-10s.md) | Actions per 10 s: sim metric, techniques return to hand on a cooldown, Strike re-tuned, bands re-baselined | agent | done | — |
| [TID-725](TID-725--card-draw-animation.md) | Card draw animation in real-time fights | agent | done | — |
| [TID-726](TID-726--auto-attack-feel.md) | Auto-attack wind-up and hit effect | agent | done | — |

## Acceptance Criteria

- [x] `balance_sim` reports player actions per 10 s; the level ladder sits in a target band
- [x] Strike is played every few seconds, with lower damage; balance bands still pass
- [x] Drawn cards animate into the hand
- [x] Hero auto-attacks wind up visibly and land with an impact effect
