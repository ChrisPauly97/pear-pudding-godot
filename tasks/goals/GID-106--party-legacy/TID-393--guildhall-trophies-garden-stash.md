# TID-393: Guildhall Trophies, Garden & Stash Chest

**Goal:** GID-106
**Type:** agent
**Status:** done (headless import + test run unverified in-sandbox — see Validation note)
**Depends On:** TID-392

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The guildhall (TID-392) is now a place the party can gather, but it is empty — just a room. This task furnishes it so it visibly reflects the party's shared history and becomes a functional co-op hub, not a blank shell. Three systems are woven in: **trophies** auto-populated from the session's recorded joint boss clears (reusing the GID-046 trophy pedestal pattern), a **shared garden** that grows on session time (reusing the GID-056 growth model), and a **physical stash chest** entity that opens the existing co-op `PartyStashOverlay` (TID-376) on interact. Together they tell a story: "We defeated these bosses together" (trophies), "We've spent N days as a guild" (garden growth), and "We pool our loot here" (stash). The trophies and garden are entirely display/cosmetic (no new game loops), while the stash chest provides a convenient in-world anchor for the party's shared inventory.

## Research Notes

**Trophies — auto-populated from leaderboard history.** The guildhall spawns trophy pedestals like the player home (GID-046 pattern), but instead of reading `SaveManager` fields, it reads session records: for each entry in `SessionState.leaderboards["coop_clears"]` (the joint boss-clear leaderboard populated by TID-391), spawn a trophy pedestal at a designated position showing the boss/floor info. The pedestal display name is the leaderboard entry's metadata (e.g. "Floor 9 Clear — 3 players" or "Ancient Colossus Defeated"). Iterate up to 3 most-recent clears (or all if fewer than 3) with positions (e.g. left/center/right pedestals at (42,50), (50,50), (58,50)). Unlike GID-046 which predetermines trophy predicates, these are **dynamic**: the UI reflects what the party actually achieved. Use the same procedural BoxMesh pedestals (gold color for clarity) and auto-hide a pedestal if no entry exists at that slot.

