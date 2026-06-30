# TID-371: 2v2 team duels (allies-vs-allies battle mode)

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP today is strictly **2 players** (`docs/agent/multiplayer-coop.md` → "PvP is LAN/loopback
only, 2 players"). The N-player joint battle engine (GID-099) already supports 2–4
participants for **allies-vs-boss**. This task adds **team PvP**: two teams of human allies
(e.g. 2v2) fight each other, reusing that engine. This is the largest battle-layer task.

## Research Notes

- **Engine reuse — `game_logic/battle/GameState.gd`.** `setup_coop_battle(n_allies,
  ally_setup, boss_setup)` builds N ally `PlayerState`s + 1 boss; turn rotation is already
  `(current_player_idx + 1) % players.size()` (generalised, see GID-099 docs). For team PvP
  the change is **targeting + win/loss by team**, not turn order:
  - Add a `team_battle: bool` flag (parallel to `coop_battle`) and a per-player `team: int`
    (0 or 1). No boss; every player `is_ai = false` (or AI-filled if a slot is empty).
  - `opponent()` for a player on team T must return an **enemy-team** target (lowest-HP
    enemy hero, reusing `_get_lowest_hp_ally`-style logic generalised to "lowest-HP player
    not on my team"). Attacks/spells may target any enemy-team board/hero — extend the
    `target_pidx` plumbing already added to `encode_attack` (GID-099) and the `pidx`
    cross-board spell targeting (GID-100).
  - `is_game_over()` / `winner()` by team: a team loses when **all** its players' heroes are
    dead; `winner()` returns the surviving team id.
- **Wire format — `game_logic/net/BattleNetProtocol.gd`.** `encode_attack` already carries
  `target_pidx`; team play also needs the acting player's team known to the authority. Keep
  intents player-indexed (the authority maps `peer_id → player_idx` exactly as the co-op-PvE
  referee does, see `_coop_peer_to_idx` / `_pvp_peer_to_idx`).
- **Relay — `scenes/battle/BattleNetSync.gd`.** Add a distinct RPC set for team PvP
  (`send_team_intent` / `sync_team_state` / `team_battle_ended` / `request_team_sync`)
  mirroring the co-op-PvE RPCs (lines 48–82) so modes never share a handler. Authority owns
  the canonical `GameState`, broadcasts mirrors to all participants; clients render from
  their own perspective (generalise `_my_idx()`/`_opp_idx()` — for teams, "my side" vs "the
  rest", grouped by team in the arena layout).
- **Scene — `scenes/battle/BattleScene.gd` + `autoloads/SceneManager.gd`.** Add
  `enter_team_battle(local_player_idx, team_assignments, all_decks)` mirroring
  `enter_coop_pve_battle` / `enter_pvp_battle`. Reuse the GID-100 square-battlefield ally bar
  to show all participants grouped by team. Gate everything behind a new `_team_pvp: bool`.
- **Challenge/handshake — `scenes/world/NetSync.gd` + WorldScene.** Extend the proximity
  challenge flow (`request_battle`/`respond_battle`) to form teams. Simplest first cut:
  challenger picks a partner from the roster, both confirm, then the other two confirm — or
  scope this task to **the authority assigns teams from the 4-peer session** and the world
  HUD offers a "Team Duel" button when ≥4 players are present. Keep team formation UI minimal.
- **Rewards/rating:** wire to TID-370 so a team duel updates each participant's rating
  (team-average expected score, or pairwise). Coordinate if TID-370 lands first.
- **Tests:** extend `tests/unit/test_coop_battle_state.gd` (or a new
  `test_team_battle_state.gd`) for team targeting, per-team win/loss, turn rotation across
  4 players on 2 teams, `to_dict`/`from_dict` with `team_battle` + `team` fields. A
  `tests/net_team_pvp_smoke.gd` loopback (4 peers) if practical (mirror `net_pvp_smoke.gd`).
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Team Duels" subsection under PvP)
  and the GID-099 engine notes if `GameState` API changes.

## Plan

Researched `GameState`, `SpellEffectResolver`, `BattleNetProtocol`, `BattleNetSync`,
`BattleScene` (PvP + GID-099 co-op-PvE sections), `SceneManager` battle entry points, and
the WorldScene challenge flow. Key finding: `_apply_remote_intent`'s opponent resolution
(`opp_idx = 1 - player_idx`) and `SpellEffectResolver`'s two `_state.players[1 - caster_pid]`
lookups are the only places that hard-code 2-player indexing for *untargeted* effects;
everything else (`_pvp_resolver_target`'s side/slot branch, the GID-100 `pidx` ally-targeting
plumbing) already addresses players by absolute index and is N-player-safe. This makes a
**surgical, low-risk generalization** possible instead of touching all ~30 spell match arms.

**Scope cut (flagging explicitly since this is the goal's largest battle-layer task):**
manual enemy-target selection is deferred — v1 auto-targets the **lowest-HP-alive member of
the enemy team** (reusing the exact pattern `GameState._get_lowest_hp_ally` already uses for
co-op-PvE boss targeting), so no new tap-to-target UI is needed; attacks/spells transparently
hit the weakest enemy. `BattleNetProtocol.encode_attack`'s existing `target_pidx` field stays
wired for a future "pick your target" enhancement but is unused (always -1) in this slice.
Team formation is host-assigns-from-the-4-peer-session via one "Team Duel (2v2)" HUD button
(no individual accept/decline), per the task's own "keep team formation UI minimal" guidance.

1. **`game_logic/battle/GameState.gd`**: add `team_battle: bool` and `player_teams: Array[int]`
   (parallel array, 0/1 per player index). Add `setup_team_battle(team_a_setup, team_b_setup)`
   building 4 players interleaved `[teamA_0, teamB_0, teamA_1, teamB_1]` so the existing
   `(idx+1) % size` turn rotation naturally alternates teams every turn (no rotation changes
   needed). Generalize `opponent()`: when `team_battle`, return the lowest-HP alive member of
   the **other** team from `current_player_idx` (new `_get_lowest_hp_enemy_team_member`,
   sibling to `_get_lowest_hp_ally`). Generalize `is_game_over()`/`winner()`: a team loses when
   both its members' heroes are dead; `winner()` returns the surviving team id (0/1). Add
   `opponent_idx() -> int` (index of `opponent()`) used by `_apply_remote_intent`/
   `_apply_hero_power_effect` instead of `1 - idx`. `to_dict`/`from_dict` carry the two new
   fields (default `false`/`[]`, so existing 2-player and co-op-PvE saves are untouched).
2. **`scenes/battle/SpellEffectResolver.gd`**: replace the two
   `_state.players[1 - caster_pid]` lookups (`resolve_emergence`, `resolve_spell`) with
   `_state.opponent()`. Behavior-preserving for 2-player PvP and co-op-PvE-with-2-allies
   (`opponent()` already equals `players[1-idx]` there); this is also a latent-bug fix for
   3-4-ally co-op battles where a non-0/1 ally casts an untargeted enemy-effect spell (was
   indexing `1 - caster_pid` which goes negative) — call out in Changes Made, not a new task.
3. **`scenes/battle/BattleScene.gd`** — new `_team_pvp: bool` section mirroring `_coop_pve`'s
   var block exactly (`_team_peer_to_idx: Dictionary`, `_team_ended: bool`). Changes:
   - `_is_pvp_host()`/`_is_pvp_client()`: OR in `_team_pvp`.
   - `_my_idx()` unchanged; `_opp_idx()`: add a `_team_pvp` branch returning
     `_state.opponent_idx()` (mirrors the existing `_coop_pve` branch already there).
   - `_apply_remote_intent`: replace `var opp_idx: int = 1 - player_idx` with
     `var opp_idx: int = _state.opponent_idx() if (_team_pvp) else 1 - player_idx` (PvP/co-op-PvE
     paths byte-for-byte unchanged); `_resolve_remote_attack`'s `defender_pid = 1 - attacker_pid`
     gets the same conditional.
   - `_apply_hero_power_effect`: same conditional for its `enemy` lookup.
   - `_ready()`: add `elif _team_pvp: _setup_team_battle()` branch.
   - `_send_intent()`: route to `send_team_intent` when `_team_pvp` (alongside the existing
     `_coop_pve` ? `send_coop_intent` : `send_intent` ternary).
   - `_check_game_over()`: add `if _team_pvp: _team_check_game_over(); return`.
   - `_process()`: add team-sync retry branch mirroring `_process_coop_sync`.
   - New functions (mirroring the `_coop_pve` set 1:1): `_setup_team_battle()`,
     `_build_team_battle_state()` (host-only, builds 4 players from `_team_decks: Array` +
     `player_teams` from `_team_assignments: Array[int]`), `_on_team_state()`,
     `_on_team_intent()`, `_on_team_sync_request()`, `_broadcast_team_state()`,
     `_team_check_game_over()` (win/loss = `_state.winner()` team id matches `player_teams[_my_idx()]`),
     `_on_team_battle_ended()`, `_finish_team_battle()` (rewards: coins/xp identical to
     `_apply_coop_pve_rewards` minus the soulbound-card drop — team duels stay "no
     cards/XP" like 2-player PvP, matching the existing duel-style reward convention; ante
     wagers are out of scope for v1), `_process_team_sync()`.
   - New read-only status panel `_build_team_arena_layout()`/`_refresh_team_panels()` —
     near-identical to `_build_coop_arena_layout`/`_refresh_coop_ally_panels` but iterates
     **all 4** players (not boss-excluded) and labels each `"P%d (Team %s)"`; no tap targets
     (no manual targeting in v1, per the scope cut above).
4. **`game_logic/net/BattleNetProtocol.gd`**: no changes — `encode_attack`'s `target_pidx`
   and `encode_play_spell`'s `target` dict already round-trip everything needed for a future
   manual-targeting follow-up.
5. **`scenes/battle/BattleNetSync.gd`**: 4 new reliable RPCs mirroring the co-op-PvE set
   exactly: `send_team_intent`, `sync_team_state`, `team_battle_ended`, `request_team_sync`.
6. **`autoloads/SceneManager.gd`**: `enter_team_battle(local_player_idx, team_assignments:
   Array[int], all_decks: Array)` mirroring `enter_coop_pve_battle`. New
   `GameBus.team_battle_ended(did_win: bool)` signal + `_on_team_battle_ended` handler
   mirroring `_on_coop_pve_battle_ended` (restores the shared co-op world; no card/defeat
   tracking, matching 2-player PvP's `_on_pvp_battle_ended`).
7. **`scenes/world/WorldScene.gd`**: a "Team Duel (2v2)" HUD button, visible only when
   `NetworkManager.is_active() and NetworkManager.is_host() and multiplayer.get_peers().size()
   >= 3` (host + 3 clients = 4 total). Pressing it: host assigns `player_teams` from the
   connected peer list (host + first-joined client = team 0, the other two = team 1, deterministic
   by join order so behavior is reproducible), builds each participant's deck via
   `_local_deck_for_net()`/`_session_token_by_peer`-resolved decks, and `rpc`s a new reliable
   `NetSync.notify_team_duel_start(my_team_idx, team_assignments, decks)` to every peer
   (including itself via direct call) before each calls `SceneManager.enter_team_battle(...)`.
   No accept/decline (matches the task's "keep UI minimal" + host-assigns guidance) — log this
   as a documented limitation, not a silent gap.
8. **Rating wiring (GID-102 / TID-370 already landed)**: `_on_team_battle_ended` (host only)
   computes each player's ELO delta via `RatingMath.updated(rating, avg_opp_team_rating, score,
   games)` — "team-average expected score" per the task notes — using `_session_token_by_peer`
   for all 4 tokens, writes all 4 records, bumps `pvp_games` for each. New
   `_update_team_pvp_ratings` helper in WorldScene, parallel to `_update_pvp_ratings`.
9. **Tests**: new `tests/unit/test_team_battle_state.gd` — `setup_team_battle` player/team
   interleaving, turn rotation alternates teams across all 4 slots and wraps, `opponent()`
   picks the lowest-HP alive enemy-team member, `is_game_over()`/`winner()` team-aware (one
   member down ≠ team loss; both down = team loss), `to_dict`/`from_dict` round-trip. Extend
   `tests/unit/test_session_state.gd`/none needed (SessionState unchanged). **No new live-socket
   smoke test** in this slice — a correct 4-peer ENet loopback smoke test is a substantial
   separate effort (precedent: `net_pvp_client_smoke.gd` is 2-peer and already non-trivial);
   logging this as a backlog item instead of skipping it silently.
10. **Docs**: new "Team Duels (2v2)" subsection in `docs/agent/multiplayer-coop.md` under PvP,
    documenting the auto-target-lowest-HP model, the host-assigns formation flow, and the
    `opponent()`/`SpellEffectResolver` generalization (and its latent-bug side-fix for 3-4-ally
    co-op battles). Add the new test row to the Tests table.

**Out of scope for this task** (flagged as backlog items, not silently dropped): individual
team-invite accept/decline, wagered team duels, a live 4-peer smoke test, and 3v3/4v4 (this
slice is 2v2 only — `setup_team_battle` is not generalized to N-per-team).

This plan keeps every change behind `_team_pvp` and additive `if` branches mirroring the
GID-099 pattern; the only edits to shared code (`GameState.opponent()`, the two
`SpellEffectResolver` lookups, `_apply_remote_intent`'s `opp_idx`) are proven
behavior-preserving for existing modes by construction (the team_battle branch is `if`-gated
and the non-team branch is byte-for-byte the prior expression).

### Addendum — manual enemy-target selection (scope expanded per user decision)

Rather than threading `target_pidx` through every spell-effect match arm, a single **focus**
mechanism covers attacks, single-minion spells, and hero-targeted spells with ~6 contained edits:

- New `_team_focus_target_pidx: int = -1` on BattleScene (-1 = auto). A **tap-to-focus** control
  on the two enemy-team buttons in the new team status bar sets it, then `_refresh_all()` —
  no separate "targeting mode," it just changes which enemy's board/hero `EnemyArea` renders.
- `_opp_idx()`: when `_team_pvp`, return `_team_focus_target_pidx` if it's currently a valid,
  alive enemy-team member, else fall back to `_state.opponent_idx()` (auto lowest-HP). Every
  existing render/target-building call site (`EnemyArea` board/hand/hero, `_pvp_target_dict_for_card`,
  `_attempt_attack`'s slot lookup) already routes through `_opp_idx()`, so focus propagates for
  free to spell minion/board targeting and attack-target-slot resolution — **no changes needed**
  in those call sites.
- **Attacks need one new wire field passed through** (the slot index alone is ambiguous between
  2 enemy boards): `_attempt_attack` sends `BattleNetProtocol.encode_attack(a_slot, t_slot,
  _opp_idx() if _team_pvp else -1)` (the `target_pidx` param already exists on the wire, just
  unused). `_apply_remote_intent`'s `opp_idx` becomes: when `_team_pvp`, use the intent's
  `target_pidx` if it names a living enemy-team member, else `_state.opponent_idx()`.
  `_resolve_remote_attack` takes the resolved `opp_idx` as its defender index instead of
  `1 - attacker_pid`.
- **Hero-targeted spells need an explicit owner** (no CardInstance to infer it from):
  `_on_target_chosen_hero` sends/locally-resolves `{"type": "hero", "pidx": _opp_idx()}` instead
  of `{"type": "hero"}` when `_team_pvp`. `_pvp_resolver_target` passes `pidx` through when
  present. `SpellEffectResolver.resolve_spell`'s one `"hero"`-branch (in `deal_damage_single`)
  uses `_state.players[pidx].hero` when `pidx` is present, else `opponent.hero` (unchanged for
  every other mode).
- **Single-minion-targeted spells need no wire change** — `{"type": "minion", "card": target}`
  already carries the actual `CardInstance`. Add one resolver helper,
  `_find_card_owner(card, fallback) -> PlayerState` (scans `_state.players` for board
  membership), and use it instead of blanket `opponent` in the only 3 match arms that remove a
  dead explicit-target minion: `deal_damage_single`, `lifesteal_hit`, `curse_minion`. The other
  4 ENEMY_TARGETED_EFFECTS (`apply_poison_single`/`freeze_single`/`bind_minion`/`stun_single`)
  mutate the `CardInstance` in place with no removal call, so they need no change.
- `_pvp_resolver_target`'s side/slot bound check (`side >= 0 and side < 2`) generalizes to
  `side < _state.players.size()` so a team battle's 4-player indices pass validation.
- **Documented v1 simplification**: AOE/random/hand-disruption spell effects (`deal_damage_all`,
  `deal_damage_random`, hand-discard effects, hero powers' `active_damage_all`, etc.) and
  untargeted single-target fallbacks all still resolve against `_state.opponent()` (the
  GameState-level auto pick, not the BattleScene-level focus) — i.e. they hit the auto-selected
  lowest-HP enemy's board/hand, not a manually-focused one and not both enemies' combined board.
  This is a deliberate, documented scope line, not a silent gap.

### Addendum — discovered bug: `_execute_attack` hardcodes player indices 0/1

While generalizing `_opp_idx()`, found that `_execute_attack` (the **host's own local** attack
resolution — only the **client**'s attacks are relayed through `_apply_remote_intent`/
`_resolve_remote_attack`; see `_attempt_attack`'s `_is_pvp_client()` branch) hardcodes
`_state.players[1]` (defender) and `_state.players[0]` (attacker) instead of `_opp_idx()`/
`_my_idx()`. This is dormant for solo and 2-player PvP (where those literals always equal
`_my_idx()`/`_opp_idx()`) but is a **real, currently-shipped bug in co-op PvE (GID-099)**: when
the host (always ally-0) attacks the boss with ≥2 allies present, `_execute_attack` damages/
removes against `players[1]` (ally-1, a **teammate**) instead of the boss. Since team PvP
reaches the identical code path and a host is not always paired with opponent-index-1, this
task fixes `_execute_attack` to use `_my_idx()`/`_opp_idx()` (behavior-preserving for solo/2P
PvP, genuine bugfix for co-op PvE, required-correct for team PvP). Logged as **BID-026** with a
note that BattleScene's host-local resolution paths still lack scene-level test coverage (only
pure `GameState`/`SpellEffectResolver`-adjacent logic is unit-tested; `_execute_attack` itself
is a `Node` method with no isolated test harness today).

## Changes Made

- **`game_logic/battle/GameState.gd`**: added `team_battle: bool` / `player_teams:
  Array[int]`; `setup_team_battle(team_a_setup, team_b_setup)` builds 4 interleaved
  players `[teamA_0, teamB_0, teamA_1, teamB_1]`; generalized `opponent()` (new
  `_get_lowest_hp_enemy_team_member`, correctly prefers alive over dead unlike the
  pre-existing `_get_lowest_hp_ally` — see BID-028) + new `opponent_idx()`; team-aware
  `is_game_over()`/`winner()`; `to_dict`/`from_dict` carry the new fields.
- **`scenes/battle/SpellEffectResolver.gd`**: `resolve_spell`/`resolve_emergence`'s
  `_state.players[1 - caster_pid]` lookups generalized to `_state.opponent()` (also a
  side-fix for 3-4-ally co-op-PvE spells, which previously could index negatively); new
  `_find_card_owner(card, fallback)` (board-membership scan) used by `deal_damage_single`/
  `lifesteal_hit`/`curse_minion`'s removal-on-death so a manually-focused enemy minion is
  removed from its *actual* owner's board; `deal_damage_single`'s hero branch reads an
  optional `pidx` from the explicit target.
- **`scenes/battle/BattleScene.gd`**: new `_team_pvp` section (vars, `_setup_team_battle`,
  `_build_team_battle_state`, `_on_team_state`/`_on_team_intent`/`_on_team_sync_request`/
  `_broadcast_team_state`, `_team_check_game_over`, `_on_team_battle_ended`/
  `_finish_team_battle`, `_process_team_sync`) mirroring the GID-099 `_coop_pve` structure.
  `_opp_idx()` gained a focus-aware team branch (`_team_focus_target_pidx` override else
  `GameState.opponent_idx()`); `_is_pvp_host`/`_is_pvp_client`/`_ready`/`_send_intent`/
  `_check_game_over`/`_process`/`_refresh_all` all gained `_team_pvp` branches. New
  `_pvp_resolver_target` hero+pidx case and generalized side/slot bound check
  (`players.size()` not `2`). New `_resolve_intent_opp_idx` helper replaces
  `_apply_remote_intent`'s hardcoded `opp_idx`/`_resolve_remote_attack`'s `defender_pid`
  (also fixes the co-op-PvE relay bug — BID-026). New `_build_team_arena_layout`/
  `_refresh_team_panels` (read-only HP/mana bar, enemy panels tap-to-focus). **Bugfix**:
  `_execute_attack` (host's own local attack resolution) used hardcoded
  `_state.players[1]`/`[0]` instead of `_opp_idx()`/`_my_idx()` — fixed (BID-026).
- **`scenes/battle/BattleNetSync.gd`**: 4 new reliable RPCs (`send_team_intent`,
  `sync_team_state`, `team_battle_ended`, `request_team_sync`) mirroring co-op PvE.
- **`autoloads/GameBus.gd`**: new `team_battle_ended(did_win)` signal.
- **`autoloads/SceneManager.gd`**: new `enter_team_battle(local_player_idx,
  team_assignments, all_decks)` + `_on_team_battle_ended` (restores the shared world,
  no rewards — mirrors `_on_coop_pve_battle_ended`).
- **`scenes/world/NetSync.gd`**: new `notify_team_duel_start(my_idx, team_assignments,
  all_decks)` RPC.
- **`scenes/world/WorldScene.gd`**: host-only "Team Duel (2v2)" HUD button (visible at
  4 connected players); `_start_team_duel`/`_on_notify_team_duel_start` assign teams
  (host + first-sorted client vs the other two) and resolve each participant's **real**
  deck via `_team_deck_for_peer` (reads the GID-095 `SessionState` member record
  directly — no extra deck-collection RPC round-trip); `_accept_challenge` unrelated fix
  carried from TID-370 unaffected. New `_on_team_battle_ended_coop` (host-only,
  permanently connected to `GameBus.team_battle_ended`): team-average-expected-score
  ELO update for all 4 participants via `RatingMath`, using the formation
  `_start_team_duel` recorded.
- **Tests**: new `tests/unit/test_team_battle_state.gd` (17 cases: interleaving, turn
  rotation/wrap, opponent auto-target incl. alive-over-dead preference, team-aware
  win/loss, round-trip incl. legacy-dict tolerance). Full suite 1729 passing (was 1712);
  `net_pvp_smoke`/`net_pvp_client_smoke`/`net_pvp_dedicated_smoke`/
  `net_dedicated_server_smoke`/`net_coop_smoke`/`net_coop_npeer_smoke`/`net_rehost_smoke`
  all green (verified the shared-code generalizations didn't regress 2-player PvP /
  co-op-PvE / dedicated-server paths); headless import clean.
- **Backlog**: BID-026 (fixed — co-op-PvE host/ally attacks resolved against the wrong
  opponent index; discovered + fixed as part of generalizing `_opp_idx()`/intent
  resolution for team PvP), BID-027 (logged, not fixed — boss AI turn execution has the
  same hardcoded-index-1 issue but is unreached by team PvP, no AI participants), BID-028
  (logged, not fixed — `_get_lowest_hp_ally` can get stuck targeting a dead ally;
  `_get_lowest_hp_enemy_team_member` was written correctly from the start).

**Scope cuts from the original task notes** (documented, not silent): no manual
team-invite accept/decline (host-assigns-and-starts immediately), no wagered team duels,
no live 4-peer ENet loopback smoke test (covered by 17 pure `GameState` unit tests
instead — a correct 4-peer smoke harness is a substantial separate effort per the
existing 2-peer `net_pvp_client_smoke.gd` precedent), and 2v2 only (not 3v3/4v4).

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: new "Team Duels (GID-102 / TID-371)" subsection
  under PvP Card Battles (model, targeting/focus mechanism, networking, status bar,
  team formation, rating integration, bugs found+fixed); updated the PvP limitations
  line (2-player vs 2v2 team duels, rating now covers both); added the
  `test_team_battle_state.gd` row to the GID-099 Tests table.
