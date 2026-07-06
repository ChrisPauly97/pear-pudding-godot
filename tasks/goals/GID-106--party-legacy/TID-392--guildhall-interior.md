# TID-392: Party Guildhall Interior & Entry

**Goal:** GID-106
**Type:** agent
**Status:** done (headless import + test run unverified in-sandbox — see Validation note)
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The co-op session today is a shared world to explore together, but it has no **permanent gathering place** — the party has no "home." The single-player Player Home (GID-046) shows that an interior map can display personal history (trophy pedestals). This task extends that pattern to co-op: a **session-owned guildhall interior map** that all party members can enter together. The guildhall is a separate map from the single-player home — it reflects the party's collective identity, not any one player's house. Entry is via a HUD button (host-only, same pattern as co-op Spire TID-390) that broadcasts a map transition so the whole party enters together (reusing `NetSync.recv_map_transition`, TID-355). The guildhall is stored in the session state, so it persists across reconnects: a rejoining member lands back in the guild hall they last entered. All peers render each other inside via the existing map-scoped avatar sync (TID-352), making the space feel shared and inhabited. Single-player never sees the guildhall — it is gated entirely by `NetworkManager.is_active()`.

## Research Notes

**Map creation — reuse Player Home pattern (GID-046, CLAUDE.md map-storage rules).** The guildhall is a new `.tres` resource in `assets/maps/guildhall.tres` (or `guildhall_interior.tres`). It follows the same interior structure as `player_home.tres`: a 100×100 tile grid, WALL=1 boundary, GRASS=0 interior floor (e.g. tiles x:40–60, z:45–60 for a larger gathering space than the home), `spawn_x`/`spawn_z` at center. Add an **exit door entity** with `entity_id = "guildhall_exit"`, positioned at the entry edge, `target_map = ""` to pop back to madrian. Do **not** add an NPC bed or `npc_type = "bed"` — guildhall is a meeting space, not a rest location. Per CLAUDE.md, add a `const _GUILDHALL := preload("res://assets/maps/guildhall.tres")` line to `MapRegistry.gd` and add `"guildhall"` to the `_BUNDLED` dictionary. Generate a 12-character `.uid` sidecar file immediately (format: `uid://a1b2c3d4e5f6`), both to keep Godot's editor scanner happy and to ensure Android exports include the `.tres`.

**Session state tracking — new SessionState field with version bump.** Add `guildhall_state: Dictionary` to `SessionState` (v6→v7 migration, `_migrate_v6_to_v7`). Shape: `{purchased: bool, members_inside: Array[String]}` where `members_inside` tracks member tokens currently in the guildhall (for display/cosmetics, populated by avatar sync). `SessionState.has_guildhall() -> bool` returns `purchased`. A dedicated `_ensure_guildhall(token, name)` method on SessionState initializes the guildhall on first session load (auto-purchased, no coin cost — it is a feature unlock, not a purchasable good like the home). The migration backfills `guildhall_state = {purchased: true, members_inside: []}` for all sessions, so all co-op parties have access immediately without per-session purchasing.

**Entry point — host-only "Enter Guildhall" HUD button.** WorldScene gains a button (viewport-relative, sized per CLAUDE.md) visible only when `NetworkManager.is_active()` and `NetworkManager.is_host()`. On press, check `SessionStore.get_state().has_guildhall()` (always true post-migration, but guard for safety) and call `SceneManager.enter_map_coop("guildhall")` (reusing the existing coop entry point, or a new `enter_guildhall_coop()` variant). The call broadcasts `NetSync.recv_map_transition("guildhall", "spawn")` (TID-355 pattern) so the whole party enters together. Non-hosts cannot initiate entry (prevent confusion/desync), but follow the broadcast and land in the guildhall on the same step.

**Avatar sync — map-scoped (TID-352 pattern).** Avatars inside the guildhall sync normally via the existing `NetSync.recv_avatar()` flow. `AvatarSync.encode` carries `map_name` (the 5th element added in TID-352), and `_on_avatar_received` filters: only show an avatar when its map equals the local `map_name`. So if a member walks out of the guildhall to madrian via the exit door, their avatar disappears from the guildhall peers' view (hidden, not freed, for instant re-convergence if they re-enter).

**Single-player unchanged.** The guildhall button is never shown to single-player (guarded by `NetworkManager.is_active()`). The guildhall map file is a co-op-only asset — single-player code paths never reference it, so single-player exports are unchanged (though the map file is still bundled via MapRegistry, which is autoload-scanned on every export).

**Project invariants.** All guildhall entry/state code guarded by `NetworkManager.is_active()`. New `.tres` resource has `.uid` sidecar. SessionState version bump + migration. New avatar/exit-door entity types (same as existing templates, no new entity code needed). Headless import must pass.

