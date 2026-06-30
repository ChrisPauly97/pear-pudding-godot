# TID-381: Party loot rolls (need/greed on drops)

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Shared loot today is **first-opener-takes** for chests (GID-096) and **soulbound-to-everyone**
for co-op boss drops (GID-099). A classic party-RPG alternative is a **need/greed roll**: when
a shareable drop appears, every present member rolls and the highest roll wins it. This task
adds an opt-in roll flow for shared chest drops (and optionally a bonus boss drop), keeping
first-opener-takes as the default.

## Research Notes

- **Pure roll helper — new `game_logic/net/LootRoll.gd`** (scene-free, unit-tested, mirrors
  `WorldObjectSync`): encode/decode for a roll session `{roll_id, item, rolls: {token: value},
  resolved, winner_token}` and individual roll intents. The **authority** rolls the RNG (so
  it's tamper-proof) — clients only submit `need` / `greed` / `pass` choices; the authority
  assigns the random value. Need beats greed; ties broken by highest value.
- **Trigger.** When a shared chest is opened in co-op (the `_on_chest_opened_coop` branch,
  `multiplayer-coop.md` → "Loot rule — first-opener-takes"), if **roll mode** is enabled for
  the session, instead of dropping locally for the opener, the authority opens a **roll
  session** for that drop and broadcasts a prompt to all same-map members. This *replaces* the
  first-opener-takes branch only when roll mode is on; default stays first-opener.
- **RPCs — `scenes/world/NetSync.gd`** (reliable):
  - `recv_loot_roll_start(payload)` (authority → all same-map) — show the roll prompt
    (item + Need/Greed/Pass buttons + a short timer).
  - `submit_loot_roll_choice(roll_id, choice)` (client → authority).
  - `recv_loot_roll_result(roll_id, winner_token, rolls)` (authority → all) — announce the
    winner; the authority grants the item to the winner's session character (reuse the
    GID-096 local-loot grant, but to the winner instead of the opener) and persists.
- **Settle.** Authority waits for all present members' choices or a timeout (auto-pass), rolls
  values for need/greed entrants, picks the winner, grants the loot into that member's GID-095
  character via `SessionStore`, broadcasts the result. No item is ever granted twice
  (authority-only grant, persisted into `opened_chests` exactly as today).
- **Mode toggle.** A session setting (host/lobby) "Loot: first-opener / need-greed". Store on
  `SessionState` (a simple `loot_mode: String`) or as a host-only runtime flag broadcast on
  join. Recommend `SessionState` so it persists; bump version with a migration (after the
  other Phase tasks).
- **Boss drops (optional).** GID-099 boss wins drop a soulbound card to **every** ally — that
  is generous and arguably shouldn't change. If a *bonus* roll item is desired, add it as an
  extra drop resolved by the same roll path; otherwise leave boss drops as-is and scope this
  task to **chest** drops.
- **UI.** A transient roll panel (BaseOverlay or a HUD popup): item icon + Need/Greed/Pass +
  countdown; a result toast naming the winner. Viewport-relative, mobile parity.
- **Tests:** `tests/unit/test_loot_roll.gd` — need>greed precedence, tie-break, all-pass,
  timeout-as-pass, encode/decode round-trip + garbage tolerance. Authority-RNG determinism
  with a seeded RNG for the test.
- **Docs:** update `docs/agent/multiplayer-coop.md` (extend the loot-rule section with the
  need/greed alternative + RPC + Tests tables).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
