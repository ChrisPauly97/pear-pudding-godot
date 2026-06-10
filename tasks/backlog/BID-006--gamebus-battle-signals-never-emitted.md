# BID-006: GameBus battle signals declared but never emitted

**Category:** code-smell
**Discovered During:** GID-060 / GID-061 research

## Description

`GameBus` declares `card_played`, `card_attacked`, and `battle_ended` signals, and
`docs/agent/battle-system.md` lists them as live integration points, but nothing in the
codebase ever emits them — only `turn_ended` is emitted (from `GameState.end_turn()`).
Any future subscriber (capture tracking, veterancy attribution, achievements) that relies
on these signals will silently receive nothing.

## Evidence

- `autoloads/GameBus.gd` — signal declarations present
- No `emit` call sites for `card_played` / `card_attacked` / `battle_ended` anywhere in
  `game_logic/` or `scenes/battle/` (verified during GID-060 and GID-061 research)
- `docs/agent/battle-system.md` "Integrations" table incorrectly implies they fire

## Suggested Resolution

Either emit them at the real action sites in `BattleScene` / `GameState`
(`_on_enemy_card_input`, `_on_enemy_hero_input`, `_resolve_spell_effect`, AI attack
Callables) or remove the dead declarations and correct `docs/agent/battle-system.md`.
GID-061 / TID-218 will need real emissions (or direct tracker calls) regardless — fix
opportunistically there.
