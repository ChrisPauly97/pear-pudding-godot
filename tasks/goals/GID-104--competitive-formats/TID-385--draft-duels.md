# TID-385: Draft Duels — Sealed-Deck PvP

**Goal:** GID-104
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP today pits full collections against each other, so a veteran always outguns a new player. A sealed/draft format where both duelists build decks live from identical seeded card pools is the fairest possible PvP. Draft duels let any two connected players challenge each other into a restricted format with zero collection advantage—the only skill that matters is deck-building choices in the pick flow. This reuses two shipped systems: the Endless Spire draft UI/pick mechanics (GID-038) for the 1-of-3 pick flow, and the Card Packs seeded roll logic (GID-050, `CardPackRegistry` + `roll_with_pity`) for generating the identical pools. Entry flows through the existing challenge handshake—`request_battle`/`respond_battle` via `NetSync` (mirroring how `ranked` is threaded)—with a new `draft` boolean flag indicating sealed-deck mode. Drafted decks are transient in-memory only; they are never written to `owned_cards` or persisted, so `SaveManager` state is untouched.

Both peers derive the same seeded card pool deterministically from a shared seed (either the host picks the seed before picks begin, or the host validates peer picks after-the-fact). The host then orchestrates the draft picking via a small RPC pair (similar to the loot-roll prompt pattern from bounty rewards or the pack-opening ceremony UI). Alternatively, both peers can fully deterministically draft offline from the shared seed with pick intents relayed to the host for conflict resolution. The first approach matches the social experience of watching a peer pick live on the map overlay; the second is lower-latency. The decision is made during the Plan phase. All code is guarded by `NetworkManager.is_active()` so single-player mode is untouched.

## Research Notes

**Existing patterns:**
- Challenge handshake: `NetSync.request_battle(opponent_idx, ante_coins, ranked)` / `respond_battle(accept)` in `scenes/multiplayer/NetSync.gd`; the `ranked` flag is already threaded through to `SceneManager.enter_pvp_battle(local_idx, opponent_deck, ante_coins, ranked)` and then to `BattleScene._init_game_state_coop(ranked=False)` and `GameState.from_dict()` which applies the `Ranked` rule set.
- Wire format: pure helpers in `game_logic/net/BattleNetProtocol.gd` (sealed, no scene dependencies); for draft, add a new pair: `encode_draft_seed(seed: int) -> PackedByteArray` and `decode_draft_seed(bytes: PackedByteArray) -> int`, or extend the existing `BattleNetProtocol` dictionary format with a `"draft_seed"` field if the seed is part of the battle state mirror.
- Seeded roll logic: `CardPackRegistry.roll_with_pity(tier: String, seed: int, pity_count: int) -> SkillData` is pure, deterministic, and reusable. Generating a sealed pool is rolling N cards with a seeded RNG stream (similar to how `GID-050` generates a pack).
- Draft UI: Endless Spire (`scenes/draft/DraftScene.gd`) implements the full 1-of-3 pick flow, showing 3 card options, handling pick submission, and managing a cumulative drafted deck. This can be reused directly or a variant can inherit from it.
- Duel entry: `SceneManager.enter_pvp_battle(local_idx, opponent_deck, ante_coins, ranked=False)` currently expects the opponent deck as `Array[String]` (card IDs). For draft duels, the opponent deck is built live during the draft, so the entry flow is: both peers draft → both submit their final decks → host validates or relays decks → host calls `enter_pvp_battle` with the drafts.
- Wagered duels: the `ante_coins` pattern in TID-362 deducts `SaveManager.add_coins(-ante)` on challenge accept via `_on_pvp_challenge_accepted_coop`. Draft duels inherit this: the same ante escrow applies.

