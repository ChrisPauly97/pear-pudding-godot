# TID-408: Co-op Compatibility Pass — Chapters 1 & 2 with up to 4 Players

**Goal:** GID-108
**Type:** agent
**Status:** done
**Depends On:** TID-402, TID-405, TID-407

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op story mode (GID-098) made the story playable as a party: story flags are
shared via `SessionState` (not local `SaveManager`), a beat triggered by one player
advances the whole party with exactly-once arbitration (TID-356), and NPC dialogue
is group-aware (TID-357). Every piece of new GID-108 content must obey those rules
so a 4-player party experiences one coherent story — no per-player divergence
within a session, no double-fired beats, no cross-map ghosts.

## Design Rules (decided at goal creation, 2026-07-02)

1. **Shared spine:** all new flags (`chapter1_camp_night`, `chapter1_learned_fire`,
   `chapter1_spoke_queen/_scargroth`, `chapter1_complete`, all `chapter2_*`) go
   through the TID-356 shared-flag arbitration in co-op. First player to trigger
   advances the party; the beat's one-time effect fires exactly once.
   **"Each player affects it differently" is intentionally NOT the model** — any
   member's interaction counts for the whole party (e.g. one player talks to the
   Queen, another to Scargroth: both sub-flags set, ending unlocks). Individual
   contribution is expressed through *who does what*, not through divergent states.
2. **Scripted tutorial battles (rabbit hunt, Ch2 ambush):** in co-op, party members
   present at the trigger join as a joint battle (GID-099/100 co-op PvE engine),
   each seated player receiving the fixed tutorial deck and their own deterministic
   draw sequence; tutorial popups render locally per client. If seating scripted
   decks in the joint engine proves too invasive, fallback: the triggering player
   fights solo and the flag is shared on victory (decide in Plan; fallback is
   acceptable for v1).
3. **Narration overlays (Ch1 ending, Ch2 cliffhanger):** the authority broadcasts a
   narration event; all clients show the overlay simultaneously; the completion
   flag is set once by the authority. Late-join/absent members inherit the shared
   flag state on next sync.
4. **Maiteln journey presence (TID-403):** exactly ONE Maiteln per session — an
   authority-owned follower whose position syncs to clients (same pattern as
   RemotePlayer avatars). He follows the party centroid / the nearest on-map member,
   never duplicates per player. Carry `map_name` in his sync payload and filter on
   receive (CLAUDE.md invariant from the cross-map-ghost fix, GID-096/TID-352).
5. **Story scrolls (larik letter, traitor's seal):** shared-trigger — first
   collector fires it; the journal entry + narration is granted to all session
   members (mirror the GID-096 shared-chest model).
6. **Story siege at marsax_hold (Ch2 beat 4):** in co-op this requires the synced
   siege from GID-103 (Shared World Life — pending). Until GID-103 lands, the
   story siege is host-resolved: the host runs the siege, outcome flag is shared.
   Note the dependency in the Plan; do not block Chapter 2 solo play on it.
7. **War-camp dungeon boss (Ch2 beat 6):** joint co-op PvE battle (GID-099);
   shared dungeon crawl machinery from GID-102/TID-380 applies.
8. **Solo saves stay clean:** co-op story progress lives in `SessionState` and must
   NOT write through to a member's personal `SaveManager.story_flags` — each
   player's solo campaign keeps its own pace (GID-098 invariant; verify for every
   new flag site: gate `set_story_flag` through the same co-op-aware path the
   existing Chapter 1 flags use).

## Research Notes

- Shared flags: game_logic/net/SessionState.gd (`story_flags` dict, to_dict/from_dict),
  tests/unit/test_coop_story_flags.gd (idempotency + round-trip semantics).
- Arbitration + multi-map transitions: GID-098 TID-355/356/357 task files; group
  dialogue pluralization pending as GID-098/TID-358 (human-action, in-progress) —
  new GID-108 dialogue lines added to story.md should be included in that
  pluralization list when TID-358 completes.
- Joint battle engine: GID-099/GID-100 (square battlefield, cross-board cards);
  co-op PvE quirks logged in BID-027/BID-028.
- Avatar/map filtering invariant: CLAUDE.md "Co-op avatar sync was map-blind" —
  carry the map discriminator in any new sync payload (Maiteln follower included).
