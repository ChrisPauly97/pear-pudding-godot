## Networked and async battles: ghost duels, PvP (player, referee, spectator,
## reconnect resume), co-op PvE and 2v2 team duels, plus their end handlers.
##
## A child of the SceneManager autoload, created in `SceneManager._ensure_modules()`.
## Reach SceneManager state as `_sm.<name>` and write the state only through
## `_sm._transition_to()`. Use `_sm.add_child` rather than a bare `add_child`.
extends Node

const _SceneManager = preload("res://autoloads/SceneManager.gd")
const _SceneFlow = preload("res://game_logic/SceneFlow.gd")
# gdlint:ignore = constant-name
const State = _SceneFlow.State

# Ghost duels (GID-102 / TID-377): flat, modest, clearly-async coin reward on win.
# No rating change ever (see enter_ghost_duel doc comment) — coins only.
const GHOST_DUEL_COIN_REWARD: int = 25

## enemy_data for a player-vs-player battle: BattleScene builds both sides from
## the PvP decks, so every drop/reward field stays inert. Duplicated per launch
## because BattleScene writes into the dict it is handed.
const PVP_ENEMY_DATA: Dictionary = {
	"display_name": "Player",
	"enemy_type": "",
	"is_boss": false,
	"drop_pool": [],
	"coin_reward": 0,
}

var _sm: _SceneManager

# Enemy type for the current co-op PvE battle (for achievement tracking)
var _coop_pve_enemy_type: String = ""


func _init(scene_manager: _SceneManager) -> void:
	_sm = scene_manager


## Enters a local, single-player battle against an AI-piloted snapshot of another
## (possibly offline) session member's deck — async competition with ZERO live
## networking. Reuses the exact same solo-battle setup path as an NPC tavern duel
## (`_on_duel_requested`): no `_pvp`/`_coop_pve` flags are set, so BattleScene's
## plain `else` branch builds `_state.players[1]` from `enemy_data["enemy_deck"]`
## and BasicAI drives it, unchanged.
##
## `opponent_snapshot` is the dict from `SessionState.get_ghost_snapshot(token)`
## (`{token, name, deck, rating}`); an empty/invalid snapshot is rejected here so a
## bad caller can never launch a battle with an empty deck.
##
## Decision (documented, not silently chosen either way): a ghost duel NEVER moves
## PvP rating — win or lose. The opponent is AI-piloted, not the real remote
## player, so rating movement here would let a player farm free ELO against their
## own cached snapshot (or a stale/offline friend's) with no real matched risk.
## Only a flat, modest coin reward is granted, and only on a win — see
## `_on_ghost_duel_ended`.
func enter_ghost_duel(opponent_snapshot: Dictionary) -> void:
	if _sm.current_state() != State.WORLD:
		return
	var deck: Array = opponent_snapshot.get("deck", [])
	if deck.is_empty():
		GameBus.hud_message_requested.emit("That ghost has no deck to duel.")
		return
	if _sm.save_manager.player_deck.size() < IsoConst.DECK_MIN:
		GameBus.hud_message_requested.emit("Deck too small — add at least %d cards first." % IsoConst.DECK_MIN)
		return
	var opponent_name: String = str(opponent_snapshot.get("name", "Ghost"))
	var captured_enemy_data: Dictionary = {
		"display_name": "%s (Ghost)" % opponent_name,
		"enemy_type": "",
		"is_boss": false,
		"drop_pool": [],
		"coin_reward": 0,
		"enemy_deck": deck,
	}
	_sm._enter_battle(func(b: Node) -> void:
		b.enemy_data = captured_enemy_data
		b.set("_ghost_duel", true)
		b.set("_ghost_duel_reward", GHOST_DUEL_COIN_REWARD))

