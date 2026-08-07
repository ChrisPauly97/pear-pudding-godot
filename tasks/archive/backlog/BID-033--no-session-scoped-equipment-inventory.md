# BID-033: No session-scoped equipment inventory — chest equipment drops can't be roll-granted

**Type:** gap (design/architecture)
**Discovered during:** GID-102 / TID-381 (Party loot rolls)
**Severity:** low

## Context

TID-381 added an opt-in need/greed roll for shared chest drops. The authority grants the
winner's cards + a coin reward directly into their GID-095 `SessionState` character record
via `SessionStore` (`WorldScene._grant_chest_loot_to_token`), mirroring how
`_transfer_card_in_session` (card trading) and party-bounty rewards already grant to a
member who may not be the local player.

**Equipment (weapons/armor/rings) has no session-record equivalent.** Single-player
equipment ownership lives on `SaveManager` (`owned_armor`, weapon-slot lookups via
`WeaponRegistry`/`sm.get_owned_by_slot`), which is local-only — there is no `owned_weapons`
/ `owned_armor` field on a `SessionState` character record the way there is `owned_cards`.
`_maybe_drop_equipment_from_chest` (the existing chest equipment-drop roll,
`WorldScene.gd`) writes straight to the local `SaveManager`.

**Consequence:** the need/greed roll path deliberately **skips equipment drops entirely**
(documented scope cut in `docs/agent/multiplayer-coop.md`) — only cards + a flat coin
reward are roll-eligible. A chest that would have had a 15–40% chance to drop a weapon/armor
piece under first-opener-takes silently loses that possibility when roll mode is on, rather
than granting it to an arbitrary (possibly remote) winner incorrectly.

## Options to resolve

- Add `owned_weapons: Array[String]` / `owned_armor: Array[String]` (+ equipped slots) to
  `SessionState`'s character record shape (a new migration), mirroring `owned_cards`, then
  extend `SessionStore`/the roll-grant path to write into it and `adopt_session_character`/
  `export_session_character` to round-trip it like the rest of the character slice.
- Once that exists, `_grant_chest_loot_to_token` can roll equipment drops into the roll pool
  too, matching the existing weapon_chance table (40% treasure rooms / 15% elsewhere).

## Notes

- Low severity: equipment drops are a chest **bonus**, not core loot; first-opener-takes
  (the default mode) is completely unaffected by this gap.
- No code change is required elsewhere — this is purely a missing session-record field +
  the plumbing to read/write it, scoped the same way GID-095's per-player character record
  was originally built out.

## Note on ID numbering

Originally filed as BID-025 from an isolated worktree (branched before BID-025 was claimed
elsewhere for an unrelated finding); renumbered to BID-033 during integration.

## Resolution

Took the first "Options to resolve" bullet, following the suggested shape with one
deliberate simplification called out below.

**`game_logic/net/SessionState.gd`** — `CURRENT_SESSION_VERSION` bumped **13 → 14** (13
was the highest version present when this task started; no conflicting parallel bump was
found). Each character record gains:
- `owned_weapons: Array[String]` — ids only, **no per-instance `upgrade_level`** (unlike
  `SaveManager.owned_weapons`, which is `Array[Dictionary]` of `{weapon_id,
  upgrade_level}`). Session equipment upgrades aren't modeled — the same "no seed
  economy" simplification the guildhall garden (v12) already uses. This is the one
  deliberate deviation from the BID's literal "mirroring whatever SaveManager already
  tracks for equipped state" — full upgrade-level tracking would need its own
  migration/round-trip surface for a feature (session weapon upgrading) that doesn't
  exist yet, so it was scoped out; noted here for visibility.
- `owned_armor: Array[String]`, `equipped_weapon: String`, `equipped_armor: String` —
  direct mirrors of the matching `SaveManager` fields.
- A v14 migration backfills all four fields (`[]` / `[]` / `""` / `""`) on every existing
  member record. `make_starter_character` seeds them the same way for a brand-new
  character.
- Only **weapon** and **armor** slots are session-scoped — `owned_rings`/`owned_trinkets`
  have no session equivalent yet, so ring/trinket chest drops remain first-opener-only.