## Plan

**Verified against actual code:**

- `assets/maps/player_home.tres` (the template to mirror) is a 100×100 grid,
  `WALL=1` everywhere except a small carved room, one `MapDoor` (exit,
  `target_map=""`), one `MapNpc` (bed — omitted here per Research Notes), a
  `spawn_x`/`spawn_z`, and no other entities. `scripts/convert_maps.py`'s
  `write_tres(map_name, data, out_path)` (its `.txt`-parsing step is not
  needed — `data` is a plain hand-buildable dict) is the exact tool to
  generate a new `.tres` in this format without a running Godot editor.
- `MapRegistry.gd`'s `_BUNDLED` dict is a flat `const preload()` map — adding
  `"guildhall"` is a 2-line change (const + dict entry), no other code paths
  care what a map's name is.
- **Entry/exit need zero new generic-flow code.** Verified against
  `_handle_interact()`'s door branch (`WorldScene.gd:4486-4507` in the
  TID-391 line numbering) and `exit_map()`: a co-op session already
  broadcasts `recv_map_transition` for *any* named-map door with a non-empty
  `target_map`, and *any* empty-`target_map` door already broadcasts
  `recv_map_transition("", "")` before calling `SceneManager.exit_map()`
  (which pops `map_stack` normally — no Spire-style special case needed,
  since the guildhall is a normal single-room sub-map like `player_home`,
  not a multi-floor one-way run). So: **as long as entry pushes `"madrian"`
  onto `map_stack` via the normal `enter_map()`** (not TID-391's
  `enter_coop_map_no_stack`, which is Spire-specific), the authored exit
  door's existing generic handling correctly pops back to `madrian` with no
  new code. Late-joiner redirect (TID-355, `SessionStore.current_map`) and
  map-scoped avatar sync (TID-352, `AvatarSync.encode`'s `map` field) are
  both entirely map-name-agnostic already — entering "guildhall" gets both
  for free.
- `SessionState.CURRENT_SESSION_VERSION` is already **10** (bumped by
  TID-391), not 6→7 as the Research Notes assumed when written before TID-391
  existed — this task bumps 10→11.

**Design decisions:**

1. **Room layout** (bigger than `player_home`'s to comfortably fit TID-393's
   furniture later): floor (GRASS=0) at tile x:40–60, z:45–61 inside a
   WALL=1-filled 100×100 grid; `spawn_x/z = (50, 59)` (south end, facing into
   the room); exit door `entity_id="guildhall_exit"`, `target_map=""`, at
   `(50, 46)` (one row inside the north floor edge, mirroring `player_home`'s
   door-one-row-in convention). No bed NPC (guildhall is a meeting space, per
   Research Notes).
2. **`SessionState.guildhall_state`**: `{"purchased": true, "members_inside": []}`
   as the direct class-default (not a lazily-initialized `_ensure_guildhall`
   call) — since it's auto-unlocked with no coin cost, every session
   (fresh or migrated) simply has it. `has_guildhall() -> bool` is a thin
   `return true` accessor kept for API symmetry with the documented shape and
   because TID-393 needs a stable place to read/write `garden_plots` inside
   this same dict. `members_inside` is carried in the shape (matches the
   documented shape, and gives TID-393/a future member-list UI a field to
   read) but is **not actively populated in this task** — wiring it to avatar
   map-enter/leave events would duplicate what `AvatarSync`'s per-peer
   `map_name` field already provides for free, for a cosmetic-only payoff;
   scope-cut, noted here rather than silently skipped.
3. **Entry point**: host-only Party Panel action "Guildhall" (`show_guildhall`/
   `on_guildhall`, exact shape as `show_spire`/`on_spire`). `WorldScene._start_guildhall()`
   mirrors `_start_dungeon_crawl()`: broadcast `recv_map_transition("guildhall", "")`,
   then local `SceneManager.enter_map("guildhall", "")` — the **normal**
   stack-pushing entry (not `enter_coop_map_no_stack`), so the exit door's
   existing generic `exit_map()` pop returns correctly to `madrian`.
4. **Single-player never sees it**: `show_guildhall = NetworkManager.is_host()`,
   same as every other Party Panel action; the Party Panel itself only opens
   in an active co-op session.

**Implementation outline:**

1. Generate `assets/maps/guildhall.tres` (via a throwaway script reusing
   `convert_maps.py`'s `write_tres`) + `assets/maps/guildhall.tres.uid`
   (random 12-char `uid://…`, matching the sidecar format of every other
   map).
2. `autoloads/MapRegistry.gd`: `const _GUILDHALL` + `_BUNDLED["guildhall"]`.
3. `game_logic/net/SessionState.gd`: `guildhall_state` field + `to_dict`/
   `from_dict`/`_sanitized_guildhall_state`-style tolerant fallback (mirrors
   `stash`'s pattern) + `has_guildhall()` + v10→v11 migration.
4. `scenes/ui/PartyPanel.gd`: `show_guildhall`/`on_guildhall` fields + one
   `_add_action_button` call.
5. `scenes/world/WorldScene.gd`: `_start_guildhall()`; wire
   `panel.show_guildhall`/`panel.on_guildhall` in `_open_party_panel()`.
6. **Tests**: extend `tests/unit/test_session_state.gd` with
   `guildhall_state` default/round-trip/migration cases (mirrors the
   `coop_spire` additions from TID-391).
7. **Validation**: same sandbox constraint as TID-390/391 (no Godot binary,
   confirmed HTTP 403 again) — manual review in lieu of a headless run,
   flagged identically.

## Changes Made

_Filled after Build phase._

## Changes Made

- **`assets/maps/guildhall.tres`** (new, + `.uid` sidecar) — 100×100 named
  map, mirrors `player_home.tres`'s structure: floor (GRASS) at x:40–60,
  z:45–61 inside a WALL boundary, `spawn_x/z = (50, 59)`, one exit door
  (`entity_id="guildhall_exit"`, `target_map=""`) at `(50, 46)`. No bed NPC.
  Generated via a throwaway script that calls `scripts/convert_maps.py`'s
  `write_tres()` directly with a hand-built data dict (not committed —
  one-time generation, matching how `convert_maps.py` itself is a one-time
  migration tool).
- **`autoloads/MapRegistry.gd`** — `const _GUILDHALL` preload + `_BUNDLED["guildhall"]`
  entry, same shape as every other named map.
- **`game_logic/net/SessionState.gd`** — new `guildhall_state: Dictionary`
  field (`{purchased: true, members_inside: []}`, always-purchased —
  auto-unlocked feature, not a purchasable good), `_sanitized_guildhall_state`
  tolerant fallback, `has_guildhall()` accessor, `to_dict`/`from_dict` wiring,
  v10→v11 migration (backfills the field for existing session files).
- **`scenes/ui/PartyPanel.gd`** — `show_guildhall`/`on_guildhall` fields +
  one `_add_action_button(grid, "Guildhall", on_guildhall, true)` call, same
  shape as `show_spire`/`on_spire`.
- **`scenes/world/WorldScene.gd`**:
  - `_open_party_panel()`: wires `panel.show_guildhall = NetworkManager.is_host()`,
    `panel.on_guildhall = _start_guildhall`.
  - `_start_guildhall()` (new): host-only, defensive `has_guildhall()` guard,
    broadcasts `recv_map_transition("guildhall", "")`, then locally calls the
    **normal** `SceneManager.enter_map("guildhall", "")` — deliberately not
    TID-391's `enter_coop_map_no_stack`, since the guildhall (unlike the
    Spire) is a single room entered/exited repeatedly; using the normal
    stack-pushing entry means the map's authored exit door already works via
    the existing generic door-interact → `exit_map()` chain, with no new
    exit code required.
- **`tests/unit/test_session_state.gd`** — `guildhall_state` coverage: defaults,
  round-trip, garbage-field fallback, v11 migration backfill + preservation
  (6 new cases).

Nothing else was needed: late-joiner map redirect (TID-355) and map-scoped
avatar sync (TID-352) are both already fully map-name-agnostic, so entering
"guildhall" gets both behaviors for free.

### Validation

**Could not run `godot --headless --editor --quit` or `tests/runner.gd`** —
same sandbox constraint as TID-390/391 (HTTP 403 from the agent proxy on the
Godot release zip, reconfirmed this session; no cached binary). Manual
review instead: verified the generated `.tres`'s `tiles`/`heights`
`PackedInt32Array`s are each exactly 10000 entries (100×100) with the
expected 357-tile (21×17) grass room via a Python parity check; brace/paren/
bracket balance check across every touched file (WorldScene.gd's
pre-existing off-by-one, documented by TID-390, is unchanged — this diff's
opens/closes are exactly matched); no duplicate function/const declarations;
every `:=` inference site checked against a concretely-typed RHS.

**Needs a real headless import + `tests/runner.gd` run before merging** —
same flag as GID-102/103/105/106(TID-390/391)/110's precedent.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: added a new `### Party guildhall —
  interior map & entry (TID-392)` subsection under "Party Legacy (GID-106)"
  (map structure + generation method, entry point, why the normal
  stack-pushing `enter_map()` was used instead of TID-391's no-stack helper,
  `SessionState.guildhall_state` shape and the always-purchased/
  not-yet-populated-`members_inside` decisions, and test coverage). Updated
  the section's intro line now that TID-390/391 are both done.