**Garden — session-scoped, days_elapsed-driven.** Reuse the GID-056 garden plot system but owned by the **session**, not the single-player character. Add `garden_plots: Array[Dictionary]` to `SessionState.guildhall_state` (expand the v7 migration from TID-392). Each plot has `{seed_id, planted_day}` (same shape as SaveManager's `garden_plots`). Three plots spawn at guildhall positions (e.g. (52,54), (55,54), (58,54) — same tile-relative layout as the home for familiarity). `GardenPlot` gains an optional `session_mode: bool` flag; when true, it reads/writes from `SessionStore` (authority-owned) instead of `SaveManager`. On interact, WorldScene shows the same plot panel (plant, growing, harvest) as single-player, but all changes are submitted to the authority via new `NetSync` RPCs: `submit_session_plant(plot_idx, seed_id)` / `submit_session_harvest(plot_idx)` (client → authority). Authority calls `StashTransfer.deposit_seeds(...)` / `withdraw_plants(...)` to move seeds/plants between the acting member's character record and the session stash (decide in Plan: should harvested plants go to the member's `owned_cards` or to the session stash? Guidance: session stash is simpler and thematic — shared garden feeds the shared stash). Authority broadcasts `recv_session_garden_update(plot_states)` so all peers see consistent plots. Garden growth is deterministic from `SessionState.days_elapsed` (authority-owned), so all peers compute identical growth stages locally without needing a per-plot-instance ticker.

**Stash chest entity — interact to open PartyStashOverlay.** A new entity type `entity_type = "stash_chest"` is placed in the guildhall (e.g. tile (50,48)). On interact (key E or tap the on-screen prompt), WorldScene calls `_show_party_stash_overlay()` — the same overlay from TID-376, already fully implemented. The overlay is a convenience: the party stash is already accessible via the always-visible HUD button (TID-376), but having a physical chest in the guild hall reinforces that it is a shared resource. The chest has a `Label3D` label ("Guild Stash" or "Party Treasury") and a subtle idle animation (e.g. slight bob, or a faint glow). No new RPC needed — the chest just routes to the existing overlay.

**Interact prompt — key + tap parity.** All three entity types (trophy pedestals, garden plots, stash chest) follow the existing interact-detection flow: WorldScene's `_check_interactions()` finds the nearest entity within `IsoConst.INTERACT_RANGE`; `_handle_interact()` dispatches by entity type. Pedestals are NPCs (`npc_type = "trophy_pedestal"`, same as GID-046) and show a fixed info dialogue on interact (read-only). Garden plots have their own `_show_garden_plot_panel` branch (existing code, reused here). The stash chest is a new `entity_id = "stash_chest"` branch that calls `_show_party_stash_overlay()`. Mobile users tap an on-screen prompt (existing pattern), desktop users press E (existing pattern). No new keybindings or prompt infrastructure needed.

**Authority-only garden writes.** Plot changes (plant/harvest) are submitted by any peer but executed by the authority. Similar to party bounties (TID-369) and party stash (TID-376), the authority resolves the submitter's token, applies the mutation to the session state, writes via `SessionStore.mark_dirty()`, and broadcasts the updated plot states. A late-joining peer receives the current `guildhall_state.garden_plots` via `_send_character_to_peer` snapshot (same as stash is sent in TID-376). Rejoining members see their guild's garden in its current growth state.

**Leaderboard vs. garden value signal.** The session's pve-leaderboard ("coop_clears") is recorded by TID-391 and feeds trophy populations. The garden is independent — it tracks session time (days elapsed), not wins. Together they show "We've cleared tough encounters (trophies) and we've built this space together (garden visible growth)."

**Project invariants.** All guildhall-interior code guarded by `NetworkManager.is_active()`. New entity interactions follow existing patterns (no new interact dispatch logic). SessionState migration for garden plots (expand TID-392's v7 bump if needed, or call it v8 if TID-392 also adds fields). New GameBus signals for garden events (optional, if re-using existing `GameBus.plant_harvested` from GID-056 causes confusion — decide in Plan). Headless import must pass. No new `.tres` resources (entity data is in-map presets). All interact prompts render viewport-relative and work on touch + keyboard.

## Plan

**Verified against actual code (several Research Notes assumptions don't hold):**

- **Trophies need no new sync.** `WorldScene._pve_leaderboards: Dictionary`
  (`{"spire": [], "coop_clears": [], "night_hunts": [], "coop_spire": []}`) is
  already a continuously-kept-current cache on **every** peer — broadcast on
  every `record_pve_score` write and sent at late-join
  (`_broadcast_pve_leaderboards`). Trophies just read
  `_pve_leaderboards.get("coop_clears", [])` directly; no new RPC needed.
- **`coop_clears` entries are `{token, name, value, day}` (party size at win
  time, not a boss/floor description) and at most one row per token** (`record_pve_score`
  is insert-or-update-per-token, re-sorted desc by value). There is no
  "boss/floor info" to display and no real notion of "3 most recent clears" —
  the board is a *best-score* leaderboard, not a clear history log. Adapting:
  show up to 3 pedestals from `get_pve_leaderboard("coop_clears", 3)`
  (already best-first), labelled from what actually exists
  (`"<name>'s Clear — Party of <value>"`). A slot with no entry is skipped
  entirely (not shown as an unearned "???" placeholder — that GID-046 pattern
  is for a fixed predicate-driven trophy *list*; this is a dynamic top-N).
- **`SessionStore` is authority-only — clients cannot read it at all**
  (`SessionStore.is_open()` is always false on a client; confirmed from its
  own doc comment: "Clients never call open()/_write() — only the authority
  persists"). So `GardenPlot` (which the Research Notes proposed should read
  session state directly) **cannot** pull garden data from `SessionStore` the
  way it pulls from `SaveManager` today — this needs the same
  authority-computes-broadcasts-cache model already used for
  `_pve_leaderboards`/`_leaderboard_rows`/`_remote_identities`, not a direct
  read.
- **`_coop_current_days_elapsed()`** (`WorldScene.gd:1588-1591`) already
  exists and returns the correct value on every peer (host reads
  `SessionStore` directly; client reads `_coop_env_days_elapsed`, kept
  current by the existing GID-103 world-clock sync) — reused as-is for
  growth-stage math, no new day-sync plumbing needed.
- **Seeds/plants are plain `Dictionary[id, int]` counters** (`SaveManager.seeds`/
  `SaveManager.plants`, `add_seeds`/`remove_seeds`/`add_plants`/`remove_plants`
  at `SaveManager.gd:1929-1949`), **not card instances** — `StashTransfer.gd`
  (which only handles card-instance/coin transfer with the party stash) is
  the wrong tool for this; the Research Notes' "`StashTransfer.deposit_seeds`/
  `withdraw_plants`" call sites don't exist and aren't the right shape to add.

**Decisions:**

1. **No session-scoped seed *economy*.** Modeling "a member deposits personal
   seeds into a session pool to fund planting" would require adding seed
   fields to `SessionState.members[token]` character records (they don't
   carry any today) and a deposit UI that doesn't exist — real net-new scope
   for a feature explicitly framed as cosmetic/no-new-game-loops. Instead:
   **planting in the guildhall garden is free** — any member picks any
   `GardenDefs.SEEDS` id for an empty plot, no seed consumed. This is a
   deliberate, documented co-op-only simplification (solo's garden still
   consumes owned seeds unchanged).
2. **Harvested yield goes into a new, small, dedicated
   `guildhall_state.plants: Dictionary` pool** (`plant_id -> count`) — **not**
   the existing `SessionState.stash` (`{cards, coins}`). Research Notes
   suggested reusing the stash ("shared garden feeds the shared stash"), but
   the stash's shape has no concept of arbitrary item counts, and extending
   it would touch already-shipped, more deeply-integrated stash/auction code
   for a cosmetic feature. A dedicated pool is simpler and lower-risk;
   documented as a deliberate deviation from the Research Notes' suggestion.
3. **Garden sync mirrors the PvE-leaderboard pattern exactly**: a WorldScene
   cache (`_guildhall_garden_cache: Dictionary = {"plots": Array, "plants": Dictionary}`),
   kept current via a request/response + broadcast RPC trio
   (`submit_guildhall_garden_request` / `recv_guildhall_garden_update`,
   same shape as `submit_pve_leaderboard_request`/`recv_pve_leaderboards`),
   plus two mutation RPCs (`submit_session_plant(plot_idx, seed_id)`,
   `submit_session_harvest(plot_idx)`, client → host, mirroring
   `submit_spire_draft_choice`'s plain-params style). `GardenPlot` gains
   `session_mode: bool` + a `set_session_state(plot_data, days_elapsed)`
   setter the WorldScene pushes into it (not a self-pull from `SessionStore`)
   — `get_plot_data()`/`get_growth_stage()` branch on `session_mode` to use
   the pushed data instead of `SceneManager.save_manager`.
4. **Trophies and the stash chest need no request/response** — trophies read
   the already-synced `_pve_leaderboards` cache directly at spawn time (a
   snapshot, not live-updating while standing in the room — acceptable, a
   trophy render is not expected to change mid-visit); the stash chest is a
   pure UI-routing entity (`_toggle_stash_overlay()`, already fully wired,
   already session-synced by TID-376).
5. **Stash chest interact wiring** goes through the same `_check_interactions()`
   / `_handle_interact()` dispatch every other entity uses, so it gets the
   on-screen tap prompt for free (mobile parity) — not a special case.

**Implementation outline:**

1. **`game_logic/net/SessionState.gd`** — expand `guildhall_state` (v11→v12):
   add `garden_plots: Array` (3× `{}`, same shape as `SaveManager.garden_plots`)
   and `plants: Dictionary` inside it. Update `_sanitized_guildhall_state`
   + migration.
2. **`scenes/world/entities/GardenPlot.gd`** — `session_mode: bool`,
   `_session_plot_data: Dictionary`, `_session_days_elapsed: int`,
   `set_session_state(data, days_elapsed)`; `get_plot_data()`/
   `get_growth_stage()` branch on `session_mode` (pure `GardenDefs.growth_stage`
   call for the stage, no `SaveManager` touch in that branch).
3. **`scenes/world/NetSync.gd`** — 4 new reliable RPCs:
   `submit_guildhall_garden_request()`, `recv_guildhall_garden_update(payload)`,
   `submit_session_plant(plot_idx, seed_id)`, `submit_session_harvest(plot_idx)`.
4. **`scenes/world/WorldScene.gd`**:
   - `_ready()`'s named-map branch: `if map_name == "guildhall" and
     NetworkManager.is_active(): _spawn_guildhall_trophies();
     _spawn_guildhall_garden(); _spawn_guildhall_stash_chest()`.
   - `_spawn_guildhall_trophies()`: up to 3 pedestals from
     `_pve_leaderboards["coop_clears"]`, reusing `_make_trophy_pedestal`.
   - `_spawn_guildhall_garden()`: 3 `GardenPlot` nodes (`session_mode = true`),
     reuses `_garden_plot_nodes` (already exists, shared with the player-home
     path — mutually exclusive per current map). Host builds its cache
     directly from `SessionStore`; a client requests one via
     `submit_guildhall_garden_request`.
   - `_spawn_guildhall_stash_chest()`: procedural chest mesh + `Label3D`
     ("Guild Stash"), tracked in a new `_guildhall_stash_chest_node` field.
   - `_check_interactions()` / `_handle_interact()`: new
     `_find_nearby_guildhall_stash_chest()` check (label "STASH") calling
     `_toggle_stash_overlay()`.
   - `_show_garden_plot_panel()`: branch on `plot.session_mode` — plant
     button always enabled (no seed cost/count), calls
     `_submit_session_plant`/`_submit_session_harvest` instead of
     `sm.*`/`GameBus.plant_harvested.emit`.
   - RPC handlers + `_broadcast_guildhall_garden(target_peer := 0)` (mirrors
     `_broadcast_pve_leaderboards` exactly) + `_on_guildhall_garden_update_received`
     (updates cache, pushes into each spawned `GardenPlot` via
     `set_session_state`).
5. **Tests** — extend `tests/unit/test_session_state.gd` with
   `garden_plots`/`plants` coverage (defaults, round-trip, v12 migration).
   No WorldScene-level test for the RPC/spawn flow — same precedent as every
   other WorldScene orchestration function in this file (requires the full
   SceneTree/multiplayer harness).
6. **Validation** — same sandbox constraint (no Godot binary, HTTP 403
   reconfirmed).

## Changes Made

_Filled after Build phase._

## Changes Made

- **`game_logic/net/SessionState.gd`** — `guildhall_state` (v11→v12) gains
  `garden_plots: Array` (3× `{}`, same shape as `SaveManager.garden_plots`)
  and `plants: Dictionary`; `_sanitized_guildhall_state` pads/truncates
  `garden_plots` to exactly 3 entries and coerces non-Dictionary slots;
  migration backfills both fields.
- **`scenes/world/entities/GardenPlot.gd`** — `session_mode: bool`,
  `set_session_state(plot_data, days_elapsed)` (pushed by `WorldScene`, since
  `SessionStore` is authority-only and a client cannot read it directly);
  `get_plot_data()`/`get_growth_stage()` branch on `session_mode` to use the
  pushed data + `GardenDefs.growth_stage` instead of `SceneManager.save_manager`.
- **`scenes/world/NetSync.gd`** — 4 new reliable RPCs:
  `submit_guildhall_garden_request()`, `recv_guildhall_garden_update(payload)`
  (mirror the PvE-leaderboard request/broadcast pair exactly), and
  `submit_session_plant(plot_idx, seed_id)` / `submit_session_harvest(plot_idx)`
  (plain-params, mirror `submit_spire_draft_choice`'s precedent).
- **`scenes/world/WorldScene.gd`**:
  - `_ready()`: guildhall furnishing spawns (`_spawn_guildhall_trophies`,
    `_spawn_guildhall_garden`, `_spawn_guildhall_stash_chest`) moved to run
    **after** `_setup_coop()` (not inline with the player-home spawns) so
    `_net_sync` exists before a client's garden-snapshot request needs it —
    a real ordering bug caught during Build, not present in the original
    Plan.
  - `_spawn_guildhall_trophies()`: up to 3 pedestals from the already-synced
    `_pve_leaderboards["coop_clears"]` cache, reusing `_make_trophy_pedestal`/
    `register_npc`.
  - `_spawn_guildhall_garden()`: 3 `GardenPlot` nodes (`session_mode = true`,
    reuses the existing `_garden_plot_nodes` array); host builds its cache
    directly from `SessionStore`, a client requests one via
    `submit_guildhall_garden_request`.
  - `_spawn_guildhall_stash_chest()`: procedural chest + `Label3D`, registered
    as an NPC (`npc_type = "stash_chest"`).
  - `_check_interactions()` / `_handle_interact()`: one new `"stash_chest"`
    case in each existing npc_type dispatch chain (prompt label "STASH",
    action calls `_toggle_stash_overlay()`) — no new proximity-detection code.
  - `_show_garden_plot_panel()`: branches on `plot.session_mode` — free
    planting (no owned-seed-count gate), calls `_submit_session_plant`/
    `_submit_session_harvest` instead of `SaveManager`/`GameBus.plant_harvested`
    in that branch; solo behavior is byte-for-byte unchanged in the `else`.
  - New: `_refresh_guildhall_garden_visuals`, `_broadcast_guildhall_garden`,
    `_on_guildhall_garden_request_submitted`, `_on_guildhall_garden_update_received`,
    `_submit_session_plant`/`_on_session_plant_submitted`,
    `_submit_session_harvest`/`_on_session_harvest_submitted` (the last two
    validate plot state server-side — a stale/duplicate submit is a no-op).
- **`tests/unit/test_session_state.gd`** — `garden_plots`/`plants` coverage:
  defaults, round-trip, 3-slot padding/truncation, garbage-field fallback,
  v12 migration backfill + preservation (7 new cases).

### Validation

**Could not run `godot --headless --editor --quit` or `tests/runner.gd`** —
same sandbox constraint as every task in this goal (HTTP 403 reconfirmed).
Manual review: brace/paren/bracket balance check across every touched file
(`WorldScene.gd`'s pre-existing off-by-one, documented since TID-390, is
unchanged — this diff's opens/closes are exactly matched); no duplicate
function declarations; every `:=` inference site checked against a
concretely-typed RHS; traced `_ready()`'s call ordering carefully enough to
catch the `_net_sync`-not-yet-created bug described above before it shipped
(the player-home precedent this was modeled on never needed `_net_sync`, so
the ordering issue wasn't obvious from that template alone).

**Needs a real headless import + `tests/runner.gd` run before merging** —
same flag as every other task in this goal.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: added a new `### Guildhall trophies,
  garden & stash chest (TID-393)` subsection under "Party Legacy (GID-106)"
  (trophy reuse of the already-synced PvE leaderboard cache, the garden's
  authority-only-`SessionStore` constraint and its request/broadcast sync
  model, the deliberate free-planting/dedicated-`plants`-pool simplifications
  and why they deviate from the task's Research Notes, the `_setup_coop()`
  ordering bug found during Build, the stash chest's zero-new-sync reuse of
  `_toggle_stash_overlay`, and test coverage).
