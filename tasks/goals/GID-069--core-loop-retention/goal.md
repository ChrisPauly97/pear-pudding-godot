# GID-069: Core Loop Retention & Ease-of-Use

## Objective

Remove the friction points in the fight → reward → rebuild-deck → fight loop that push players to quit: the dead-end defeat flow, unavoidable/unescapable battles, invisible rewards, tedious deck building, and fixed battle pacing.

## Context

Recent goals added content depth (cards, keywords, skill trees, story). This goal targets the loop players repeat hundreds of times instead. Research found five concrete leaks:

1. **Defeat is a dead end** — `SceneManager._on_battle_lost()` frees the entire world scene and routes to a bare `GameOverScene` whose only option is "Return to Menu"; resuming requires Continue + a full world reload.
2. **Battles can't be avoided or escaped** — enemies auto-engage on proximity with no visible difficulty tier, and there is no flee/concede.
3. **Rewards are mostly invisible** — the victory overlay shows only the card name; coins, XP, and rolled rarity are awarded silently in `SceneManager._on_battle_won()` *after* the overlay closes. Level-up is a passive toast with no path to spend skill points.
4. **Deck builder lacks filters and auto-fill** — sorting exists but with 46+ card templates, rarities, and per-instance stats, building a deck is tedious tapping.
5. **No battle pacing control** — enemy turns use fixed `await` delays with no speed setting.

Deliberately excluded (already pending goals): tap-to-move (GID-047), wayfinding (GID-049), fast travel (GID-044), deck loadouts (GID-058), bestiary (GID-045).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-250 | Defeat recovery: keep world alive on loss; defeat screen with Retry and Respawn | agent | pending | — |
| TID-251 | Enemy difficulty pips in world + Flee option in battle pause menu | agent | pending | TID-250 |
| TID-252 | Full reward presentation: coins/XP/rarity on victory screen; level-up prompt links to skill tree | agent | pending | — |
| TID-253 | Deck builder QoL: type/cost/rarity filters + auto-fill deck button | agent | pending | — |
| TID-254 | Battle speed setting: fast-mode toggle halving AI/animation delays, persisted | agent | pending | — |

## Acceptance Criteria

- [ ] Losing a battle no longer frees the world scene; the defeat screen offers Retry Battle (same enemy, fresh battle) and Respawn (return to the live world) in addition to Return to Menu
- [ ] World enemies display their difficulty tier visibly before engagement; battles can be fled from the pause menu (no rewards, enemy survives, brief re-engage grace period)
- [ ] The victory screen shows the card with its rolled rarity, coins earned, and XP earned; leveling up surfaces unspent skill points with a direct route to the skill tree
- [ ] The deck builder can filter the collection by card type, mana cost, and rarity, and an Auto-Fill button completes the deck to a legal size with a sensible heuristic
- [ ] A persisted battle-speed setting (normal/fast) at least halves enemy-turn and animation delays in fast mode
- [ ] Mobile parity for every new control (touch-operable, viewport-relative sizing per CLAUDE.md)
- [ ] All tests pass headless