## Applies the (win-only) ghost-duel coin reward exactly once, then restores the
## world — mirrors `_on_duel_won`/`_on_duel_lost` structurally. No card drops, no
## enemy-defeat bookkeeping, no rating change (see `enter_ghost_duel` doc comment).
func _on_ghost_duel_ended(did_win: bool) -> void:
	if _sm.current_state() != State.BATTLE:
		return
	if did_win:
		_sm.save_manager.add_coins(GHOST_DUEL_COIN_REWARD)
		_sm._bump_session_stat("coins_earned", GHOST_DUEL_COIN_REWARD)
	_sm._finish_battle(false)
	_sm._restore_world()

## Enters a networked PvP battle from the shared co-op world. The WorldScene is
## detached but kept alive (like a normal battle) so both peers return to the SAME
## madrian session afterwards; the NetworkManager co-op session is NOT torn down.
## local_player_idx: 0 on the host (authority), 1 on the client. opponent_token
## (GID-102 / TID-372) lets the host verify a later reconnect actually claims to be
## this same opponent — empty when unknown (e.g. an already-resumed duel re-entering
## via resume_pvp_battle, which doesn't have a token to pass; verification then
## falls back to accepting any reconnect, the documented same-LAN trust model).
## ranked (GID-102 / TID-373): when true, the duel's outcome moves both combatants'
## persistent ELO rating (TID-370) — both peers must pass the same value (set from the
## challenge handshake, mirroring how ante_coins is agreed before either side calls this).
## local_deck_override (GID-104 / TID-385, draft duels): when non-empty, the
## listen-server host builds its own players[0] deck from these transient instance
## dicts instead of SaveManager.get_deck_instances() — a drafted deck must never
## read (or write) the persisted collection. Empty = normal collection deck.
func enter_pvp_battle(local_player_idx: int, opponent_deck: Array, ante_coins: int = 0,
		opponent_token: String = "", ranked: bool = false,
		local_deck_override: Array = []) -> void:
	if _sm.current_state() != State.WORLD:
		return
	var captured_idx: int = local_player_idx
	var captured_deck: Array = opponent_deck
	var captured_ante: int = ante_coins
	var captured_token: String = opponent_token
	var captured_ranked: bool = ranked
	var captured_local_deck: Array = local_deck_override
	_enter_pvp_battle(func(b: Node) -> void:
		b.set("_local_player_idx", captured_idx)
		b.set("pvp_opponent_deck", captured_deck)
		b.set("pvp_ante_coins", captured_ante)
		b.set("pvp_opponent_token", captured_token)
		b.set("pvp_ranked", captured_ranked)
		b.set("pvp_local_deck_override", captured_local_deck))

## Resumes a PvP duel after a reconnect (GID-102 / TID-372). Called from
## MultiplayerLobbyScene._on_connection_succeeded when NetworkManager.has_pvp_resume()
## instead of the normal enter_map_coop landing. Unlike enter_pvp_battle, this is
## reachable with no current WorldScene (the reconnecting client is coming cold from
## the lobby/menu, not from an active shared world) — so it first lands in the shared
## map (giving enter_pvp_battle a real "_saved_world_scene" to detach/restore later)
## and waits for that transition to actually finish before stacking the battle
## transition on top (TransitionManager.transition() is fire-and-forget async).
## local_deck_override (GID-115 / TID-434, fixes BID-035): threaded straight through to
## enter_pvp_battle so a resumed draft duel never silently falls back to the persisted
## collection — see NetworkManager.set_pvp_resume's doc comment for why this is
## currently inert (only client idx 1 ever resumes, and only the duel-host side
## consumes the override) but kept symmetric for correctness.
func resume_pvp_battle(local_player_idx: int, opponent_deck: Array, ante_coins: int,
		local_deck_override: Array = []) -> void:
	_sm.enter_map_coop("madrian")
	while _sm.current_state() != State.WORLD:
		await get_tree().process_frame
	enter_pvp_battle(local_player_idx, opponent_deck, ante_coins, "", false, local_deck_override)