**`autoloads/SaveManager.gd`** — `adopt_session_character(record)` now also loads
`equipped_weapon`/`equipped_armor` directly and converts the record's flat
`owned_weapons` id list into `SaveManager`'s own `{weapon_id, upgrade_level: 0}`
instances (deduped via the existing `_has_weapon_id` check; blank ids skipped); `owned_armor`
is loaded straight across. `export_session_character()` is the mirror image, flattening
`get_owned_by_slot("weapon")` back to ids and adding `owned_armor`/`equipped_weapon`/
`equipped_armor`. Both round-trip through the same `_loaded = false` isolation invariant
the rest of the character slice already uses — session equipment can never leak into
`save_slot_*.json`.

**`game_logic/net/LootRoll.gd`** — new pure, RNG-injected `roll_equipment_drop(tier,
weapon_ids, armor_ids, owned_weapon_ids, owned_armor_ids, rng) -> String`, plus two new
constants `EQUIPMENT_CHANCE_TREASURE_ROOM = 0.40` / `EQUIPMENT_CHANCE_DEFAULT = 0.15` —
copied from `WorldScene._open_chest`'s existing `weapon_chance` literals (40% for a
tier-3 `dtr_` treasure-room chest, 15% otherwise), the same table
`_maybe_drop_equipment_from_chest` already used for first-opener drops. Excludes the
starter `rusty_dagger` and any id already present in the passed-in ownership arrays.
Pure/injectable so it needs neither a live `SaveManager` nor a live `SessionStore` — fully
unit-tested.

**`scenes/world/coop/CoopActivities.gd`** — `_grant_chest_loot_to_token` now also calls
the new `_roll_equipment_into_loot_grant(rec, tier)`, which rolls `LootRoll.roll_equipment_drop`
against the **winner's own** session-record ownership (`rec.owned_weapons`/`owned_armor`,
so a winner never receives a duplicate they already hold), resolves the picked id's slot
via `WeaponRegistry.get_weapon(picked).slot`, and appends it into the matching array in
place before the record is persisted. No new wire message announces the specific
equipment drop (if any) — the winner discovers it the same way they discover granted
cards/coins, on their next character sync — kept minimal per the BID's own "low severity,
bonus not core loot" framing; `recv_loot_roll_result`'s existing winner-announcement toast
is unchanged.

**`docs/agent/multiplayer-coop.md`** updated: the old "equipment drops are out of scope
for a roll" note is replaced with a description of the new fields/flow, and a new "Session-
scoped equipment inventory (BID-033)" subsection documents the shape, the adopt/export
round-trip, and the roll logic.

**Tests added:**
- `tests/unit/test_session_state.gd` — 5 new tests: starter-character defaults, a plain
  round-trip through `to_dict`/`from_dict`, the v14 migration backfilling missing fields,
  the v14 migration preserving already-present fields, and a from-scratch (versionless)
  blob still ending up with the fields defaulted via the full migration chain.
- `tests/unit/test_session_equipment.gd` (new file) — 14 tests: `adopt_session_character`
  loading/deduping/defaulting the equipment fields and forcing `_loaded = false`;
  `export_session_character` flattening them back out; a full export→adopt→export
  round-trip stability check; and 7 pure-logic tests for `LootRoll.roll_equipment_drop`
  (treasure-room chance > default chance, never returns an already-owned id, excludes
  `rusty_dagger`, returns `""` when the pool is exhausted, deterministic for a fixed
  seed, and a statistical check over 300 trials that tier-3's hit rate exceeds tier-1's).

**Verification:** `godot --headless --editor --quit` parse-clean after every edit; full
unit suite (`tests/runner.gd`) 2374 passed / 0 failed / 1 pre-existing pending (up from
2355/0/1 before this work — all 19 new tests are the ones listed above);
`tests/world_scene_smoke.gd` 18/18 (the loot-roll RPC handlers, unaffected in name/shape,
still dispatch cleanly); `tests/net_world_sync_smoke.gd` (exercises the loot/chest sync
RPC surface `CoopActivities.gd` also owns) and `tests/net_session_smoke.gd` (exercises
`adopt_session_character`/`export_session_character` end-to-end over a real ENet loopback,
including the `save_slot_*.json`-isolation assertion) both still pass unchanged.
