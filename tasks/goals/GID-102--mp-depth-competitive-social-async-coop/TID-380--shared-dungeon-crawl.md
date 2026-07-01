# TID-380: Shared procedural dungeon crawl (synced seed)

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op runs on **named maps only** — `docs/agent/multiplayer-coop.md` lists *"Infinite chunk
world not supported"* and the procedural **dungeons** (DungeonGen, entered via doors) are
likewise outside co-op. This task lets a party enter a procedural dungeon **together** by
syncing the generation seed so every member generates the identical dungeon, then reuses the
GID-096 shared enemy/chest sync. This is the largest world-layer task and the most valuable
content unlock (it gives BID-024 — "co-op map has no enemies/chests" — a real answer).

## Research Notes

- **Why it's tractable.** DungeonGen is **deterministic from a seed** (see
  `docs/agent/named-maps-and-dungeons.md` — "procedural dungeons generated from a seed when
  entering dungeon doors"). If every peer uses the **same seed**, geometry, enemy placement,
  and chest placement are identical *by construction* — exactly the property GID-096's
  deterministic-spawn + discrete-sync model already relies on for named maps. So the new work
  is mostly **transition + seed propagation**, not a new sync system.
- **Seed propagation.** Co-op multi-map transitions already exist (GID-098 / TID-355):
  `NetSync.recv_map_transition(target_map, door_id)` makes all peers follow through a door.
  Dungeons aren't a named map though — they're generated. Extend the transition message (or
  add `recv_dungeon_transition(seed, door_id, depth)`) so the initiating peer's dungeon
  **seed** is broadcast and all peers call the dungeon entry with that explicit seed instead
  of rolling their own. Find the dungeon entry point in `SceneManager` (grep `dungeon` /
  `DungeonGen`) and add a seed override parameter if one isn't already threadable.
- **Authority owns the seed.** To avoid races (two peers entering different doors at once), the
  **authority** picks/blesses the dungeon seed and fans it out, same arbitration shape as the
  story-flag authority path (GID-098 / TID-356). The session's `world_seed` +
  door id + depth can derive a stable per-dungeon seed deterministically.
- **Reuse GID-096.** Once all peers are in the same generated dungeon, enemy engage-locks
  (first-engager-takes, defeat persists) and chest first-opener-takes already work — they are
  **map-agnostic** (`multiplayer-coop.md` → "Shared World-Object Sync", noted dormant only
  because madrian has none). The dungeon's enemies/chests get ids; confirm the id scheme is
  deterministic across peers (position-derived or generation-index — must match on all peers).
