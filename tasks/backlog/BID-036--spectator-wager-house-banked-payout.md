# BID-036: Spectator wager settlement is house-banked, not parimutuel

**Category:** design-gap
**Discovered During:** GID-104 / TID-387

`WagerSync.settle()` pays every winning bettor 1:1 (2× stake credited since
stakes are pre-debited). If winning stakes exceed losing stakes the session
"mints" coins out of thin air; otherwise it absorbs the surplus. Acceptable for
a coins-only economy, but a pool-based (parimutuel) model would be
economy-neutral. Related deliberate choice worth revisiting at the same time:
grace-expired combatant forfeits refund all bets rather than paying out (anti-
grief: a losing combatant could otherwise burn bettors by yanking the cable),
which means a genuine walkover pays nobody.