**CLAUDE.md invariants:**
- Preload + UID: if new `.tres` draft-related resources are created (e.g. a dedicated DraftConfig), declare `const _DRAFT_CONFIG := preload("res://assets/...")` in the calling scene and generate a `.uid` sidecar.
- Headless import: after any `.gd` edit, run `godot --headless --editor --quit 2>&1 | grep -iE "Parse Error|Compile Error|Failed to load script"` — must be empty.
- Mobile parity: if the draft UI adds new interactive elements, ensure they have both keyboard (Enter to confirm pick) and touch (tap pick option) affordances.
- NetworkManager guard: wrap all draft duel logic in `if NetworkManager.is_active():` so single-player mode is untouched.

**Files to examine:**
- `scenes/multiplayer/NetSync.gd` — `request_battle` / `respond_battle` signature; extend with draft flag.
- `scenes/battle/BattleNetSync.gd` — mirrors the `GameState` from host; may need a `_pvp_draft_seed` field.
- `game_logic/net/BattleNetProtocol.gd` — pure wire helpers; add seed encode/decode if needed.
- `scenes/draft/DraftScene.gd` — full 1-of-3 pick implementation; reuse or fork.
- `autoloads/CardPackRegistry.gd` — `roll_with_pity` logic; may need a new public `generate_sealed_pool(tier: String, count: int, seed: int) -> Array[String]` helper.
- `autoloads/SceneManager.gd` — `enter_pvp_battle` signature; draft duels may route here with `draft=True` flag or a separate `enter_draft_duel` method.

## Plan

**Approach chosen: fully-deterministic shared-seed draft, no host orchestration
beyond the existing challenge handshake.** Rejected the "host relays live picks to
spectators" alternative — it needs a new stateful RPC pair (start/pick/ack) that
duplicates work `game_logic/net/DraftDuelGen.gd`'s determinism already makes
unnecessary, and the task's own note flags the shared-seed approach as the
simpler option. Because **both duelists see the identical sequence of 1-of-3
options** (not a shared/limited pool), there is no pick to arbitrate or relay —
only the two *finished* decks need to cross the wire, once, at the end.

1. **Wire helpers — `game_logic/net/DraftDuelGen.gd`** (new, pure, no scene deps,
   mirrors `BattleNetProtocol.gd`/`AvatarSync.gd`):
   - `NUM_ROUNDS = 8` (== `IsoConst.DECK_MIN`, so a finished draft deck is always
     battle-legal), `OPTIONS_PER_ROUND = 3`.
   - `generate_rounds(seed_val, pool_templates) -> Array` — deterministically builds
     `NUM_ROUNDS` rounds of 3 card ids each by reusing
     `game_logic/spire/SpireDraft.gd`'s tier-weighted `generate_picks` (GID-038),
     seeding one `RandomNumberGenerator` once and calling it 8 times with
     `floor = round_idx + 1` (so later rounds skew toward better cards, the same
     escalation feel Spire already has). Reuse, not reimplementation, of the pick
     algorithm.
   - `encode_seed(seed_val) -> Dictionary` / `decode_seed(payload) -> Dictionary` —
     versioned, garbage-tolerant wire pair for the seed handshake payload.
   - `make_drafted_instance(template_id, tier, round_idx, owner_token, tmpl) ->
     Dictionary` — builds a **transient** `CardInstanceUtil`-shaped instance dict
     (synthetic `"draft_<token>_<round>_<id>"` uid, base template stats, no rarity
     roll — identical base stats for both duelists is the fairness point of a
     sealed format). Never touches `SaveManager`/`owned_cards`.

2. **Challenge handshake — `scenes/world/NetSync.gd`** (append-only new section,
   3 new reliable RPCs, mirrors the existing `request_battle`/`respond_battle`
   pattern exactly so it doesn't collide with TID-386/387's likely edits to the
   same file):
   - `request_draft_duel(seed_val: int)` — challenger → target, carrying a
     `randi()`-generated seed.
   - `respond_draft_duel(accepted: bool, seed_val: int)` — target → challenger.
   - `submit_draft_duel_deck(deck: Array)` — **either** drafting peer → the other,
     sent once each side finishes picking. Symmetric (not "client → host"), so it
     works the same way `request_battle`/`respond_battle` already do not assume
     which side is the co-op host.