## Dedicated-server variant of enter_pvp_battle (GID-097 / TID-353).
## The server is the headless referee: _local_player_idx = -1 (no local player),
## both decks come from the clients, and _pvp_peer_to_idx maps peer_id → player_idx.
## token_a/token_b (GID-102 / TID-372) are the combatants' identity tokens, used to
## verify a later reconnect; empty strings fall back to accepting any reconnect.
func enter_pvp_referee(deck_a: Array, deck_b: Array, peer_a_id: int, peer_b_id: int, token_a: String = "",
		token_b: String = "") -> void:
	if _sm.current_state() != State.WORLD:
		return
	_enter_pvp_battle(func(b: Node) -> void:
		b.set("_local_player_idx", -1)       # no local player
		b.set("pvp_player0_deck", deck_a)
		b.set("pvp_player1_deck", deck_b)
		b.set("_pvp_peer_to_idx", {peer_a_id: 0, peer_b_id: 1})
		b.set("_pvp_idx_to_token", {0: token_a, 1: token_b}))

## Enters a PvP battle as a read-only spectator (GID-101 / TID-367). The spectator
## renders the board (from a neutral perspective, local_player_idx = -1) but sends
## no intents. The BattleScene's _pvp_spectating flag blocks all input gates.
func enter_pvp_spectator() -> void:
	if _sm.current_state() != State.WORLD:
		return
	_enter_pvp_battle(func(b: Node) -> void:
		b.set("_local_player_idx", 0)   # neutral — same as host perspective
		b.set("_pvp_spectating", true))

## Resolve a connected peer's GID-095 session token, whether WorldScene is currently
## live in the tree or detached during an active PvP battle (GID-104 / TID-387:
## spectator-wager escrow/settlement runs from BattleScene, which is exactly when
## WorldScene is detached — see enter_pvp_battle/enter_pvp_spectator above). Looks at
## the live scene first, falling back to the saved detached instance. Returns "" if
## unknown (e.g. a peer whose identity handshake hasn't completed yet).
func session_token_for_peer(peer_id: int) -> String:
	var ws: Node = get_tree().current_scene if _sm.current_state() == State.WORLD else _sm._saved_world_scene
	if ws == null or not ws.has_method("get_session_token_for_peer"):
		return ""
	return str(ws.get_session_token_for_peer(peer_id))

## Enters a co-op PvE battle from the shared world (GID-099).
## All N allies fight a single shared boss together. The authority (host or dedicated
## server) owns the canonical GameState; each client sends intents and renders the
## mirror. local_ally_idx is 0 for the host, 1..N-1 for each additional ally client.
## all_ally_decks is an Array of N per-ally deck Arrays, indexed by ally_idx; only
## the authority uses all N. Each inner Array is either owned card instances
## (Array[Dictionary], e.g. siege's per-peer decks) or plain card-id Strings (e.g.
## the co-op Endless Spire's shared draft deck, TID-391 — BattleScene's
## _build_coop_pve_state branches on element type).
## enemy_data is the boss enemy_data dict (same shape as NPC-battle enemy_data).
func enter_coop_pve_battle(local_ally_idx: int, all_ally_decks: Array, enemy_data: Dictionary) -> void:
	if _sm.current_state() != State.WORLD:
		return
	_coop_pve_enemy_type = str(enemy_data.get("enemy_type", ""))
	var captured_idx: int = local_ally_idx
	var captured_decks: Array = all_ally_decks
	var captured_edata: Dictionary = enemy_data
	var setup := func(b: Node) -> void:
		b.set("_coop_pve", true)
		b.set("_local_player_idx", captured_idx)
		b.set("_coop_ally_decks", captured_decks)
		b.enemy_data = captured_edata
	_sm._enter_battle(setup, true)

