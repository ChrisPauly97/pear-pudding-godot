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