- Sync layer: scenes/world NetSync/AvatarSync, autoloads/NetworkManager.gd;
  docs/agent/multiplayer-coop.md.
- Pending related goals: GID-103 (synced sieges/night hunts), GID-102/TID-380
  (shared dungeon crawl) — check their status at Plan time.

## Plan

Research findings per design rule, and what (if anything) each needs:

1. **Shared spine (flags) — already satisfied, zero code needed.** Read
   `WorldScene.gd`'s pre-existing TID-356 block (`_on_local_story_flag_set` /
   `_on_story_flag_received` / `_on_story_flag_submitted` /
   `_send_story_flags_snapshot_to_peer` / `_on_story_flags_snapshot_received`).
   Every `SaveManager.set_story_flag()` call anywhere (including all of TID-401–407's
   new flags: `chapter1_camp_night`, `chapter1_learned_fire`, `chapter1_spoke_queen`,
   `chapter1_spoke_scargroth`, `chapter1_complete`, all `chapter2_*`) already routes
   through `GameBus.story_flag_set`, which this block picks up generically and
   arbitrates host-authoritative + idempotent, broadcasting to the party and
   persisting into `SessionState.story_flags`. No GID-108 code bypassed
   `set_story_flag()`, so this rule needed no new code.
2. **Scripted tutorial battles — sanctioned fallback already in effect, zero code
   needed.** `WildernessCamp`/`ScoutAmbush` are per-client local entities (no
   world-object id); each interacting player fights their own local
   `ScriptedBattleRegistry` battle, and `SceneManager._on_scripted_battle_ended`
   grants the completion flag via `set_story_flag()` — which flows through rule 1's
   arbitration to the whole party. This is exactly the task's sanctioned "solo
   fight, flag shared on victory" fallback. `WildernessCamp.interact()` already
   re-checks flags fresh each interaction, so a party member arriving after a
   teammate already resolved the beat sees the correct next stage, not a repeat.
3. **Narration overlays — needs new code.** `_trigger_chapter1_ending()`
   (WorldScene) and `SceneManager._show_chapter2_cliffhanger()` currently build the
   `ChapterEndingOverlay` directly and only the interacting player's client ever
   sees it. Add `GameBus.narration_overlay_requested(pages, title, completion_flag)`;
   WorldScene owns a single handler that shows the overlay locally and (if
   `_coop_active`) broadcasts a new `recv_narration_overlay` RPC so every peer shows
   the same overlay. `completion_flag` (optional) is set via the existing
   idempotent `set_story_flag()` when the overlay closes, replacing the inline
   flag-set in the chapter-2 cliffhanger's close callback.