- **Persistence.** Dungeon progress is transient by single-player design (dungeons regenerate);
  for co-op, decide whether a cleared dungeon persists in the session or resets — recommend
  **transient** (matches single-player; don't bloat the session file). The shared seed lives
  only while the party is in the dungeon.
- **Map-scoped avatar sync (TID-352)** already filters cross-map avatars; a dungeon is a
  distinct `map_name`, so avatars converge correctly once all peers are inside. Verify the
  dungeon map name is identical on all peers (derive from the seed/door id, not a local
  counter).
- **Scope guard.** Still **not** the infinite chunk world (that needs chunk streaming sync —
  separate, out of scope). This is finite generated dungeons only.
- **Tests:** a unit test that the seed→dungeon generation is deterministic (same seed ⇒ same
  tile grid + entity ids) — likely already covered by DungeonGen tests; extend if needed. A
  loopback smoke that a `recv_dungeon_transition` lands both peers on the same generated map
  with matching entity ids (mirror `net_world_sync_smoke.gd`).
- **Docs:** update `docs/agent/multiplayer-coop.md` (lift the dungeon exclusion; document the
  shared-seed transition) and cross-reference `named-maps-and-dungeons.md`. Update BID-024.

## Plan

### Verified premises (re-derived from code, confirms the task's pre-research)

- `WorldScene._ready()` (`scenes/world/WorldScene.gd:324`) branches purely on the
  **string prefix** `"dungeon_"` of `map_name`: `var dseed: int =
  int(map_name.substr(8))`, then either reloads a previously-saved `.tres`
  (`MapRegistry.get_map(map_name) != null`) or calls
  `DungeonGen.generate(map_name, dseed)`. Nothing about this path cares how the
  string was constructed — no dungeon door exists anywhere today (confirmed:
  `grep -rn "dungeon_" assets/maps/*.tres` → no matches; the only
  `"dungeon_" + str(seed)` construction site is `InfiniteWorldGen.gd`, infinite-chunk
  only, out of co-op scope).
- `DungeonGen.generate(p_name, dungeon_seed)` is a pure function: one
  `RandomNumberGenerator` seeded from the int, no reads of global/save state, no
  wall-clock/random-without-seed calls anywhere in the file. All entity ids are
  **index-based counters** (`"de_%d" % enemy_uid`, `"dnpc_rest_%d" % npc_uid`,
  `"dtr_%d" % troom_uid`, fixed `"dc_0"`, `"dsr_0"`, `"exit"`), not
  position-derived or randomized — so two independent calls with the same
  `(p_name, dungeon_seed)` produce byte-identical tile grids and identical entity
  id/type/position lists. (One caveat found: `map.save_to_file(p_name)` at the end
  of `generate()` — the *second* peer to generate the same name will still compute
  identical content before saving, so this doesn't break determinism, just means
  both peers redundantly regenerate + write the same `.tres` to their own
  `user://maps/`, which is fine since each peer has its own `user://`.)
- `NetSync.recv_map_transition(target_map, door_id)` (reliable, any_peer →
  call_remote) → `WorldScene._on_map_transition_received` → `SceneManager.enter_map`
  / `exit_map()` already exists (TID-355) and is **completely content-agnostic**
  about `target_map` — it is exactly the RPC the task needs, reused as-is, zero
  changes to `NetSync.gd` required.
- Existing door-triggered pattern to imitate, from `WorldScene._handle_interact()`
  (`scenes/world/WorldScene.gd:2779-2813`): guard on
  `_coop_active and _net_sync != null and not _coop_map_transitioning`, set
  `_coop_map_transitioning = true`, `_net_sync.rpc("recv_map_transition", target_map,
  tdoor)`, then call the same local `SceneManager.enter_map(...)` /
  `SceneManager.exit_map()` the single-player path uses. The exit-door case
  (`target_map == ""`) already broadcasts `recv_map_transition("", "")` — this is
  fully generic to *any* current map, dungeons included, since `SceneManager.exit_map()`
  just pops the map stack regardless of what's on top. No special-casing needed for
  the dungeon exit door (`DungeonGen`'s `"exit"` door already has `target_map = ""`,
  `target_door_id = ""`, routed through the same `_handle_interact` door branch).

### Entry-trigger decision: HUD button, not a new map door entity

Two options considered:
1. **Author a new door/portal entity in `madrian.tres`.** Rejected for this slice:
   requires placing a tile position, carving/decorating terrain, wiring a
   `MapDoor` resource via the in-game map editor or a converter script, and
   picking a location that doesn't collide with existing madrian geography — a
   real content-authoring task, heavier than the sync-and-transition work this
   task is actually about, and orthogonal to it (madrian's layout is
   human-authored content, and `docs/human/` is never edited by the agent; adding
   a new gameplay entity to it doesn't require human sign-off since `.tres` isn't
   `docs/human/`, but it's still a bigger, separate content decision the task
   explicitly permits deferring — "or a simpler HUD/lobby button... if adding a
   full new map entity is too heavy for this slice — your call").
2. **A HUD button, host-only, co-op-only, visible on any co-op map.** Chosen.
   Follows the exact pattern already used for `_ensure_challenge_button()` /
   `_ensure_social_buttons()` — a `Button` created once in `_setup_coop()`,
   viewport-relative sizing per the UI-sizing rule, `pressed` signal wired to a
   new handler. This is reachable identically on desktop and mobile (a HUD
   button satisfies the mobile/desktop parity rule with zero extra work — no new
   key binding is introduced), requires no map authoring, and generalizes beyond
   madrian to any future co-op-supported named map for free (the button check is
   `_coop_active`, not `map_name == "madrian"`).

Button: **"Dungeon Crawl"**, visible only when `NetworkManager.is_host()` (the
task's "authority owns the seed" principle — avoids two peers racing to open
different dungeons at once; a non-host sees it hidden, mirroring how only the
host can dismiss/decide certain flows elsewhere. If a non-host wants to enter, they
ask the host verbally/via chat — out of scope to build a request-flow for this).

### Seed derivation

`"dungeon_%d" % seed` where `seed` is derived deterministically from
`SessionStore.get_state()`: `hash(str(st.world_seed) + "_dungeon_" +
str(st.days_elapsed))` when a session is open (always true in co-op per
`_setup_session`), falling back to `randi()` if `SessionStore` isn't open
(defensive; shouldn't happen when `_coop_active`). Using `world_seed +
days_elapsed` (not a raw `randi()`) means re-opening the "Dungeon Crawl" button
on the same in-game day reproduces the *same* dungeon (handy if the party wants
to return mid-crawl after a disconnect before persistence lands in a future
task), while a new day yields a fresh one — matches the task's suggested
"deterministic hash... if you want reproducibility" option. `hash()` on a String
returns an `int` (can be negative) — fine, since `int(map_name.substr(8))`
round-trips negative ints correctly via `String`'s `int()` parser (`"-123"` →
`-123`), and `DungeonGen` never assumes the seed is non-negative (it's only fed
into `RandomNumberGenerator.seed`, `int`, which accepts any 64-bit value, and
`dungeon_seed % 10000` in `_dist` calc — GDScript's `%` on a negative int can be
negative but `_EnemyRegistry.type_for_chunk_dist` is only ever called with
`abs()` applied already in that line, confirmed by reading `dist` calc: `int(abs(...))`).

### Implementation steps

1. **`scenes/world/WorldScene.gd`**
   - Add `_dungeon_btn: Button = null` var near the other HUD button vars
     (`_challenge_btn`, `_emote_btn`, ...).
   - Add `_ensure_dungeon_button()` (same shape as `_ensure_challenge_button`):
     create the button once, `vh`-relative size/position, hidden by default,
     `pressed.connect(_start_dungeon_crawl)`, shown only when
     `NetworkManager.is_host()` (set visibility once at creation since host-ness
     doesn't change mid-session; also re-assert in the same place
     `_ensure_social_buttons` is called so it's consistent).
   - Call `_ensure_dungeon_button()` from `_setup_coop()` alongside
     `_ensure_challenge_button()` / `_ensure_social_buttons()` (same
     `not NetworkManager.is_dedicated_server()` guard).
   - Add `_start_dungeon_crawl()`: computes the seed (per "Seed derivation"
     above), builds `target_map := "dungeon_%d" % seed`, then reuses the exact
     broadcast-then-local-enter pattern from the door branch: guard
     `_coop_active and _net_sync != null and not _coop_map_transitioning`, set
     `_coop_map_transitioning = true`, `_net_sync.rpc("recv_map_transition",
     target_map, "")`, `SceneManager.enter_map(target_map, "")`. Also guard
     `NetworkManager.is_host()` again defensively (button should already be
     hidden for non-hosts, but don't trust client-side UI alone for an
     authority decision — if a non-host somehow calls it, do nothing).
   - Hide `_dungeon_btn` in the same places `_challenge_btn` is hidden on
     teardown/battle-enter (`_teardown_coop`, wherever `_challenge_btn.hide()`
     appears for battle-start, e.g. lines ~1461, ~4507) so it doesn't linger
     during a PvP battle overlay.
2. **No changes to `NetSync.gd`, `SceneManager.gd`, or `DungeonGen.gd`** — confirmed
   unnecessary by the research above. This keeps the change minimal and
   correctly scoped.
3. **Docs** — update `docs/agent/multiplayer-coop.md`:
   - In "Co-op Story Mode (GID-098)" → "Multi-map transitions (TID-355)", add a
     short subsection "Shared dungeon crawl (GID-102 / TID-380)" documenting the
     Dungeon Crawl button, the seed derivation, and the "no new RPC" finding.
   - In "Limitations / Out of Scope (this slice)", qualify the dungeon-adjacent
     line: dungeons ARE now reachable in co-op via the new button; only the
     **infinite chunk world** remains unsupported (leave that bullet as-is,
     it's accurate and unrelated).
   - Add a documented **scope cut**: no new loopback smoke test for the dungeon
     transition specifically, because `recv_map_transition` is untouched code
     already exercised generically, and `DungeonGen` determinism is a pure-logic
     property independent of networking — a unit test proves the property that
     actually matters (same seed ⇒ same content on two independent calls, which
     is what two peers do). Writing a redundant smoke test that just re-proves
     `recv_map_transition` delivers a string (already implied by TID-355's own
     tests, if any) would not add coverage proportional to the time cost.
4. **Tests** — strengthen `tests/unit/test_dungeon_secrets.gd`'s
   `test_dungeon_determinism_same_seed` (currently only checks one center tile +
   chest count) to assert full-grid + entity-id equality: compare every tile in
   the `DW × DH` grid, compare `enemies`/`chests`/`npcs`/`doors` arrays
   element-by-element (id, type, position), across two independent
   `DungeonGen.generate()` calls with the same seed. This directly satisfies the
   task's requested unit test ("same seed ⇒ same tile grid + entity ids").
5. **Backlog** — check highest existing `BID-XXX`, update `BID-024` per the task
   instructions (note this task addresses the "no enemies/chests" problem via
   dungeons, but madrian itself is still empty — leave BID-024 open, don't
   archive).
6. **Validate** — headless import + `tests/runner.gd` per workflow.

### Why this satisfies "reuse GID-096" without new work

Once every peer's `WorldScene._ready()` runs with the same `map_name =
"dungeon_<seed>"`, each independently calls `DungeonGen.generate` (or reloads its
own `user://maps/dungeon_<seed>.tres` if it already generated it, e.g. from a
prior crawl this session) and gets byte-identical `enemies`/`chests` arrays with
identical ids. GID-096's engage-lock / first-opener-takes logic
(`_on_enemy_engaged_coop`, `_on_chest_opened_coop`) keys purely on those string
ids via `WorldObjectSync.encode_event(kind, id)` — it never inspects `map_name`.
So the sync "just works" the moment the ids match, which they do by construction.
No empirical test beyond the strengthened determinism unit test is needed to
support this claim; it follows deductively from reading `WorldObjectSync.gd`'s
id-keyed event shape (already documented in `multiplayer-coop.md`) plus the
newly-verified id-determinism.

## Changes Made

- **`scenes/world/WorldScene.gd`**:
  - Added `_dungeon_btn: Button = null` var (next to `_challenge_btn`).
  - Added `_ensure_dungeon_button()`: creates a "Dungeon Crawl" HUD button (viewport-relative
    sizing per the UI-sizing rule), visible only when `NetworkManager.is_host()`. Re-asserts
    visibility on every call (not just at creation) so it correctly reappears after a PvP
    battle re-attach hides it unconditionally.
  - Added `_start_dungeon_crawl()`: host-only (defensively re-checked, not just relying on
    button visibility). Derives a seed from `hash(str(world_seed) + "_dungeon_" +
    str(days_elapsed))` via `SessionStore.get_state()` when a session is open (falls back to
    `randi()` otherwise), builds `"dungeon_%d" % seed`, then reuses the exact
    broadcast-then-local-enter pattern already used by the door branch in
    `_handle_interact()`: `_net_sync.rpc("recv_map_transition", target_map, "")` +
    `SceneManager.enter_map(target_map, "")`, guarded by `_coop_map_transitioning`.
  - Wired `_ensure_dungeon_button()` into `_setup_coop()` alongside the existing
    `_ensure_challenge_button()` / `_ensure_social_buttons()` calls.
  - Hid `_dungeon_btn` alongside `_challenge_btn` in `_enter_pvp()` and
    `_enter_pvp_wagered()` so it doesn't linger during a PvP battle overlay.
  - **No changes to `NetSync.gd`, `SceneManager.gd`, or `DungeonGen.gd`** — confirmed
    unnecessary; `recv_map_transition` and the `"dungeon_"`-prefix load branch in
    `WorldScene._ready()` are already fully content-agnostic.
- **`tests/unit/test_dungeon_secrets.gd`**: added
  `test_dungeon_determinism_full_grid_and_entity_ids` — asserts full `DW × DH` tile-grid
  equality plus per-entity (enemies/chests/npcs/doors) id/type/position equality across two
  independent `DungeonGen.generate()` calls with the same seed. The pre-existing
  `test_dungeon_determinism_same_seed` (single center-tile + chest-count sample) is left
  intact; the new test is a stronger, additive check satisfying the task's requested
  "same seed ⇒ same tile grid + entity ids" coverage.
- **`tasks/backlog/BID-024--coop-map-has-no-enemies-chests.md`**: added an "Update" section
  documenting that this task addresses the reachability gap via dungeons, while explicitly
  **not** closing the item (madrian itself is still empty — see Documentation Updates below
  for the reasoning).

### Validation

- `godot --headless --editor --quit 2>&1 | grep -iE "Parse Error|Compile Error|Failed to load script" | grep -viE "imported/|Make sure resources"` → **empty** (clean compile).
- `godot --headless --path . -s tests/runner.gd` → **1691 passed, 0 failed, 1 pending** (pre-existing pending, unrelated). New test `test_dungeon_secrets::test_dungeon_determinism_full_grid_and_entity_ids` passes.
- `godot --headless --path . -s tests/net_world_sync_smoke.gd` → **PASS** (re-ran as a sanity check that GID-096's sync machinery, which this task relies on being map-agnostic, is unaffected).

### Scope cuts (documented, not silent)

- **No new loopback smoke test** mirroring `net_world_sync_smoke.gd` specifically for the
  dungeon transition. Reasoning: `recv_map_transition` is untouched, already-shipped code
  (TID-355); the only new property this task introduces is "two independent
  `DungeonGen.generate()` calls with the same seed produce identical content," which is pure
  logic with no networking dependency and is fully covered by the new unit test. A loopback
  test would mostly re-prove that `recv_map_transition` delivers a string over ENet — already
  implied by its existing shipped behavior — for a large time cost relative to the marginal
  coverage gained.
- **No new door/portal map entity.** A HUD button was chosen instead (see Plan). This can be
  revisited if a future task wants a more diegetic entry point (e.g. authoring an actual
  dungeon-door prop on madrian), but that's a content-authoring decision orthogonal to the
  sync work this task is scoped to.
- **No dungeon-clear persistence.** Per the task's own recommendation, dungeon progress stays
  transient (matches single-player); the shared seed only needs to survive for the crawl's
  duration and is recomputed fresh (or reused, if same-day) each time the host presses the
  button.

## Documentation Updates

**`docs/agent/multiplayer-coop.md`** (surgical edits — shared with other parallel GID-102 tasks):

- Added a new subsection **"Shared dungeon crawl (GID-102 / TID-380)"** under "Co-op Story
  Mode (GID-098)" → right after "Multi-map transitions (TID-355)", documenting: the
  entry-point gap that existed before this task, the host-only HUD button trigger and why it
  was chosen over an authored map door, the seed-derivation formula, the "no new RPC needed"
  finding (reuses `recv_map_transition` verbatim), why GID-096 sync "just works" once ids
  match by construction, the exit-door confirmation, the transient-progress decision, and the
  documented smoke-test scope cut.
- Updated the "Limitations / Out of Scope (this slice)" GID-096 bullet: replaced "The co-op
  map (madrian) happens to have no enemies/chests today, so the sync is dormant in practice"
  with a qualified statement — madrian itself is still empty (cross-referenced to BID-024,
  not fully resolved), but procedural dungeons are now reachable together via the new button,
  so the sync is exercised by real content.
- Updated the "Infinite chunk world not supported" bullet to note the finite-map constraint
  is now satisfied by either a named map *or* a finite generated dungeon — the infinite chunk
  world itself remains explicitly out of scope, unchanged.

**`tasks/backlog/BID-024--coop-map-has-no-enemies-chests.md`**: appended an "Update (GID-102 /
TID-380)" section. **Decision: left open, not archived.** Reasoning: BID-024's title and
original content are specifically about **madrian** (the map co-op lands on by default via
`enter_map_coop("madrian")`) having no enemies/chests. This task does not add any content to
madrian itself — it adds an *opt-in side trip* to a procedural dungeon that the host must
explicitly trigger. A session that never presses "Dungeon Crawl" still has zero enemies/chests
to interact with on its actual landing map, so the literal gap BID-024 describes persists.
Full resolution would require the first option BID-024 itself lists (add enemies/chests
directly to madrian), which is out of this task's scope. The update section makes this
distinction explicit for whoever revisits the item next.