3. **WorldScene.gd**: a new "Draft Duel" HUD button (mobile+desktop parity via
   `Button.pressed`, same viewport-relative sizing as `_ensure_challenge_button`)
   next to the existing Challenge button, shown at the same proximity trigger
   (`_challenge_target_peer`). Accept/decline panel mirrors
   `_show_challenge_accept_panel`. On accept, both peers instantiate the new
   `scenes/multiplayer/DraftDuelPicker.gd` overlay locally with the shared seed —
   no network traffic per pick. When a peer finishes its 8 picks, it sends its
   assembled deck to the other peer via `submit_draft_duel_deck`. Once a peer has
   **both** its own finished deck and the deck received from its opponent, it
   calls `SceneManager.enter_pvp_battle(...)` itself (mirrors how both sides of a
   normal challenge each independently call `_enter_pvp` once they have the data
   they need — no extra "go" signal, the client's existing `request_sync` retry
   loop absorbs any entry-order skew). Never ranked, never wagered — `_pvp_ranked`
   forced `false`, `ante_coins = 0`.

4. **BattleScene.gd / SceneManager.gd — minimal additive param, mirrors how
   `ranked`/`ante_coins`/`opponent_token` were threaded through before**:
   - `SceneManager.enter_pvp_battle` gains a trailing `local_deck_override: Array =
     []` param, forwarded to a new `BattleScene.pvp_local_deck_override` field.
   - `BattleScene._build_pvp_decks`'s listen-server-host branch uses
     `pvp_local_deck_override` for `players[0]` instead of
     `SceneManager.save_manager.get_deck_instances()` when non-empty — this is the
     **only** way a draft duel avoids reading (or writing) the host's persisted
     collection. The dedicated-referee branch already builds both decks from
     RPC-supplied arrays, so it needs no change.

5. **Tests — `tests/unit/test_draft_duel_gen.gd`** (new, pure, fake pool dicts like
   `test_spire_draft.gd`): round count/shape, determinism (same seed ⇒ same
   rounds), different seeds ⇒ different rounds (eventually), `encode_seed`/
   `decode_seed` round-trip + garbage tolerance, `make_drafted_instance` shape
   (uid format, fields, no `is_unique`/persistence markers).

6. **Docs**: `docs/agent/multiplayer-coop.md` gets a new "Draft Duels" subsection
   under the PvP Card Battles section, following the existing prose style (model,
   wire format, flow, integration table entry if useful).

**Out of scope** (documented, not implemented): drafting decks larger than 8
cards, a "watch the picks live" spectator view of drafting itself (spectating
the resulting *battle* already works for free via the existing GID-101 flow once
`_enter_pvp`-equivalent bookkeeping runs), client-vs-client draft duels when
neither peer is the co-op host (pre-existing limitation of `_enter_pvp` itself —
`local_idx` is derived from `NetworkManager.is_host()`, so a duel between two
non-host clients was never supported before this task either).

## Changes Made

**New files:**
- `game_logic/net/DraftDuelGen.gd` (+ `.uid`) — pure sealed-pool round generation
  (`generate_rounds`: one RNG seeded once, 8 calls into `SpireDraft.generate_picks`
  with escalating floor), seed wire pair (`encode_seed`/`decode_seed`, versioned +
  garbage-tolerant), and `make_drafted_instance` (transient `CardInstanceUtil`-shaped
  dict, `draft_<token>_<round>_<id>` uid namespace, base template stats, no rarity roll).
- `scenes/ui/DraftDuelPickScene.gd` (+ `.uid`) — the pick overlay, built fully in
  code (no `.tscn`), modeled on `SpireDraftScene`: 1-of-3 rounds with tier badges,
  portrait stacking, drafted-so-far strip, post-draft "Waiting for opponent…" state.
  Emits `draft_finished(deck)`. All picks are `Button`s (mobile + desktop parity).
