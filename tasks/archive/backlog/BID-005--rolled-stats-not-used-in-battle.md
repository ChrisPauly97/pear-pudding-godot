# BID-005: Player's per-instance rolled card stats are never applied in battle

**Category:** design-inconsistency
**Discovered During:** GID-060 research

## Description

GID-028 introduced per-instance card rarity with rolled stats (`owned_cards` entries carry
`uid, template_id, rarity, attack, health, cost`), but the battle system never uses them.
`BattleScene._ready()` builds the player deck via `SaveManager.get_deck_template_ids()`,
which strips instance UIDs down to template ID strings before `PlayerState.build_deck()`
creates fresh `CardInstance`s from registry templates. A legendary Ghost with rolled +2/+2
fights with base Ghost stats.

`SaveManager.get_deck_instances()` exists but has zero callers.

## Evidence

- `scenes/battle/BattleScene.gd` lines ~116–124 — deck built from template IDs only
- `game_logic/battle/PlayerState.gd` — `build_deck()` uses `CardRegistry.get_template(cid)` base stats
- `autoloads/SaveManager.gd` — `get_deck_instances()` unused
- Enemy decks DO get tier scaling, making the asymmetry more visible

## Suggested Resolution

Planned to be fixed as part of GID-060 / TID-216, which threads `collection_uid` into
`CardInstance` and adds a build-from-instances path. If GID-060 is deprioritized, this
should be fixed standalone — players currently get no battle benefit from rarity rolls.