## Enters a 2v2 team PvP duel from the shared world (GID-102 / TID-371). The host is
## always players[0]/team 0 in the canonical GameState; local_player_idx is the local
## participant's absolute index (0..3). team_assignments[i] is the team (0/1) for
## absolute index i. all_decks is an Array of 4 Arrays[Dictionary] (deck instances per
## absolute index); only the authority uses all 4, set by the host from the connected
## peers' relayed decks (see WorldScene's "Team Duel" trigger).
func enter_team_battle(local_player_idx: int, team_assignments: Array, all_decks: Array) -> void:
	if _sm.current_state() != State.WORLD:
		return
	var captured_idx: int = local_player_idx
	var captured_teams: Array = team_assignments
	var captured_decks: Array = all_decks
	var setup := func(b: Node) -> void:
		b.set("_team_pvp", true)
		b.set("_local_player_idx", captured_idx)
		b.set("_team_assignments", captured_teams)
		b.set("_team_decks", captured_decks)
		b.enemy_data = PVP_ENEMY_DATA.duplicate(true)
	_sm._enter_battle(setup, true)

## Team PvP duel finished (2v2). Restore the shared world (duel-style: no card/coin
## rewards in v1, like unwagered 2-player PvP). Mirrors _on_coop_pve_battle_ended.
func _on_team_battle_ended(_did_win: bool) -> void:
	if _sm.current_state() != State.BATTLE:
		return
	_sm._dismiss_battle_overlay()
	if _sm._saved_world_scene != null and NetworkManager.is_active():
		_sm._restore_world()
	else:
		if _sm._saved_world_scene != null:
			_sm._saved_world_scene.queue_free()
			_sm._saved_world_scene = null
		_sm.go_to_menu_direct()

## Co-op PvE battle finished (all allies vs shared boss). Restore the shared world.
## Mirrors _on_pvp_battle_ended but emitted by GameBus.coop_pve_battle_ended.
func _on_coop_pve_battle_ended(did_win: bool) -> void:
	if _sm.current_state() != State.BATTLE:
		return
	if did_win:
		if not _coop_pve_enemy_type.is_empty():
			_sm.save_manager.increment_progress("enemies_defeated", 1)
		_sm.save_manager.increment_progress("battles_won", 1)
		_sm.save_manager.check_deck_achievements(_sm.save_manager.player_deck)
	_coop_pve_enemy_type = ""
	_sm._dismiss_battle_overlay()
	if _sm._saved_world_scene != null and NetworkManager.is_active():
		_sm._restore_world()
	else:
		if _sm._saved_world_scene != null:
			_sm._saved_world_scene.queue_free()
			_sm._saved_world_scene = null
		_sm.go_to_menu_direct()

## PvP battle finished (duel-style: no cards/coins/defeat tracking). Restore the
## shared co-op world. If the session ended (host vanished for a client), the
## world can't be restored → go to the menu cleanly.
func _on_pvp_battle_ended(_did_win: bool) -> void:
	if _sm.current_state() != State.BATTLE:
		return
	_sm._dismiss_battle_overlay()
	if _sm._saved_world_scene != null and NetworkManager.is_active():
		_sm._restore_world()
	elif NetworkManager.is_dedicated_server():
		# Server restores its world scene — no menu to fall back to.
		if _sm._saved_world_scene != null:
			get_tree().root.add_child(_sm._saved_world_scene)
			get_tree().current_scene = _sm._saved_world_scene
			_sm._transition_to(State.WORLD)
	else:
		# No co-op session / world to return to.
		if _sm._saved_world_scene != null:
			_sm._saved_world_scene.queue_free()
			_sm._saved_world_scene = null
		_sm.go_to_menu_direct()

## A PvP-flavoured `_enter_battle`: marks the scene `_pvp` and hands it the inert
## PVP_ENEMY_DATA after `configure` runs.
func _enter_pvp_battle(configure: Callable) -> void:
	var setup := func(b: Node) -> void:
		b.set("_pvp", true)
		configure.call(b)
		b.enemy_data = PVP_ENEMY_DATA.duplicate(true)
	_sm._enter_battle(setup, true)