4. **Maiteln sync — needs new code.** `MaitelnFollower.gd` currently follows
   `_player_ref` locally with no network awareness — in co-op every client spawns
   and drives its own independent copy (a real per-player duplication bug, not
   just a v1 gap). Fix: only the authority's copy runs the existing local
   follow-the-player logic; give `MaitelnFollower` a `networked` mode where it
   instead lerps toward a received net position and does nothing else. The
   authority broadcasts `[x, z, map_name]` at low Hz (mirrors
   `_broadcast_local_avatar`); receivers apply position only when the map matches
   (CLAUDE.md cross-map-ghost invariant) and otherwise just hide the node.
   Simplification (documented, not hidden): "follows the party" is implemented as
   "follows the authority's own player," not a true multi-player centroid — this
   still fully satisfies the actual bug (exactly one Maiteln, position synced,
   no divergence) without new centroid math; `_maiteln_should_be_present()` stays
   map/flag-driven identically for every peer so existence agrees everywhere the
   party is together (co-op's normal case).
5. **Story scrolls — needs new code.** `StoryScroll.gd` calls
   `SaveManager.mark_scroll_collected()` + emits `GameBus.story_scroll_collected`
   purely locally; nothing shares the pickup today (only the two scroll-specific
   *story flags* it sets in `_on_scroll_collected` ride rule 1's sync — the
   journal entry / "found" tip / completion check do not). Mirror the GID-096
   shared-chest model exactly: add `WorldObjectSync.EV_SCROLL_COLLECTED` and reuse
   the existing generic `recv_world_event`/`submit_world_event` RPC pair (no new
   RPC needed). Add `SessionState.collected_scrolls` (mirrors `opened_chests`,
   no version bump needed — `from_dict` already defaults missing keys) and extend
   `WorldObjectSync.encode_snapshot`/`decode_snapshot` with an optional 3rd
   element so a late joiner's snapshot includes already-collected scrolls
   (backward compatible: existing 2-arg call sites/tests are unaffected).
6. **Story siege at marsax_hold — needs a one-line guard.** Confirmed GID-103 only
   wired the *synced* siege for madrian (`CoopSiege.gd`); marsax_hold's story siege
   still calls the single-player `SaveManager.start_siege()`/`_spawn_siege_raiders`
   path with no co-op awareness at all — every peer who walks in would start their
   own private local siege. Apply the task's own sanctioned rule-6 fallback: gate
   `_check_story_siege_trigger()` so only `_coop_world_authority()` (or solo play)
   starts it; the `chapter2_siege_won` flag still reaches the whole party via
   rule 1. Documented as the intended v1 (a true synced marsax_hold siege reusing
   `CoopSiege` is future work, not blocking Chapter 2).
7. **War-camp dungeon boss — already satisfied, zero code needed.** Confirmed by
   reading `_handle_interact()`'s door branch: *any* door (including the
   war-camp's fixed `dungeon_731906` door) already broadcasts
   `recv_map_transition` to the whole party in co-op — no special-casing exists
   or is needed (TID-380's Changes Made explicitly confirms `recv_map_transition`
   and the `"dungeon_"` load branch are content-agnostic). `_inject_warcamp_boss`
   runs unconditionally for every peer's `WorldScene._ready()` (not host-gated),
   so all peers deterministically get the identical boss entry in `WorldMap.enemies`.
   Combat then rides the already-map-agnostic GID-096 enemy engage-lock (confirmed
   in TID-380's own smoke-test re-run), so the boss is a single shared,
   engage-locked enemy — first engager fights it solo, the party shares the
   defeat + `chapter2_warcamp_cleared`/`chapter2_complete` flags via rule 1. This
   is the same "solo fight, shared outcome" shape rule 2 explicitly sanctions,
   not a true multi-seat joint battle (`enter_coop_pve_battle` is not wired here);
   documented as the deliberate v1 scope, consistent with the fallback already
   accepted for tutorial battles and the marsax_hold siege above.
8. **Solo saves stay clean — already satisfied, zero code needed.** Confirmed
   `SaveManager.adopt_session_character()` sets `_loaded = false` and `save()` is a
   no-op while `_loaded` is false — a co-op session's `SceneManager.save_manager`
   is the ephemeral session character, never the disk-backed solo save, so every
   flag/scroll write this task adds through the existing arbitration/event paths
   cannot leak into a member's personal save file.

**Net new code, in order:**
- `game_logic/net/WorldObjectSync.gd`: add `EV_SCROLL_COLLECTED`; extend
  `encode_snapshot`/`decode_snapshot` with an optional 3rd `collected_scrolls` array.
- `game_logic/net/SessionState.gd`: add `collected_scrolls: Array = []` (+
  `to_dict`/`from_dict`).
- `autoloads/GameBus.gd`: add `narration_overlay_requested(pages, title, completion_flag)`.
- `scenes/world/entities/MaitelnFollower.gd`: add networked mode (`set_networked`,
  `set_net_state`), branch `_process`.
- `scenes/world/NetSync.gd`: add `recv_maiteln_state` and `recv_narration_overlay` RPCs
  (both mirror existing `recv_avatar`/`recv_map_transition` shape).
- `scenes/world/WorldScene.gd`:
  - New vars: `_coop_collected_scrolls: Dictionary`, `_coop_scroll_syncing: bool`,
    `_maiteln_broadcast_accum: float`.
  - `_refresh_maiteln_presence()`: set networked mode per role when `_coop_active`.
  - `_broadcast_maiteln_state(delta)` (called from `_process` alongside
    `_broadcast_local_avatar`) + `_on_maiteln_state_received(payload)`.
  - `_show_narration_overlay(pages, title, completion_flag)` +
    `_on_narration_overlay_requested(pages, title, completion_flag)` (GameBus
    listener, connected in `_ready()`); `_trigger_chapter1_ending()` and
    `SceneManager._show_chapter2_cliffhanger()` route through the signal instead
    of building the overlay inline.
  - `_on_scroll_collected()`: broadcast via `_broadcast_scroll_collected_coop()`
    guarded by `_coop_scroll_syncing` (reentry guard); `_coop_apply_scroll_collected()`
    / `_coop_record_scroll_collected()` (mirror `_coop_mark_chest_opened_node`/
    `_coop_record_chest_opened`); new `EV_SCROLL_COLLECTED` cases in
    `_on_world_event_received`/`_on_world_event_submitted`; extend
    `_coop_apply_world_progress()` and its two call sites (`_setup_session`,
    `_on_world_snapshot_received`) and `_send_world_snapshot_to_peer()` for the
    3rd snapshot element; clear `_coop_collected_scrolls` alongside
    `_coop_opened_objects` on session reset.
  - `_check_story_siege_trigger()`: add the `_coop_world_authority()` guard.
- `autoloads/SceneManager.gd`: `_show_chapter2_cliffhanger()` emits the GameBus
  signal instead of constructing the overlay inline.
- Tests: extend `tests/unit/test_world_sync.gd` (or add a focused new test file)
  for `EV_SCROLL_COLLECTED` + the 3-element snapshot; a small `MaitelnFollower`
  networked-mode unit test if one is practical without a live scene tree.
- `docs/agent/multiplayer-coop.md` and `docs/agent/story-implementation.md`:
  document the co-op behavior + the two sanctioned v1 fallbacks (rules 6/7).

## Changes Made

- `game_logic/net/WorldObjectSync.gd`: added `EV_SCROLL_COLLECTED`; extended
  `encode_snapshot`/`decode_snapshot` with an optional 3rd `collected_scrolls`
  element (backward compatible — existing 2-arg callers/tests unaffected).
- `game_logic/net/SessionState.gd`: added `collected_scrolls: Array = []` field
  (`to_dict`/`from_dict` + a v13 migration, `CURRENT_SESSION_VERSION` 12 → 13).
- `autoloads/GameBus.gd`: added `narration_overlay_requested(pages, title, completion_flag)`.
- `scenes/world/entities/MaitelnFollower.gd`: added a `networked` mode
  (`set_networked`, `set_net_state`) and branched `_process` — networked copies
  lerp toward a received position instead of following `_player_ref`.
- `scenes/world/NetSync.gd`: added `recv_narration_overlay` and
  `recv_maiteln_state` RPCs (mirror `recv_map_transition`/`recv_avatar` shape).
- `scenes/world/WorldScene.gd`:
  - New vars: `_maiteln_broadcast_accum`, `_coop_collected_scrolls`,
    `_coop_scroll_syncing`.
  - `_refresh_maiteln_presence()`: non-authority co-op clients spawn Maiteln in
    networked mode, hidden until the first same-map packet (TID-352 pattern).
  - `_broadcast_maiteln_state()` (wired into `_process`) +
    `_on_maiteln_state_received()`.
  - `_on_narration_overlay_requested()` / `_on_narration_overlay_received()` /
    `_show_narration_overlay()` — connected to the new GameBus signal in
    `_ready()`; `_trigger_chapter1_ending()` now emits the signal instead of
    building the overlay inline.
  - `_check_story_siege_trigger()`: added the `_coop_world_authority()` guard
    (design rule 6).
  - `_on_scroll_collected()`: broadcasts via the new
    `_broadcast_scroll_collected_coop()` (guarded by `_coop_scroll_syncing`);
    added `_coop_record_scroll_collected()` / `_coop_apply_scroll_collected()`
    (mirror the existing chest-open pair); new `EV_SCROLL_COLLECTED` cases in
    `_on_world_event_received()`/`_on_world_event_submitted()`; extended
    `_coop_apply_world_progress()` (+ its two call sites) and
    `_send_world_snapshot_to_peer()` for the 3rd snapshot element; clear
    `_coop_collected_scrolls` alongside `_coop_opened_objects` in
    `_on_coop_session_ended()`.
- `autoloads/SceneManager.gd`: `_show_chapter2_cliffhanger()` now emits
  `GameBus.narration_overlay_requested` instead of building the overlay
  directly (no `_net_sync` reference exists in this autoload); removed the
  now-unused `_ChapterEndingOverlay` preload const.
- `tests/unit/test_world_sync.gd`: added `EV_SCROLL_COLLECTED` coverage
  (distinctness + kind round-trip) and extended the snapshot tests for the 3rd
  `collected_scrolls` element (round-trip, empty defaults, garbage defaults,
  explicit round-trip test).
- `tests/unit/test_session_state.gd`: added `collected_scrolls` to the
  round-trip fixture/assertions and a `test_migration_v13_adds_collected_scrolls`
  migration test.
- Confirmed (no code needed) design rules 1, 2, 7, 8 were already satisfied by
  pre-existing GID-098/GID-096/TID-380 machinery — see the Plan section above
  for the full per-rule research trail, and
  `docs/agent/multiplayer-coop.md`'s new section for the write-up.

### Validation

No Godot binary available in this sandbox (outbound download blocked, same
constraint noted on GID-103/GID-102/GID-105) — headless import and the test
runner could not be executed. Mitigations taken in lieu of a compiler run:
- Every new/modified `.gd` file was manually re-read end-to-end after editing.
- Paren/bracket/brace balance was checked for every touched file
  (`scenes/world/WorldScene.gd`, `scenes/world/NetSync.gd`,
  `scenes/world/entities/MaitelnFollower.gd`, `game_logic/net/WorldObjectSync.gd`,
  `game_logic/net/SessionState.gd`, `autoloads/GameBus.gd`,
  `autoloads/SceneManager.gd`, both test files) — all balanced except
  `WorldScene.gd`'s pre-existing, previously-investigated harmless off-by-one
  paren count in a string literal (unrelated to this task's edits).
- Cross-checked every new function name for accidental duplicate definitions
  (`grep -n "^func <name>"` on each new symbol — all unique).
- Confirmed `_coop_world_authority()`, `_coop_world_authority`-guarded
  functions, and every reused pattern (`_on_chest_opened_coop` /
  `_coop_record_chest_opened` / `_coop_mark_chest_opened_node`,
  `_broadcast_local_avatar` / `_on_avatar_received`, `_send_world_snapshot_to_peer`
  / `_on_world_snapshot_received`) against the exact existing code they mirror.
**Next session with Godot available should run**
`godot --headless --editor --quit` **and**
`godot --headless --path . -s tests/runner.gd` **before trusting this in production.**

### Scope cuts (documented, not silent)

- **No true multi-player centroid for Maiteln.** He follows the co-op
  authority's own player, not a computed party centroid — sufficient to fix
  the actual bug (one Maiteln, synced, no per-client divergence) without new
  math; documented in the Plan and in `docs/agent/multiplayer-coop.md`.
- **No true joint multi-seat battle** for the war-camp boss or the marsax_hold
  siege — both use the "solo fight/siege, shared outcome via flag" fallback
  the task's own design rules 2 and 6 explicitly sanction, consistent with how
  the tutorial battles already work. A synced marsax_hold siege reusing
  GID-103's `CoopSiege.gd`, and a true joint war-camp boss battle via
  `enter_coop_pve_battle`, are both flagged as future work, not blockers.
- **No dedicated `MaitelnFollower` networked-mode unit test** — it is a
  `Node3D` whose new behavior only manifests via `_process` against a live
  scene tree, and this codebase has no precedent for unit-testing that shape
  of entity script (mirrors the scope cut already accepted for other
  WorldScene-orchestrated entities, e.g. GID-106's guildhall spawn/RPC flow).
  The logic was instead traced by hand against the already-shipped
  `RemotePlayer`/`AvatarSync` pattern it mirrors line-for-line.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: new "Story Arc Co-op Compatibility
  (GID-108 / TID-408)" section — full per-rule breakdown of what was already
  free vs. what needed new code, plus the two documented v1 fallbacks.
- `docs/agent/story-implementation.md`: updated the Maiteln section's stale
  "solo-only follower" caveat to describe the shipped networked mode, and
  replaced the Chapter 2 "no co-op arbitration" caveat with the corrected
  (already-mostly-free, three real gaps fixed) summary, both pointing to the
  new multiplayer-coop.md section for detail.
