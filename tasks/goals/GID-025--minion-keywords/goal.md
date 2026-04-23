# GID-025: Minion Keywords — Ward, Surge, Shroud

## Objective

Add three passive minion keyword abilities (Ward, Surge, Shroud) to the card system, implement their game logic, display them on cards, and introduce new keyword-bearing cards to the card pool.

## Context

All minions currently behave identically beyond their stats. Keywords are permanent passive properties printed on a card that change how it interacts with the board — a 2/3 with Ward plays completely differently from a 2/3 without it. This is the primary source of board puzzle depth in TCG games and the biggest gap between the current battle system and something that feels strategically rich.

**Keyword definitions:**
- **Ward** — Enemy attacks must target this minion before any other friendly minion (while alive)
- **Surge** — This minion can attack the same turn it is summoned (no summoning sickness)
- **Shroud** — The first time this minion takes damage, the damage is absorbed and Shroud is removed

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-093 | Keyword data model — add keywords to CardData and CardInstance | agent | done | — |
| TID-094 | Keyword game logic — Ward attack redirection, Surge summon, Shroud absorption | agent | pending | TID-093 |
| TID-095 | Keyword UI — display keyword badges on cards in hand and on board | agent | pending | TID-093 |
| TID-096 | Keyword card content — new .tres card files bearing keywords | agent | pending | TID-094, TID-095 |

## Acceptance Criteria

- [ ] CardData and CardInstance support a `keywords: Array[String]` field
- [ ] Ward: enemy AI targets Ward minions first; player must target Ward minions first when attacking
- [ ] Surge: a Surge minion can attack the turn it is summoned (summoning_sick = false on placement)
- [ ] Shroud: first hit on a Shroud minion is absorbed; Shroud badge is removed; subsequent hits deal damage normally
- [ ] Keywords are clearly displayed on cards in hand and on the board (badge or label)
- [ ] At least 6 new cards exist bearing one or more keywords
- [ ] All tests pass headless