- `tests/unit/test_draft_duel_gen.gd` (+ `.uid`) — 17 pure unit tests: round shape,
  same-seed determinism, seed divergence, tier escalation, encode/decode round-trip
  + garbage tolerance, transient-instance shape/uid namespacing/rarity clamp.

**Modified (shared) files — kept small and localized:**
- `scenes/world/NetSync.gd` — appended one new section (3 reliable RPCs):
  `request_draft_duel(payload)`, `respond_draft_duel(accepted, payload)`,
  `submit_draft_duel_deck(deck)`. No existing RPC touched.
- `scenes/world/WorldScene.gd` — one const/var block (preloads + draft state), one
  appended function block at end of file (`_ensure_draft_duel_button`,
  `_update_draft_duel_proximity`, `_request_draft_duel`, `_on_draft_duel_requested/
  _responded/_deck_submitted`, accept panel, `_start_draft`, `_on_local_draft_finished`,
  `_maybe_enter_draft_duel`, `_abort_draft_duel[_for_peer]`), and 4 one-line hooks:
  `_ensure_draft_duel_button()` in `_setup_coop`, `_update_draft_duel_proximity()` in
  `_process`, abort calls in `_on_coop_peer_disconnected` / `_on_coop_session_ended`.
- `autoloads/SceneManager.gd` — `enter_pvp_battle` gained a trailing
  `local_deck_override: Array = []` parameter (mirrors how `ranked`/`ante_coins`
  were threaded), forwarded to `BattleScene.pvp_local_deck_override`.
- `scenes/battle/BattleScene.gd` — new `pvp_local_deck_override` field; the
  listen-server host branch of `_build_pvp_decks` uses it for `players[0]` when
  non-empty instead of `SaveManager.get_deck_instances()`. Client/referee paths
  unchanged.

**Design points:**
- Deterministic shared-seed model chosen (see Plan): both peers see identical
  options each round, so no pick relay/arbitration exists — only the two finished
  transient decks cross the wire, once each, then whichever peer holds both decks
  enters `SceneManager.enter_pvp_battle` (host = idx 0, mirrors `_enter_pvp`
  including spectator broadcast + opponent reconnect token).
- Draft duels are always casual (never ranked — `_pvp_ranked` forced false; never
  wagered — ante 0) and have **no DECK_MIN gate** (no collection needed at all).
- Drafted cards are never written to `owned_cards`/`SaveManager`/`SessionState`;
  the `draft_` uid namespace makes accidental persistence collision-proof.
- Single-player untouched: every entry point hangs off `_setup_coop`'s
  `NetworkManager.is_active()`-guarded HUD (`_coop_active` gates the `_process`
  hook); dedicated servers hide the button (`_session_dedicated`).
- Note: the planned `NetworkManager.is_active()` guard is enforced structurally
  (all triggers created only inside `_setup_coop`) rather than by re-checking in
  every handler, matching how the existing challenge handshake does it.
- Deviation from Research Notes: pool generation reuses `SpireDraft.generate_picks`
  (GID-038) rather than a `CardPackRegistry.roll_with_pity` wrapper — the notes
  referenced a `CardPackRegistry` autoload that does not exist in this codebase
  (packs live in `game_logic/PackDefs.gd` and are not seed-parameterized; Spire's
  draft logic is already seeded, pure, and 1-of-3 shaped).

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — new "Draft Duels — sealed-deck PvP
  (GID-104 / TID-385)" section (model, wire table, flow, invariants/scope) after
  the Ghost Duels section, plus a `test_draft_duel_gen.gd` row in the Tests table.
- This task file: Plan, Changes Made, Documentation Updates.
- Deliberately did NOT edit the CLAUDE.md docs-index row for multiplayer-coop.md:
  sibling tasks TID-386/387 would race on the same line; the orchestrator can
  reconcile the one-line feature list after merge.
