# GID-060: Veteran Cards — Cards That Remember

## Objective

Each owned card instance tracks kills and battles survived, earning veterancy ranks with small stat bumps, earned titles (e.g. "Ghost the Relentless"), and player renaming.

## Context

GID-028 made every owned card a unique per-instance entry (`SaveManager.owned_cards: Array[Dictionary]` with `uid`, `template_id`, `rarity`, rolled `attack`/`health`/`cost`). This goal extends that per-instance model into **battle memory**:

- Per-instance counters `kills` and `battles_survived`, persisted in `save.json` alongside the existing instance fields.
- Rank thresholds (e.g. rank 1 at 5 kills or 10 battles, rank 2 at 15/25, rank 3 at 40/60 — exact numbers decided in Plan phase) grant small stat bumps (+1 HP or +1 ATK per rank) and an earned title suffix.
- Player can rename veteran cards in the Inventory; renamed/titled name shows on the card face in battle.
- Emotional hook: the deck becomes a roster of individuals with history, not interchangeable copies.

**Architectural crux discovered during research:** battle decks are currently built from template ID strings only — `BattleScene._ready()` calls `SaveManager.get_deck_template_ids()` and collection UIDs never enter the battle engine (`PlayerState.build_deck(card_ids: Array[String])` creates fresh `CardInstance`s with their own unrelated `instance_id`). `SaveManager.get_deck_instances()` exists but has zero callers. TID-216 must thread a `collection_uid` through battle `CardInstance` so kills/survival can be attributed back to collection entries. As a side effect this also closes a latent GID-028 gap: per-instance rolled stats are currently *not* applied to the player's cards in battle.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-215 | Veterancy data model, rank thresholds, SaveManager persistence | agent | pending | — |
| TID-216 | Battle hooks: attribute kills/survival to collection instances post-battle | agent | pending | TID-215 |
| TID-217 | UI: rank chevrons + title on card face, rename dialog in Inventory | agent | pending | TID-216 |

## Acceptance Criteria

- [ ] Every entry in `SaveManager.owned_cards` carries `kills: int`, `battles_survived: int`, and `custom_name: String` fields; old saves migrate cleanly (save version bump + migration func backfilling defaults).
- [ ] A pure helper (no autoload dependency) computes veterancy rank (0–3) from kills/battles_survived and resolves the earned title suffix and per-rank stat bumps.
- [ ] After a won battle, kills made by each player deck card and survival are written back to the matching collection instance via its UID; lost battles grant nothing (or per Plan-phase decision, documented).
- [ ] Battle `CardInstance`s built from the player's deck carry `collection_uid`, and the field round-trips through `to_dict()`/`from_dict()` so mid-battle save/resume (GID-034) does not lose attribution.
- [ ] Rank stat bumps (+1 HP or +1 ATK per rank, exact scheme decided in Plan) apply to the card's effective battle stats.
- [ ] Inventory shows rank chevrons and the titled/renamed name per instance; a rename dialog lets the player rename a card (touch-reachable, per the mobile parity rule in CLAUDE.md).
- [ ] The titled/renamed name displays on the card face in battle (`NameLabel` in `_build_card_vbox`/`_update_card_view`).
- [ ] Unit tests cover rank threshold math, persistence/migration, and post-battle attribution; `godot --headless --path . -s tests/runner.gd` exits 0.
- [ ] `docs/agent/inventory-and-deck.md` and `docs/agent/battle-system.md` updated; new feature doc or section describing veterancy.
