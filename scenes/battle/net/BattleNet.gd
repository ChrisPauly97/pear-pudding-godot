## The networked-battle surface of BattleScene: PvP duels (client intents,
## host authority, state mirroring, reconnect), duel spectating and spectator
## wagers, the co-op PvE joint battle, and team duels.
##
## A child node of BattleScene, registered with BattleNetSync as an RPC handler
## target so the `_on_*` entry points below are reached exactly as they were
## when they lived in BattleScene itself. Everything battle-side is reached via
## `_battle`. See CLAUDE.md "WorldScene co-op modules" — same arrangement.
extends Node

## The BattleScene that owns this module. The game state, the card view builder,
## the FX layer and the battle configuration all live there and are reached
## through this back-reference; only the networked surface lives here.
var _battle: Node = null

const BattleNetProtocol = preload("res://game_logic/net/BattleNetProtocol.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const WagerSync = preload("res://game_logic/net/WagerSync.gd")
const _BattleNetSyncScript = preload("res://scenes/battle/BattleNetSync.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _CoopBattleScaling = preload("res://game_logic/battle/CoopBattleScaling.gd")

var _coop_ended: bool = false  # guard so the result fires once
var _coop_peer_to_idx: Dictionary = {}
var _coop_sync_retry_accum: float = 0.0
# BID-031: authority-only clock + party-scaled difficulty for the coop_clears
# leaderboard's richer {boss_tier, clear_seconds} value. Set once in
# _build_coop_pve_state() (host-only); a client never computes these, it only
# ever reads them back out of the reward_payload the host RPCs it.
var _coop_battle_started_at_msec: int = 0
var _coop_boss_tier: int = 1
var _pvp_reconnect_timer: Timer = null
var _pvp_sync_retry_accum: float = 0.0
var _spectators: Array[int] = []      # host only: peer_ids watching this duel
var _state_seq: int = 0              # host: monotonic broadcast counter
var _team_arena_built: bool = false
var _team_ended: bool = false  # guard so the result fires once
var _team_panels: Array[Control] = []
var _team_peer_to_idx: Dictionary = {}  # peer_id (int) → player_idx (int), authority only
var _team_sync_retry_accum: float = 0.0
var _wager_amount: int = 10
var _wager_amount_label: Label = null
var _wager_bets: Dictionary = {}      # authority: token -> {side, amount, peer_id}
var _wager_minus_btn: Button = null
var _wager_panel: Control = null
var _wager_place_btn: Button = null
var _wager_placed_amount: int = 0
var _wager_placed_side: String = ""   # last host-accepted bet ("" = none)
var _wager_plus_btn: Button = null
var _wager_result_text: String = ""   # settlement line shown on the result overlay
var _wager_side: String = "a"
var _wager_side_a_btn: Button = null
var _wager_side_b_btn: Button = null
var _wager_status_label: Label = null
var _wagers_settled: bool = false     # authority: one-shot settlement guard

## The opening every networked battle mode shares: a fresh canonical GameState
## bound to the resolver, and the BattleNetSync relay node.
##
## The relay is parented to the battle scene, never to this module — its node
## path is the RPC address both peers resolve, so reparenting it would silently
## break every call. SpellEffectResolver.setup() only stores the state reference,
## so callers are free to configure the state after this returns.
func _build_net_state() -> void:
	_battle._state = GameState.new()
	_battle._resolver.setup(_battle._state)
	_battle._wire_gamebus_emitter()
	_battle._net = _BattleNetSyncScript.new()
	_battle._net.name = "BattleNetSync"
	_battle.add_child(_battle._net)
	_battle._net.battle_scene = _battle
	_battle._net.call("register_handler", self)

func _setup_pvp_battle() -> void:
	_build_net_state()
	_battle._state.ranked = _battle.pvp_ranked
	if _battle._pvp_spectating:
		# Spectator: send request_spectate so the host registers us and sends the state.
		_connect_pvp_net_signals()
		_battle._net.rpc_id(1, "request_spectate")
		# Spectator wagers (GID-104 / TID-387): bet panel over the read-only view.
		_build_wager_panel()
		return
	_connect_pvp_net_signals()
	if _battle._is_pvp_host():
		_build_pvp_decks()
		_battle._state.players[0].start_turn(1)
		# Initial state is broadcast by the _check_game_over() call at the end of
		# _ready (host branch), so the client populates from the mirror.
	elif _battle._local_player_idx >= 0:
		# Client (GID-102 / TID-372): remember enough to re-enter this exact duel if the
		# connection drops — MultiplayerLobbyScene checks this on the next
		# connection_succeeded instead of landing in the normal shared world. Only the
		# client reconnects in this slice (a dropped host/referee still ends the duel
		# for everyone, per the existing session_ended semantics).
		NetworkManager.set_pvp_resume(_battle._local_player_idx, _battle.pvp_opponent_deck, _battle.pvp_ante_coins,
			_battle.pvp_local_deck_override)
		# Announce once so a host/referee with a pending grace window (this peer
		# reconnecting after a drop) can verify + resume immediately; harmless no-op
		# on a fresh (non-reconnect) duel start since no grace window is pending.
		_battle._net.rpc_id(1, "announce_reconnect", MpProfile.get_token())


## Client/spectator: keep asking the host for the initial state until the first
## mirror lands (handles the race where the host broadcasts before this scene exists).

## Per-frame net tick. Driven by BattleScene._process rather than being a
## _process of its own: BattleScene owns the battle's frame tick, and the PvP
## smoke tests advance a detached battle by calling battle._process(delta)
## directly — a module-private _process would silently never run for them.
func tick(delta: float) -> void:
	if _battle._coop_pve:
		_process_coop_sync(delta)
		return
	if _battle._team_pvp:
		_process_team_sync(delta)
		return
	if not (_battle._is_pvp_client() or _battle._pvp_spectating) or _battle._last_applied_seq >= 0 or _battle._net == null:
		return
	_pvp_sync_retry_accum += delta
	if _pvp_sync_retry_accum >= 0.4:
		_pvp_sync_retry_accum = 0.0
		if _battle._pvp_spectating:
			_battle._net.rpc_id(1, "request_spectate")  # re-send until host registers us
		else:
			_battle._net.rpc_id(1, "request_sync")

## Host: a client asked for the current state — send it.

func _on_pvp_sync_request() -> void:
	if _battle._is_pvp_host():
		_broadcast_state()

## Authority: build both player decks. In listen-server mode players[0] uses the
## local save and players[1] uses pvp_opponent_deck; in dedicated-server referee
## mode both decks come from the clients (pvp_player0_deck / pvp_player1_deck).

func _build_pvp_decks() -> void:
	var fallback: Array[String] = [
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
	]
	if _battle._local_player_idx < 0:
		# Dedicated-server referee: both decks supplied by clients.
		var insts0: Array[Dictionary] = []
		for inst in _battle.pvp_player0_deck:
			if inst is Dictionary:
				insts0.append(inst)
		if insts0.size() > 0:
			_battle._state.players[0].build_deck_from_instances(insts0)
		else:
			_battle._state.players[0].build_deck(fallback)
		var insts1: Array[Dictionary] = []
		for inst in _battle.pvp_player1_deck:
			if inst is Dictionary:
				insts1.append(inst)
		if insts1.size() > 0:
			_battle._state.players[1].build_deck_from_instances(insts1)
		else:
			_battle._state.players[1].build_deck(fallback)
	else:
		# Listen-server host: players[0] is local, players[1] from the challenged peer.
		# Draft duel (GID-104 / TID-385): a non-empty pvp_local_deck_override replaces
		# the persisted collection entirely — drafted decks never touch SaveManager.
		var my_insts: Array[Dictionary] = []
		if _battle.pvp_local_deck_override.size() > 0:
			for inst in _battle.pvp_local_deck_override:
				if inst is Dictionary:
					my_insts.append(inst)
		else:
			my_insts = SceneManager.save_manager.get_deck_instances()
		if my_insts.size() > 0:
			_battle._state.players[0].build_deck_from_instances(my_insts)
		else:
			_battle._state.players[0].build_deck(fallback)
		var opp_insts: Array[Dictionary] = []
		for inst in _battle.pvp_opponent_deck:
			if inst is Dictionary:
				opp_insts.append(inst)
		if opp_insts.size() > 0:
			_battle._state.players[1].build_deck_from_instances(opp_insts)
		else:
			_battle._state.players[1].build_deck(fallback)
	_battle._state.players[0].draw_opening_hand(4)
	_battle._state.players[1].draw_opening_hand(4)

func _connect_pvp_net_signals() -> void:
	if NetworkManager.peer_disconnected.is_connected(_on_pvp_peer_disconnected):
		return
	NetworkManager.peer_disconnected.connect(_on_pvp_peer_disconnected)
	NetworkManager.session_ended.connect(_on_pvp_session_ended)

func _disconnect_pvp_net_signals() -> void:
	if NetworkManager.peer_disconnected.is_connected(_on_pvp_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_pvp_peer_disconnected)
	if NetworkManager.session_ended.is_connected(_on_pvp_session_ended):
		NetworkManager.session_ended.disconnect(_on_pvp_session_ended)

## Client → host: send one intent (host is network id 1).

func _broadcast_state() -> void:
	if not _battle._is_pvp_host() or _battle._net == null:
		return
	_state_seq += 1
	var payload: Dictionary = BattleNetProtocol.encode_state(_battle._state.to_dict(), _state_seq)
	_battle._net.rpc("sync_state", payload)
	for spec_id in _spectators:
		_battle._net.rpc_id(spec_id, "sync_state", payload)

## Client/spectator: receive and apply an authoritative state mirror.

## Decodes an authority state broadcast and adopts it, unless the packet is
## malformed or is a mirror we have already applied (sequence numbers only ever
## move forward, and a late duplicate would roll the board backwards). Returns
## whether the mirror was adopted.
func _accept_state_mirror(payload: Dictionary) -> bool:
	var decoded: Dictionary = BattleNetProtocol.decode_state(payload)
	if not bool(decoded["valid"]):
		return false
	var seq: int = int(decoded["seq"])
	if seq <= _battle._last_applied_seq:
		return false
	_battle._last_applied_seq = seq
	_battle._pvp_pending = false
	_adopt_mirrored_state(decoded["state"])
	return true

func _on_pvp_state(payload: Dictionary) -> void:
	if not (_battle._is_pvp_client() or _battle._pvp_spectating):
		return
	if not _accept_state_mirror(payload):
		return
	# Spectator wagers (GID-104 / TID-387): each mirror carries turn_number, so the
	# cutoff ("Bets Closed") is evaluated locally on every state update.
	if _battle._pvp_spectating:
		_update_wager_panel()

## Replaces the local GameState with an authority mirror and re-points every
## helper that caches a GameState reference (GID-040 pattern). from_dict builds
## a brand-new GameState, so its turn_ended signal must be reconnected too — the
## connection made in _ready was to the state this one replaces.

func _adopt_mirrored_state(state_dict: Dictionary) -> void:
	_battle._state = GameState.new()
	_battle._state.from_dict(state_dict)
	_battle._wire_gamebus_emitter()
	_battle._bump_card_next_id(_battle._state)
	if not _battle._state.turn_ended.is_connected(_battle._on_turn_ended):
		_battle._state.turn_ended.connect(_battle._on_turn_ended)
	_battle._resolver.setup(_battle._state)
	_battle._fx.set_game_state(_battle._state)
	_battle._view.set_battle_state(_battle._state, _battle.enemy_data)
	_battle._refresh_all()
	_battle._refresh_potion_button()

## Authority: validate + apply a client intent, then re-render (broadcast happens
## in _check_game_over). In referee mode both players send intents; in
## listen-server mode only the single client (player 1) does.

func _on_pvp_intent(sender: int, payload: Dictionary) -> void:
	if not _battle._is_pvp_host():
		return
	var intent: Dictionary = BattleNetProtocol.decode_intent(payload)
	var t: String = str(intent["type"])
	if t == "":
		return
	# Determine which player index the sender maps to.
	# Listen-server: the only remote sender is always player 1.
	# Dedicated-server referee: look up the per-peer mapping.
	var acting_idx: int = 1
	if _battle._local_player_idx < 0:
		acting_idx = int(_battle._pvp_peer_to_idx.get(sender, -1))
		if acting_idx < 0:
			return  # unknown sender — ignore
	if t == BattleNetProtocol.INTENT_SURRENDER:
		_apply_remote_surrender(acting_idx)
		return
	if _battle._state.current_player_idx != acting_idx:
		_broadcast_state()
		return
	var changed: bool = _apply_remote_intent(intent, acting_idx)
	if changed:
		_battle._refresh_all()
		_battle._check_game_over()
	else:
		_broadcast_state()  # reject → re-sync the client

## Resolves the "opponent index" an authority should use for a given remote intent.
##
## 2-player PvP: 1 - player_idx (unchanged).
##
## Co-op PvE (GID-099): always the boss (last player slot) — fixes a pre-existing bug
## (discovered while generalizing this for team PvP, see BID-026): the old unconditional
## `1 - player_idx` only happens to equal the boss index for a 2-player-shaped state;
## for any ally CLIENT (idx 1..N-1) relaying an ATTACK intent, `1 - player_idx` resolved
## to an arbitrary ally index (and, via GDScript's negative-index wraparound, sometimes a
## different ally entirely) instead of the boss, so a relayed ally attack could damage/
## remove against the wrong ally's board. Ally indices vs the boss only ever face one
## opponent (the boss), so this is unconditional, not target_pidx-dependent.
##
## Team PvP (GID-102 / TID-371): the intent's target_pidx when it names a living
## enemy-team member (the attacker's manually focused target, sent by the client's
## _opp_idx()), else the auto-picked lowest-HP enemy-team member (_state.opponent_idx(),
## valid here since callers already verified current_player_idx == player_idx before
## invoking _apply_remote_intent).

func _resolve_intent_opp_idx(intent: Dictionary, player_idx: int) -> int:
	if _battle._coop_pve:
		return _battle._state.players.size() - 1
	if not _battle._team_pvp:
		return 1 - player_idx
	var tp: int = int(intent.get("target_pidx", -1))
	if tp >= 0 and tp < _battle._state.players.size() and tp < _battle._state.player_teams.size() \
			and player_idx < _battle._state.player_teams.size() \
			and _battle._state.player_teams[tp] != _battle._state.player_teams[player_idx] \
			and _battle._state.players[tp].hero.is_alive():
		return tp
	return _battle._state.opponent_idx()

## Authority: apply a validated remote-player intent to the canonical state.
## `player_idx` is 1 in listen-server mode (the single client); either 0 or 1 in
## referee mode (determined by _pvp_peer_to_idx lookup in _on_pvp_intent).
## Returns true if the state changed (and should be re-broadcast).

func _apply_remote_intent(intent: Dictionary, player_idx: int) -> bool:
	var t: String = str(intent["type"])
	var p1: PlayerState = _battle._state.players[player_idx]
	var opp_idx: int = _resolve_intent_opp_idx(intent, player_idx)
	match t:
		BattleNetProtocol.INTENT_PLAY_CARD_AT_SLOT:
			var hi: int = int(intent["hand_index"])
			var slot_idx: int = int(intent["slot_idx"])
			if hi < 0 or hi >= p1.hand.size():
				return false
			var card: CardInstance = p1.hand[hi]
			if card.card_class == "spell":
				return false
			if slot_idx < 0 or slot_idx >= 5 or p1.board.slots[slot_idx] != null:
				return false
			if not _battle._do_play_card_at_slot(card, player_idx, slot_idx):
				return false
			if card.emergence_effect != "":
				_battle._resolver.resolve_emergence(card, player_idx)
			else:
				_battle._apply_weather_to_summoned(card, player_idx)
			return true
		BattleNetProtocol.INTENT_PLAY_SPELL:
			var hi2: int = int(intent["hand_index"])
			if hi2 < 0 or hi2 >= p1.hand.size():
				return false
			var spell: CardInstance = p1.hand[hi2]
			if spell.card_class != "spell" or not p1.can_play(spell):
				return false
			var tgt: Dictionary = intent["target"]
			if SpellEffectResolver.SLOT_TARGETED_EFFECTS.has(spell.spell_effect):
				var s_slot: int = int(tgt.get("slot", -1))
				if not _battle._do_play_card(spell, player_idx):
					return false
				match spell.spell_effect:
					"bless_slot":
						p1.board.enhance_slot(s_slot, "atk_bonus", spell.spell_power)
					"ward_slot":
						p1.board.enhance_slot(s_slot, "shroud", 1)
				return true
			var resolver_target: Dictionary = _pvp_resolver_target(tgt)
			if not _battle._do_play_card(spell, player_idx):
				return false
			_battle._resolver.resolve_spell(spell, player_idx, resolver_target)
			return true
		BattleNetProtocol.INTENT_ATTACK:
			var a_slot: int = int(intent["attacker_slot"])
			var t_slot: int = int(intent["target_slot"])
			if a_slot < 0 or a_slot >= 5:
				return false
			var attacker: CardInstance = p1.board.slots[a_slot]
			if attacker == null or not attacker.can_attack():
				return false
			var target: CardInstance = null
			if t_slot != BattleNetProtocol.TARGET_HERO:
				if t_slot < 0 or t_slot >= 5:
					return false
				target = _battle._state.players[opp_idx].board.slots[t_slot]
				if target == null:
					return false
				# Ward gating: if any enemy minion has Ward, only Ward minions are valid.
				var valid: Array[CardInstance] = _battle._view.get_ward_valid_targets(_battle._state.players[opp_idx].board.get_cards())
				if not valid.has(target):
					return false
			else:
				# Cannot attack hero while a Ward minion stands.
				for ec: CardInstance in _battle._state.players[opp_idx].board.get_cards():
					if ec.keywords.has(Keywords.WARD):
						return false
			_resolve_remote_attack(attacker, target, player_idx, opp_idx)
			return true
		BattleNetProtocol.INTENT_HERO_POWER:
			_battle._apply_hero_power_effect(player_idx, str(intent["effect_type"]), int(intent["effect_value"]))
			return true
		BattleNetProtocol.INTENT_POTION:
			_apply_potion_state_effect(player_idx, str(intent["potion_id"]))
			return true
		BattleNetProtocol.INTENT_END_TURN:
			_battle._state.end_turn()
			return true
	return false

## Translates a wire target dict ({hero}/{hero,pidx}/{side,slot}/{pidx}) into a resolver
## target. "hero" is checked before the plain "pidx" branch: a team-battle hero target
## carries BOTH keys ({"hero": true, "pidx": N} — which enemy hero), distinct from the
## ally-targeting payload which carries "pidx" alone (GID-100).

func _pvp_resolver_target(tgt: Dictionary) -> Dictionary:
	if tgt.is_empty():
		return {}
	if bool(tgt.get("hero", false)):
		var out: Dictionary = {"type": "hero"}
		if tgt.has("pidx"):
			out["pidx"] = int(tgt["pidx"])
		return out
	if tgt.has("pidx"):
		return {"pidx": int(tgt["pidx"])}
	if tgt.has("side") and tgt.has("slot"):
		var side: int = int(tgt["side"])
		var slot: int = int(tgt["slot"])
		if side >= 0 and side < _battle._state.players.size() and slot >= 0 and slot < 5:
			var c: CardInstance = _battle._state.players[side].board.slots[slot]
			if c != null:
				return {"type": "minion", "card": c}
	return {}

## State-only attack resolution (no side-specific FX) for relayed/remote attacks.
## defender_pid is resolved by the caller via _resolve_intent_opp_idx (handles 2-player
## PvP, co-op-PvE-vs-boss, and team-PvP focus/auto-target uniformly).

func _resolve_remote_attack(attacker: CardInstance, target: CardInstance, attacker_pid: int, defender_pid: int) -> void:
	var attacker_dmg: int = BattlefieldRules.modify_damage(attacker.attack, _battle._state.battlefield_biome)
	if target != null:
		var target_dmg: int = BattlefieldRules.modify_damage(target.attack, _battle._state.battlefield_biome)
		target.take_damage(attacker_dmg)
		attacker.take_damage(target_dmg)
		attacker.attack_count -= 1
		if not target.is_alive():
			attacker.battle_kills += 1
			_battle._state.players[defender_pid].board.remove_card(target)
			_battle._state.players[defender_pid].discard.append(target)
		GameBus.card_attacked.emit(attacker.template_id, target.template_id)
	else:
		var hero: HeroState = _battle._state.players[defender_pid].hero
		hero.take_damage(attacker_dmg)
		attacker.take_damage(BattlefieldRules.modify_damage(hero.attack, _battle._state.battlefield_biome))
		attacker.attack_count -= 1
		GameBus.card_attacked.emit(attacker.template_id, "hero")
	if not attacker.is_alive():
		_battle._state.players[attacker_pid].board.remove_card(attacker)
		_battle._state.players[attacker_pid].discard.append(attacker)

## Applies a hero-power effect to player_idx. Shared by the local host power and
## the relayed client power (host doesn't know the client's skill, so the effect
## is carried in the intent).

func _apply_potion_state_effect(player_idx: int, potion_id: String) -> void:
	var player: PlayerState = _battle._state.players[player_idx]
	match potion_id:
		"healing_draught":
			player.hero.health = mini(player.hero.health + 8, player.hero.max_health)
		"clarity_brew":
			player.draw_card()
			player.draw_card()
		"ember_tonic":
			player.hero.mana = mini(player.hero.mana + 1, player.hero.max_mana)

# ── Client intent builders ────────────────────────────────────────────────────

## Computes a wire target dict for a chosen target card (any board) or hero.

func _pvp_target_dict_for_card(card: CardInstance) -> Dictionary:
	var my_slot: int = _battle._state.players[_battle._my_idx()].board.slots.find(card)
	if my_slot != -1:
		return {"side": _battle._my_idx(), "slot": my_slot}
	var opp_slot: int = _battle._state.players[_battle._opp_idx()].board.slots.find(card)
	if opp_slot != -1:
		return {"side": _battle._opp_idx(), "slot": opp_slot}
	return {}

# ── PvP end-of-battle (host detect + sync) ────────────────────────────────────

## Routed from _check_game_over when _pvp. Host detects the winner, broadcasts
## the final state + pvp_ended, and shows its own overlay. Otherwise (host, not
## over) it pushes the latest state to the client.

func _pvp_check_game_over() -> void:
	if not _battle._is_pvp_host():
		return
	if _battle._state.is_game_over():
		if _battle._pvp_ended:
			return
		_battle._pvp_ended = true
		var w: int = _battle._state.winner()
		_broadcast_state()
		# Settle spectator wagers BEFORE the pvp_ended broadcast so the settlement
		# RPC (same reliable channel) lands before each spectator's result overlay.
		_settle_spectator_wagers(WagerSync.SIDE_A if w == 0 else WagerSync.SIDE_B)
		if _battle._net != null:
			_battle._net.rpc("pvp_ended", {"winner_idx": w, "forfeit": false, "ante_coins": _battle.pvp_ante_coins})
			for spec_id in _spectators:
				_battle._net.rpc_id(spec_id, "pvp_ended", {"winner_idx": w, "forfeit": false, "ante_coins": 0})
		# Referee mode (_local_player_idx < 0): _finish_pvp's did_win bool is always
		# false here (there is no "local player" to compare w against), so a referee
		# (e.g. a GID-104 tournament host arbitrating a match it isn't playing in)
		# needs the real winner via a dedicated signal instead.
		if _battle._local_player_idx < 0:
			GameBus.pvp_referee_match_ended.emit(w)
		_finish_pvp(w == _battle._local_player_idx)
		return
	_broadcast_state()

## Client/spectator: the host says the battle is over. Show the matching overlay.

func _on_pvp_ended(payload: Dictionary) -> void:
	if not (_battle._is_pvp_client() or _battle._pvp_spectating) or _battle._pvp_ended:
		return
	_battle._pvp_ended = true
	var w: int = int(payload.get("winner_idx", _battle._opp_idx()))
	_battle.pvp_ante_coins = int(payload.get("ante_coins", 0))
	_finish_pvp(w == _battle._local_player_idx)

## Host/referee: player_idx surrenders → the other player wins.

func _apply_remote_surrender(player_idx: int) -> void:
	if _battle._pvp_ended:
		return
	_battle._pvp_ended = true
	var winner_idx: int = 1 - player_idx
	_battle._state.players[player_idx].hero.health = 0
	_broadcast_state()
	# A surrender is a clean win for the other side — spectator bets pay out normally.
	_settle_spectator_wagers(WagerSync.SIDE_A if winner_idx == 0 else WagerSync.SIDE_B)
	if _battle._net != null:
		_battle._net.rpc("pvp_ended", {"winner_idx": winner_idx, "forfeit": true, "ante_coins": _battle.pvp_ante_coins})
		for spec_id in _spectators:
			_battle._net.rpc_id(spec_id, "pvp_ended", {"winner_idx": winner_idx, "forfeit": true, "ante_coins": 0})
	# See the matching comment in _pvp_check_game_over — a referee has no local
	# player, so _finish_pvp's did_win bool can't carry the real winner.
	if _battle._local_player_idx < 0:
		GameBus.pvp_referee_match_ended.emit(winner_idx)
	_finish_pvp(_battle._local_player_idx >= 0 and winner_idx == _battle._local_player_idx)

## Local surrender request (from the pause menu Flee). Host ends immediately;
## client tells the host, which marks it the loser and ends for both.
## Referee (_local_player_idx < 0) has no local player — nothing to do.

func _pvp_surrender() -> void:
	if _battle._pvp_ended or _battle._local_player_idx < 0:
		return
	if _battle._is_pvp_host():
		_battle._pvp_ended = true
		_battle._state.players[_battle._local_player_idx].hero.health = 0
		_broadcast_state()
		# Host surrender is a clean win for the other side — bets pay out normally.
		_settle_spectator_wagers(WagerSync.SIDE_A if _battle._local_player_idx == 1 else WagerSync.SIDE_B)
		if _battle._net != null:
			_battle._net.rpc("pvp_ended", {"winner_idx": 1 - _battle._local_player_idx, "forfeit": true, "ante_coins": _battle.pvp_ante_coins})
			for spec_id in _spectators:
				_battle._net.rpc_id(spec_id, "pvp_ended", {"winner_idx": 1 - _battle._local_player_idx, "forfeit": true, "ante_coins": 0})
		_finish_pvp(false)
	else:
		_battle._send_intent(BattleNetProtocol.encode_surrender())

## A combatant's peer disconnected. 2-player PvP (GID-102 / TID-372): starts a grace
## window instead of an immediate forfeit, so a dropped client can reconnect via
## announce_reconnect. Team duels and co-op PvE are untouched (this only fires when
## _pvp is set; their own disconnect handling — currently immediate end — is
## unaffected, out of scope for this slice). Spectator disconnects don't map to a
## combatant idx and are ignored here (no effect on the duel).

func _on_pvp_peer_disconnected(pid: int) -> void:
	if not _battle._pvp or _battle._pvp_ended:
		return
	# Spectator wagers (GID-104 / TID-387): a disconnected SPECTATOR's pending bet is
	# refunded immediately (their stake goes back into their SessionState record; they
	# re-adopt it on reconnect). Runs before the combatant checks below because a
	# spectator pid never maps to a combatant idx.
	_refund_wager_for_peer(pid)
	# Opportunistic fix (TID-387): on a listen server the `idx = 1` fallback below
	# treats ANY disconnected pid as the combatant client — including a spectator,
	# which would start a bogus 45 s grace window and end the duel as a forfeit.
	# A registered spectator leaving must never touch the duel.
	if _spectators.has(pid):
		_spectators.erase(pid)
		return
	if _battle._pvp_reconnect_idx != -1:
		return
	var idx: int = 1 if _battle._local_player_idx >= 0 else int(_battle._pvp_peer_to_idx.get(pid, -1))
	if idx < 0:
		return
	_battle._pvp_reconnect_idx = idx
	if _pvp_reconnect_timer == null:
		_pvp_reconnect_timer = Timer.new()
		_pvp_reconnect_timer.one_shot = true
		_battle.add_child(_pvp_reconnect_timer)
		_pvp_reconnect_timer.timeout.connect(_on_pvp_reconnect_grace_expired)
	_pvp_reconnect_timer.start(_battle._PVP_RECONNECT_GRACE_SECONDS)

## Grace window expired with no reconnect — fall back to the original immediate-forfeit
## behavior (same shape as the pre-TID-372 _on_pvp_peer_disconnected).

func _on_pvp_reconnect_grace_expired() -> void:
	if _battle._pvp_ended or _battle._pvp_reconnect_idx < 0:
		return
	_battle._pvp_ended = true
	_battle._pvp_reconnect_idx = -1
	if _battle._is_pvp_host():
		_broadcast_state()
		# Abandoned match (combatant never came back) — refund every spectator bet
		# rather than paying out on a walkover (GID-104 / TID-387).
		_settle_spectator_wagers(WagerSync.OUTCOME_ABANDONED)
	_finish_pvp(true)

## Authority: a peer announced its identity token (sent once at every duel setup,
## including fresh non-reconnect starts — a no-op there since no grace window is
## pending). When it matches the combatant currently mid-grace-window, cancels the
## timer and resumes by re-broadcasting the live state; the rejoined client's own
## request_sync retry loop also converges on it within ~0.4 s regardless.

func _on_reconnect_announced(sender: int, token: String) -> void:
	if _battle._pvp_reconnect_idx < 0:
		return
	var idx: int = _battle._pvp_reconnect_idx
	var expected_token: String = str(_battle._pvp_idx_to_token.get(idx, "")) if _battle._local_player_idx < 0 else _battle.pvp_opponent_token
	# Same-LAN trust model: a missing recorded token (legacy/edge case) doesn't block
	# resume — refusing a reconnect is worse than a same-LAN false accept.
	if expected_token != "" and token != "" and expected_token != token:
		return
	_battle._pvp_reconnect_idx = -1
	if _pvp_reconnect_timer != null:
		_pvp_reconnect_timer.stop()
	if _battle._local_player_idx < 0:
		# Referee: remap the stale peer id to the same idx (prune the old mapping first).
		for old_pid in _battle._pvp_peer_to_idx.keys():
			if int(_battle._pvp_peer_to_idx[old_pid]) == idx:
				_battle._pvp_peer_to_idx.erase(old_pid)
		_battle._pvp_peer_to_idx[sender] = idx
	# Listen-server needs no peer-id bookkeeping: _broadcast_state() already reaches
	# "all connected peers" and incoming-intent routing is hardcoded idx 1 regardless
	# of the client's current peer id.
	_broadcast_state()

func _on_pvp_session_ended() -> void:
	if not _battle._pvp or _battle._pvp_ended:
		return
	# GID-102 / TID-372: my own connection to the duel just dropped. If I'm a client
	# with a resume record (set at duel setup), don't declare a false "win" and tear
	# the scene down — leave it frozen-but-recoverable so the player can navigate back
	# to the lobby's Rejoin list and reconnect within the host's grace window, which
	# routes straight back here via MultiplayerLobbyScene._on_connection_succeeded.
	if _battle._local_player_idx == 1 and NetworkManager.has_pvp_resume():
		return
	_battle._pvp_ended = true
	# Authority: session tore down mid-duel — refund escrowed spectator bets into
	# SessionState before it closes (no peers left to unicast to; the write is the
	# part that matters, bettors re-adopt their record on the next session).
	_settle_spectator_wagers(WagerSync.OUTCOME_ABANDONED)
	_finish_pvp(true)

## Shows the synced duel-style result overlay and emits the SceneManager
## completion signal once dismissed. Headless referee has no _result_ui —
## emit the signal directly. Spectators dismiss back to world too. Always the
## genuine end of a duel — clears any pending PvP resume record (TID-372).

func _finish_pvp(did_win: bool) -> void:
	NetworkManager.clear_pvp_resume()
	_disconnect_pvp_net_signals()
	# Remove self from spectator list if we are one (cleanup on battle end).
	if _battle._pvp_spectating and _battle._net != null:
		_battle._net.rpc_id(1, "stop_spectate")
	if _battle._result_ui != null:
		# wager_note (TID-387): the spectator's settlement line ("" for combatants —
		# the settlement RPC is sent before pvp_ended on the same reliable channel,
		# so _wager_result_text is already populated when this runs.)
		_battle._result_ui.show_pvp_result(did_win, _battle.pvp_ante_coins if did_win else -_battle.pvp_ante_coins,
			_wager_result_text)
	elif _battle._local_player_idx < 0:
		GameBus.pvp_battle_ended.emit(false)
	elif _battle._pvp_spectating:
		GameBus.pvp_battle_ended.emit(false)


# ── Spectator handlers (GID-101 / TID-367) ───────────────────────────────────

## Host: a peer wants to spectate — add them to the list and send the current state.

func _on_spectate_request(sender: int) -> void:
	if not _battle._is_pvp_host() or _battle._pvp_ended:
		return
	if not _spectators.has(sender):
		_spectators.append(sender)
	if _battle._net != null and _battle._state != null:
		var payload: Dictionary = BattleNetProtocol.encode_state(_battle._state.to_dict(), _state_seq)
		_battle._net.rpc_id(sender, "sync_state", payload)


## Host: a spectator is leaving — remove them from the list.

func _on_stop_spectate(sender: int) -> void:
	_spectators.erase(sender)


## Spectator: receives state mirrors via the same _on_pvp_state path (reused).
## The _pvp_spectating flag ensures _can_local_act() returns false so no input fires.

# ── Spectator wagers (GID-104 / TID-387) ─────────────────────────────────────
# Authority side: escrow + settlement. Spectator side: bet panel + local mirror.
# Everything below is inert in single-player: the panel is only built when
# _pvp_spectating (a co-op-only entry path), and the authority handlers guard on
# NetworkManager.is_active() + _is_pvp_host().

## Authority: a spectator wants to place (or replace) a bet. Validates spectator
## registration (no betting on your own match — combatants are never in
## _spectators, and the referee's _pvp_peer_to_idx is checked explicitly), the
## cutoff turn, and the WagerSync bet caps against the bettor's SessionState
## coins. On accept, the stake moves out of the member record into escrow
## (_wager_bets) immediately — the same direct-SessionStore-write pattern as
## WorldScene._grant_chest_loot_to_token, just in the debit direction.

func _on_wager_bet_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_active() or not _battle._is_pvp_host() or not _battle._pvp or _battle._pvp_ended:
		return
	if _battle._net == null:
		return
	if _battle._pvp_peer_to_idx.has(sender):
		_battle._net.rpc_id(sender, "recv_wager_ack", false, "You cannot bet on your own match.", "", 0, 0)
		return
	if not _spectators.has(sender):
		_battle._net.rpc_id(sender, "recv_wager_ack", false, "Only spectators can bet.", "", 0, 0)
		return
	if _battle._state == null or not WagerSync.is_betting_open(_battle._state.turn_number):
		_battle._net.rpc_id(sender, "recv_wager_ack", false, "Bets are closed.", "", 0, 0)
		return
	var bet: Dictionary = WagerSync.decode_bet(payload)
	var side: String = str(bet.get("side", ""))
	var amount: int = int(bet.get("amount", 0))
	var token: String = SceneManager.session_token_for_peer(sender)
	var st = SessionStore.get_state()
	var rec: Dictionary = {}
	if st != null and token != "":
		rec = st.get_member(token)
	if rec.is_empty():
		_battle._net.rpc_id(sender, "recv_wager_ack", false, "No session record found.", "", 0, 0)
		return
	var coins: int = int(rec.get("coins", 0))
	var existing: int = 0
	if _wager_bets.has(token):
		existing = int((_wager_bets[token] as Dictionary).get("amount", 0))
	if not WagerSync.is_valid_bet(side, amount, coins, existing):
		var cap: int = WagerSync.max_bet(coins + existing)
		_battle._net.rpc_id(sender, "recv_wager_ack", false, "Invalid bet (max %d)." % cap, "", 0, coins)
		return
	# Escrow: credit back any prior stake, deduct the new one, persist.
	rec["coins"] = coins + existing - amount
	st.update_member(token, rec)
	SessionStore.mark_dirty()
	_wager_bets[token] = {"side": side, "amount": amount, "peer_id": sender}
	_battle._net.rpc_id(sender, "recv_wager_ack", true, "", side, amount, int(rec["coins"]))


## Authority: refund a single disconnecting spectator's pending bet — the stake
## goes straight back into their SessionState record (they re-adopt it on
## reconnect). No-op once settlement has run or when the peer holds no bet.

func _refund_wager_for_peer(pid: int) -> void:
	if _wager_bets.is_empty() or _wagers_settled:
		return
	var st = SessionStore.get_state()
	for token in _wager_bets.keys():
		var wbet: Dictionary = _wager_bets[token]
		if int(wbet.get("peer_id", 0)) != pid:
			continue
		_wager_bets.erase(token)
		if st != null:
			var rec: Dictionary = st.get_member(str(token))
			if not rec.is_empty():
				rec["coins"] = int(rec.get("coins", 0)) + int(wbet.get("amount", 0))
				st.update_member(str(token), rec)
				SessionStore.mark_dirty()
		return


## Authority: settle every escrowed bet exactly once. `outcome` is WagerSync.SIDE_A/
## SIDE_B (clean win for that side) or OUTCOME_DRAW/OUTCOME_ABANDONED (refund all).
## Payouts are credited directly into each bettor's SessionState record (the stake
## was already debited at placement), then the settlement is unicast to each bettor
## still connected so their local coin mirror + result UI update. Only the
## authority ever fills _wager_bets, so a non-empty dict is itself authority proof
## (no _is_pvp_host() check here — it can false-negative during session teardown).

func _settle_spectator_wagers(outcome: String) -> void:
	if _wagers_settled or _wager_bets.is_empty():
		return
	_wagers_settled = true
	var payouts: Dictionary = WagerSync.settle(_wager_bets, outcome)
	var st = SessionStore.get_state()
	if st != null:
		for token in payouts.keys():
			var payout: int = int(payouts[token])
			if payout <= 0:
				continue
			var rec: Dictionary = st.get_member(str(token))
			if rec.is_empty():
				continue
			rec["coins"] = int(rec.get("coins", 0)) + payout
			st.update_member(str(token), rec)
			SessionStore.mark_dirty()
	if _battle._net != null and multiplayer.multiplayer_peer != null:
		var payload: Dictionary = WagerSync.encode_settlement(outcome, payouts)
		var connected: PackedInt32Array = multiplayer.get_peers()
		for token in _wager_bets.keys():
			var pid: int = int((_wager_bets[token] as Dictionary).get("peer_id", 0))
			if pid > 0 and connected.has(pid):
				_battle._net.rpc_id(pid, "recv_wager_settlement", payload)
	_wager_bets.clear()


## Spectator: host accepted/rejected our bet. On accept, mirror the authority's
## escrow deduction into the local in-memory character (add_coins with the exact
## delta to the authoritative remainder) so the periodic session persist-back
## can't clobber the record with stale pre-bet coins once back in the world.

func _on_wager_ack(accepted: bool, reason: String, side: String, amount: int, remaining_coins: int) -> void:
	if not _battle._pvp_spectating:
		return
	if accepted:
		_wager_placed_side = side
		_wager_placed_amount = amount
		var cur: int = SceneManager.save_manager.coins
		SceneManager.save_manager.add_coins(remaining_coins - cur)
		if _wager_status_label != null:
			_wager_status_label.text = "Bet placed: %d on %s" % [amount, _wager_side_name(side)]
	elif _wager_status_label != null:
		_wager_status_label.text = reason
	_update_wager_panel()


## Spectator: final settlement from the authority. Credits any payout into the
## local coin mirror (the authority already wrote our SessionState record) and
## builds the result line surfaced on the post-match result overlay.

func _on_wager_settlement(payload: Dictionary) -> void:
	if not _battle._pvp_spectating:
		return
	var s: Dictionary = WagerSync.decode_settlement(payload)
	var payouts: Dictionary = s.get("payouts", {})
	var my_token: String = MpProfile.get_token()
	if not payouts.has(my_token) or _wager_placed_amount <= 0:
		return
	var payout: int = int(payouts[my_token])
	var outcome: String = str(s.get("outcome", ""))
	if payout > 0:
		SceneManager.save_manager.add_coins(payout)
	if outcome == WagerSync.OUTCOME_DRAW or outcome == WagerSync.OUTCOME_ABANDONED:
		_wager_result_text = "Bet refunded: %d coins returned" % payout
	elif payout > 0:
		_wager_result_text = "Bet won! +%d coins" % (payout - _wager_placed_amount)
	else:
		_wager_result_text = "Bet lost: -%d coins" % _wager_placed_amount
	_wager_placed_amount = 0
	_wager_placed_side = ""
	if _wager_status_label != null:
		_wager_status_label.text = _wager_result_text
	_update_wager_panel()


## "Side a" renders at the bottom for a spectator (_local_player_idx = 0 → host
## perspective, players[0] bottom / players[1] top).

func _wager_side_name(side: String) -> String:
	return "Bottom Player" if side == WagerSync.SIDE_A else "Top Player"


## Spectator: build the bet panel over the read-only view. Viewport-relative
## sizing per CLAUDE.md; every control is a tappable Button (mobile + desktop
## parity — no keyboard-only path).

func _build_wager_panel() -> void:
	if not NetworkManager.is_active() or _wager_panel != null:
		return
	var panel := PanelContainer.new()
	panel.name = "WagerPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(_battle._vh * 0.02, _battle._vh * 0.14)
	_battle._float_layer.add_child(panel)
	_wager_panel = panel
	var vbox := _UiUtil.make_vbox(int(_battle._vh * 0.012), panel)

	var title := _UiUtil.make_label("Spectator Bet", int(_battle._font(0.024)), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, vbox)

	var side_row := _UiUtil.make_hbox(int(_battle._vh * 0.01), vbox)
	var group := ButtonGroup.new()
	_wager_side_a_btn = _make_wager_side_button(_wager_side_name(WagerSync.SIDE_A), group)
	_wager_side_a_btn.button_pressed = true
	_wager_side_a_btn.pressed.connect(func() -> void: _wager_side = WagerSync.SIDE_A)
	side_row.add_child(_wager_side_a_btn)
	_wager_side_b_btn = _make_wager_side_button(_wager_side_name(WagerSync.SIDE_B), group)
	_wager_side_b_btn.pressed.connect(func() -> void: _wager_side = WagerSync.SIDE_B)
	side_row.add_child(_wager_side_b_btn)

	var amount_row := _UiUtil.make_hbox(int(_battle._vh * 0.01), vbox)
	_wager_minus_btn = _UiUtil.make_button("-", Vector2(_battle._vh * 0.055, _battle._vh * 0.055), int(_battle._font(0.025)), func() -> void: _adjust_wager_amount(-_battle._WAGER_STEP), amount_row)
	_wager_amount_label = _UiUtil.make_label(str(_wager_amount), int(_battle._font(0.025)), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, amount_row)
	_wager_amount_label.custom_minimum_size = Vector2(_battle._vh * 0.07, 0)
	_wager_plus_btn = _UiUtil.make_button("+", Vector2(_battle._vh * 0.055, _battle._vh * 0.055), int(_battle._font(0.025)), func() -> void: _adjust_wager_amount(_battle._WAGER_STEP), amount_row)

	_wager_place_btn = _UiUtil.make_button("Place Bet", Vector2(_battle._vh * 0.16, _battle._vh * 0.055), int(_battle._font(0.022)), _on_wager_place_pressed, vbox)

	_wager_status_label = _UiUtil.make_label("Bets close after turn %d." % WagerSync.CUTOFF_TURN, int(_battle._font(0.018)), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, vbox)
	_clamp_wager_amount()
	_update_wager_panel()

func _make_wager_side_button(label_text: String, group: ButtonGroup) -> Button:
	var b := _UiUtil.make_button(label_text, Vector2(_battle._vh * 0.14, _battle._vh * 0.055), int(_battle._font(0.02)))
	b.toggle_mode = true
	b.button_group = group
	return b

func _adjust_wager_amount(delta: int) -> void:
	_wager_amount += delta
	_clamp_wager_amount()
	if _wager_amount_label != null:
		_wager_amount_label.text = str(_wager_amount)


## Clamp the stepper to [1, cap]. Headroom includes any already-escrowed stake:
## replacing a bet is validated by the host against balance + prior stake.

func _clamp_wager_amount() -> void:
	var cap: int = WagerSync.max_bet(SceneManager.save_manager.coins + _wager_placed_amount)
	if cap <= 0:
		_wager_amount = 0
		return
	_wager_amount = clampi(_wager_amount, 1, cap)

func _on_wager_place_pressed() -> void:
	if _battle._net == null or _wager_amount <= 0:
		return
	if _wager_status_label != null:
		_wager_status_label.text = "Placing bet..."
	_battle._net.rpc_id(1, "submit_spectator_bet", WagerSync.encode_bet(_wager_side, _wager_amount))


## Refresh enabled/disabled state + the status line. Called on every state mirror
## (turn_number can advance past the cutoff), on ack, and on settlement.

func _update_wager_panel() -> void:
	if _wager_panel == null or not is_instance_valid(_wager_panel):
		return
	var open: bool = _battle._state != null and not _battle._pvp_ended \
			and WagerSync.is_betting_open(_battle._state.turn_number)
	var can_bet: bool = open \
			and WagerSync.max_bet(SceneManager.save_manager.coins + _wager_placed_amount) > 0
	if _wager_side_a_btn != null:
		_wager_side_a_btn.disabled = not can_bet
	if _wager_side_b_btn != null:
		_wager_side_b_btn.disabled = not can_bet
	if _wager_minus_btn != null:
		_wager_minus_btn.disabled = not can_bet
	if _wager_plus_btn != null:
		_wager_plus_btn.disabled = not can_bet
	if _wager_place_btn != null:
		_wager_place_btn.disabled = not can_bet
	if _wager_status_label == null or _wager_result_text != "":
		return
	if not open:
		if _wager_placed_amount > 0:
			_wager_status_label.text = "Bets Closed — %d on %s" % [
				_wager_placed_amount, _wager_side_name(_wager_placed_side)]
		else:
			_wager_status_label.text = "Bets Closed"
	elif not can_bet and _wager_placed_amount <= 0:
		_wager_status_label.text = "Not enough coins to bet."

# ── Co-op PvE joint battle (GID-099) ─────────────────────────────────────────


## Builds the relay node + canonical co-op state. Authority builds N ally states +
## the scaled boss; each client waits for the first sync_coop_state mirror.

func _setup_coop_pve_battle() -> void:
	_build_net_state()
	_connect_pvp_net_signals()  # reuse PvP disconnect handlers
	if _battle._is_pvp_host():
		_build_coop_pve_state()
		# Boss skips start_turn (AI acts on boss's turn via _run_ai_turn in _on_turn_ended).
		_battle._state.players[_battle._my_idx()].start_turn(1)

## Authority-only: build N-player co-op GameState from ally decks + enemy_data.

func _build_coop_pve_state() -> void:
	var n: int = maxi(1, _battle._coop_ally_decks.size())
	var boss_hp_base: int = int(_battle.enemy_data.get("boss_hp", 30))
	if boss_hp_base <= 0:
		boss_hp_base = 30
	var enemy_type: String = str(_battle.enemy_data.get("enemy_type", ""))
	var base_tier: int = EnemyRegistry.get_difficulty_tier(enemy_type) if enemy_type != "" else 1
	if bool(_battle.enemy_data.get("is_boss", false)):
		base_tier = 4
	var scaled_hp: int = _CoopBattleScaling.scale_boss_hp(boss_hp_base, n)
	var scaled_tier: int = _CoopBattleScaling.scale_boss_tier(base_tier, n)
	# BID-031: stamp the clear-timing start and the scaled tier the boss actually
	# fights at, both used later by _build_coop_reward_payload for the coop_clears
	# leaderboard's {boss_tier, clear_seconds} value.
	_coop_battle_started_at_msec = Time.get_ticks_msec()
	_coop_boss_tier = scaled_tier
	var fallback: Array[String] = ["ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul"]
	var p_idx_ref: Array[int] = [0]  # closure-safe counter
	_battle._state.setup_coop_battle(n,
		func(ally_idx: int, ally: PlayerState) -> void:
			var deck_arr: Array = _battle._coop_ally_decks[ally_idx] if ally_idx < _battle._coop_ally_decks.size() else []
			var insts: Array[Dictionary] = []
			var ids: Array[String] = []
			for inst in deck_arr:
				if inst is Dictionary:
					insts.append(inst)
				elif inst is String:
					ids.append(inst)
			if insts.size() > 0:
				ally.build_deck_from_instances(insts)
			elif ids.size() > 0:
				# Plain card-id deck (e.g. a co-op Endless Spire shared draft deck) —
				# every ally shuffles their own independent draw order from the same ids.
				ally.build_deck(ids)
			else:
				ally.build_deck(fallback)
			ally.draw_opening_hand(4)
			p_idx_ref[0] += 1,
		func(boss_ps: PlayerState) -> void:
			var raw: Array = _battle.enemy_data.get("enemy_deck", [])
			var boss_deck: Array[String] = []
			boss_deck.assign(raw)
			if boss_deck.is_empty():
				boss_deck = fallback
			boss_ps.build_deck(boss_deck, scaled_tier)
			boss_ps.draw_opening_hand(4)
			boss_ps.hero.health = scaled_hp
			boss_ps.hero.max_health = scaled_hp)

## Client: receive and apply an authoritative co-op state mirror.

func _on_coop_state(payload: Dictionary) -> void:
	if not _battle._is_pvp_client():
		return
	if not _accept_state_mirror(payload):
		return

## Authority-side handling of one participant's intent in an N-player battle.
##
## Co-op PvE and team duels run the same wire protocol over different tables, so
## they share this and pass their own mode flag, peer→index map, state broadcast
## and game-over check. Any intent the authority rejects — wrong peer, out of
## turn — answers with a state broadcast, which snaps the sender back onto the
## canonical state rather than leaving them desynced.
func _handle_participant_intent(sender: int, payload: Dictionary, mode_active: bool,
		peer_to_idx: Dictionary, broadcast: Callable, check_game_over: Callable) -> void:
	if not _battle._is_pvp_host() or not mode_active:
		return
	var intent: Dictionary = BattleNetProtocol.decode_intent(payload)
	var t: String = str(intent["type"])
	if t == "":
		return
	# Map peer → participant idx. The host never sends intents to itself.
	var acting_idx: int = int(peer_to_idx.get(sender, -1))
	if acting_idx < 0:
		return
	if t == BattleNetProtocol.INTENT_SURRENDER:
		# Surrender: mark that participant dead (spectating) and broadcast.
		_battle._state.players[acting_idx].hero.health = 0
		broadcast.call()
		check_game_over.call()
		return
	if _battle._state.current_player_idx != acting_idx:
		broadcast.call()
		return
	var changed: bool = _apply_remote_intent(intent, acting_idx)
	if changed:
		_battle._refresh_all()
		check_game_over.call()
	else:
		broadcast.call()

## Authority: validate + apply an ally client's intent for the co-op battle.

func _on_coop_intent(sender: int, payload: Dictionary) -> void:
	_handle_participant_intent(sender, payload, _battle._coop_pve,
		_coop_peer_to_idx, _broadcast_coop_state, _coop_pve_check_game_over)

## Host: a client asked for the current co-op state — send it.

func _on_coop_sync_request() -> void:
	if _battle._is_pvp_host() and _battle._coop_pve:
		_broadcast_coop_state()

## Authority: broadcast the full canonical co-op state.

func _broadcast_coop_state() -> void:
	if not _battle._is_pvp_host() or _battle._net == null:
		return
	_state_seq += 1
	_battle._net.rpc("sync_coop_state", BattleNetProtocol.encode_state(_battle._state.to_dict(), _state_seq))

## Authority-only: detect co-op battle end, compute rewards, and broadcast.

func _coop_pve_check_game_over() -> void:
	if not _battle._is_pvp_host():
		return
	if _battle._state.is_game_over():
		if _coop_ended:
			return
		_coop_ended = true
		var w: int = _battle._state.winner()
		var did_win: bool = (w == 0)  # 0 = party wins
		_broadcast_coop_state()
		var reward_payload: Dictionary = _build_coop_reward_payload(did_win)
		if _battle._net != null:
			_battle._net.rpc("coop_battle_ended", reward_payload)
		_finish_coop_pve(did_win, reward_payload)
		return
	_broadcast_coop_state()

## Computes the reward payload for the co-op battle result.
## Each ally gets: full coins, full XP, and the soulbound card (if won).
##
## BID-031: also carries `boss_tier`/`clear_seconds` — computed here (host-only,
## the only side that ever calls this) and RPC'd to every peer via the existing
## `coop_battle_ended` broadcast, so `_finish_coop_pve` can forward them to
## `GameBus.coop_pve_battle_ended`'s `result` dict on every peer without a second
## signal or an extra RPC. Included on both win/loss so a future "best attempt"
## leaderboard entry (a loss with a good clear time) has the data available even
## though today's `_on_coop_pve_battle_ended_leaderboard` only submits on a win.

func _build_coop_reward_payload(did_win: bool) -> Dictionary:
	var clear_seconds: float = 0.0
	if _coop_battle_started_at_msec > 0:
		clear_seconds = float(Time.get_ticks_msec() - _coop_battle_started_at_msec) / 1000.0
	if not did_win:
		return {"winner_ally": false, "card_id": "", "rarity": "", "stats": {}, "coins": 0, "xp": 0,
			"boss_tier": _coop_boss_tier, "clear_seconds": clear_seconds}
	var enemy_type: String = str(_battle.enemy_data.get("enemy_type", ""))
	var is_boss: bool = bool(_battle.enemy_data.get("is_boss", false))
	var drop_tier: int = EnemyRegistry.get_difficulty_tier(enemy_type) if enemy_type != "" else 1
	if is_boss:
		drop_tier = 4
	var coins: int = EnemyRegistry.get_coin_reward(enemy_type) if enemy_type != "" else 0
	var xp: int = EnemyRegistry.get_xp_reward(enemy_type, is_boss)
	var pool: Array[String] = EnemyRegistry.get_drop_pool(enemy_type)
	var card_id: String = ""
	var rarity: String = ""
	var stats: Dictionary = {}
	if pool.size() > 0:
		card_id = pool[randi() % pool.size()]
		rarity = CardDropUtil.effective_rarity(card_id, CardDropUtil.roll_rarity(drop_tier))
		stats = CardDropUtil.roll_stats(card_id, rarity)
	return {"winner_ally": true, "card_id": card_id, "rarity": rarity, "stats": stats, "coins": coins, "xp": xp,
		"boss_tier": _coop_boss_tier, "clear_seconds": clear_seconds}

## Called on every peer (host from _coop_pve_check_game_over, clients from RPC).

func _on_coop_battle_ended(payload: Dictionary) -> void:
	if _coop_ended:
		return
	_coop_ended = true
	var did_win: bool = bool(payload.get("winner_ally", false))
	_finish_coop_pve(did_win, payload)

## Apply rewards locally and show a simple result message, then return to world.

func _finish_coop_pve(did_win: bool, payload: Dictionary) -> void:
	_disconnect_pvp_net_signals()
	if did_win:
		AudioManager.play_sfx("battle_win")
		_battle._fx.haptic(120)
		var card_id: String = str(payload.get("card_id", ""))
		var rarity: String = str(payload.get("rarity", ""))
		var stats: Dictionary = {}
		var raw_stats: Variant = payload.get("stats", {})
		if raw_stats is Dictionary:
			stats = raw_stats
		var coins: int = int(payload.get("coins", 0))
		var xp: int = int(payload.get("xp", 0))
		_apply_coop_pve_rewards(card_id, rarity, stats, coins, xp)
	else:
		AudioManager.play_sfx("battle_lose")
		_battle._fx.haptic(80)
	# Minimal result: show HUD message and return. Full ceremony is GID-100.
	var msg: String = "Party victorious!" if did_win else "The party was defeated."
	GameBus.hud_message_requested.emit(msg)
	await get_tree().create_timer(2.0, false).timeout
	# BID-031: forward the boss-tier/clear-time signal _build_coop_reward_payload
	# already computed (host) and RPC'd (every peer, via `payload`) so
	# WorldScene's coop_clears leaderboard can rank on something richer than
	# party size. Defaults keep this safe for any payload shape that predates
	# these fields (e.g. a saved/replayed battle payload).
	var result: Dictionary = {
		"boss_tier": int(payload.get("boss_tier", 1)),
		"clear_seconds": float(payload.get("clear_seconds", 0.0)),
	}
	GameBus.coop_pve_battle_ended.emit(did_win, result)

## Apply the per-ally rewards from a co-op win to the local session character.

func _apply_coop_pve_rewards(card_id: String, rarity: String, stats: Dictionary, coins: int, xp: int) -> void:
	var sm := SceneManager.save_manager
	if coins > 0:
		sm.add_coins(coins)
	if xp > 0:
		sm.add_xp(xp)
	if card_id == "" or rarity == "":
		return
	# Use the signature card as the soulbound card (same as solo soulbind logic).
	# Each ally gets their own instance.
	var atk: int = int(stats.get("attack", -1))
	var hp: int = int(stats.get("health", -1))
	var cst: int = int(stats.get("cost", -1))
	sm.grant_card_reward(card_id, rarity, atk, hp, cst)

## Co-op PvE retry sync (mirrors _process for PvP).

func _process_coop_sync(delta: float) -> void:
	if not _battle._coop_pve or not _battle._is_pvp_client() or _battle._last_applied_seq >= 0 or _battle._net == null:
		return
	_coop_sync_retry_accum += delta
	if _coop_sync_retry_accum >= 0.4:
		_coop_sync_retry_accum = 0.0
		_battle._net.rpc_id(1, "request_coop_sync")


# -------------------------------------------------------------------------
# Team PvP duels (GID-102 / TID-371)
#
# 2v2 only. Mirrors the GID-099 co-op-PvE section structurally (own RPC set, own
# setup/intent/state/end-of-battle functions) rather than the 2-player PvP path,
# since both need N-participant handling. The host is always players[0]/team 0;
# GameState.player_teams + the focus mechanism (_opp_idx()) carry the rest.
# -------------------------------------------------------------------------

## Builds the relay node + canonical state for a team battle. Host builds all 4
## decks and starts turn 1; clients wait for the first sync_team_state mirror.

func _setup_team_battle() -> void:
	_build_net_state()
	_connect_pvp_net_signals()  # reuse PvP disconnect handlers
	if _battle._is_pvp_host():
		_build_team_battle_state()
		_battle._state.players[_battle._my_idx()].start_turn(1)

## Authority-only: build the 4-player team GameState from _team_decks/_team_assignments.
## _team_assignments[i] is the team (0/1) for absolute player index i; team_a_setup/
## team_b_setup close over that to assign the right deck per absolute index.

func _build_team_battle_state() -> void:
	var fallback: Array[String] = ["ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul"]
	var deck_for_abs_idx := func(abs_idx: int) -> Array[Dictionary]:
		var insts: Array[Dictionary] = []
		if abs_idx < _battle._team_decks.size():
			for inst in _battle._team_decks[abs_idx]:
				if inst is Dictionary:
					insts.append(inst)
		return insts
	# setup_team_battle calls team_a_setup for absolute indices 0,2 and team_b_setup
	# for 1,3 (the interleaved layout) with local_idx 0/1 within that team — recover
	# the absolute index from _team_assignments so each member gets their own deck.
	var abs_for_team := func(team: int, local_idx: int) -> int:
		var seen: int = 0
		for i in range(_battle._team_assignments.size()):
			if int(_battle._team_assignments[i]) == team:
				if seen == local_idx:
					return i
				seen += 1
		return -1
	_battle._state.setup_team_battle(
		func(local_idx: int, ps: PlayerState) -> void:
			var abs_idx: int = abs_for_team.call(0, local_idx)
			var insts: Array[Dictionary] = deck_for_abs_idx.call(abs_idx) if abs_idx >= 0 else []
			if insts.size() > 0:
				ps.build_deck_from_instances(insts)
			else:
				ps.build_deck(fallback)
			ps.draw_opening_hand(4),
		func(local_idx: int, ps: PlayerState) -> void:
			var abs_idx: int = abs_for_team.call(1, local_idx)
			var insts: Array[Dictionary] = deck_for_abs_idx.call(abs_idx) if abs_idx >= 0 else []
			if insts.size() > 0:
				ps.build_deck_from_instances(insts)
			else:
				ps.build_deck(fallback)
			ps.draw_opening_hand(4))

## Client: receive and apply an authoritative team-battle state mirror.

func _on_team_state(payload: Dictionary) -> void:
	if not _battle._is_pvp_client():
		return
	if not _accept_state_mirror(payload):
		return

## Authority: validate + apply a team participant's intent.

func _on_team_intent(sender: int, payload: Dictionary) -> void:
	_handle_participant_intent(sender, payload, _battle._team_pvp,
		_team_peer_to_idx, _broadcast_team_state, _team_check_game_over)

## Host: a client asked for the current team-battle state — send it.

func _on_team_sync_request() -> void:
	if _battle._is_pvp_host() and _battle._team_pvp:
		_broadcast_team_state()

## Authority: broadcast the full canonical team-battle state.

func _broadcast_team_state() -> void:
	if not _battle._is_pvp_host() or _battle._net == null:
		return
	_state_seq += 1
	_battle._net.rpc("sync_team_state", BattleNetProtocol.encode_state(_battle._state.to_dict(), _state_seq))

## Authority-only: detect team-battle end and broadcast.

func _team_check_game_over() -> void:
	if not _battle._is_pvp_host():
		return
	if _battle._state.is_game_over():
		if _team_ended:
			return
		_team_ended = true
		var winning_team: int = _battle._state.winner()
		_broadcast_team_state()
		var payload: Dictionary = {"winning_team": winning_team}
		if _battle._net != null:
			_battle._net.rpc("team_battle_ended", payload)
		_finish_team_battle(winning_team, payload)
		return
	_broadcast_team_state()

## Called on every peer (host from _team_check_game_over, clients from RPC).

func _on_team_battle_ended(payload: Dictionary) -> void:
	if _team_ended:
		return
	_team_ended = true
	var winning_team: int = int(payload.get("winning_team", -1))
	_finish_team_battle(winning_team, payload)

## Apply a minimal result (no card/coin rewards — duel-style, like unwagered 2-player
## PvP; ante wagers are out of scope for v1) and return to the shared world. Full
## result ceremony is a future enhancement, mirroring _finish_coop_pve's "minimal
## result" precedent (GID-100 polish applies there too).

func _finish_team_battle(winning_team: int, _payload: Dictionary) -> void:
	_disconnect_pvp_net_signals()
	var my_team: int = int(_battle._state.player_teams[_battle._my_idx()]) if _battle._my_idx() < _battle._state.player_teams.size() else 0
	var did_win: bool = winning_team == my_team
	if did_win:
		AudioManager.play_sfx("battle_win")
		_battle._fx.haptic(120)
	else:
		AudioManager.play_sfx("battle_lose")
		_battle._fx.haptic(80)
	var msg: String = "Your team is victorious!" if did_win else "Your team was defeated."
	GameBus.hud_message_requested.emit(msg)
	await get_tree().create_timer(2.0, false).timeout
	GameBus.team_battle_ended.emit(did_win)

## Team-battle retry sync (mirrors _process_coop_sync).

func _process_team_sync(delta: float) -> void:
	if not _battle._team_pvp or not _battle._is_pvp_client() or _battle._last_applied_seq >= 0 or _battle._net == null:
		return
	_team_sync_retry_accum += delta
	if _team_sync_retry_accum >= 0.4:
		_team_sync_retry_accum = 0.0
		_battle._net.rpc_id(1, "request_team_sync")

## Builds (or rebuilds) the read-only team status bar: one compact hero panel per
## participant (HP/mana), grouped my-team-first then enemy-team. Enemy panels are
## tappable focus targets (sets _team_focus_target_pidx, drives _opp_idx()); my-team
## panels are informational only (no per-teammate spell targeting in v1).

func _build_team_arena_layout() -> void:
	if not _battle._team_pvp or _battle._state == null:
		return
	for p in _team_panels:
		if is_instance_valid(p):
			p.queue_free()
	_team_panels.clear()

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = _battle._vh * 0.08
	_battle.add_child(bar)
	_team_panels.append(bar)

	var my_team: int = int(_battle._state.player_teams[_battle._my_idx()]) if _battle._my_idx() < _battle._state.player_teams.size() else 0
	var order: Array[int] = []
	for i in range(_battle._state.players.size()):
		if i < _battle._state.player_teams.size() and _battle._state.player_teams[i] == my_team:
			order.append(i)
	for i in range(_battle._state.players.size()):
		if i < _battle._state.player_teams.size() and _battle._state.player_teams[i] != my_team:
			order.append(i)
	for pidx in order:
		var ps: PlayerState = _battle._state.players[pidx]
		var is_enemy: bool = pidx < _battle._state.player_teams.size() and _battle._state.player_teams[pidx] != my_team
		var btn := Button.new()
		btn.text = "%s P%d  HP:%d/%d  Mana:%d" % [
			"Enemy" if is_enemy else "Ally", pidx + 1,
			ps.hero.health, ps.hero.max_health, ps.hero.mana]
		btn.custom_minimum_size = Vector2(_battle._vh * 0.20, _battle._vh * 0.06)
		if is_enemy:
			var cap_pidx: int = pidx
			btn.pressed.connect(func() -> void:
				_battle._team_focus_target_pidx = cap_pidx
				_battle._refresh_all()
			)
		bar.add_child(btn)
	_team_arena_built = true

func _refresh_team_panels() -> void:
	if not _battle._team_pvp or _battle._state == null:
		return
	if not _team_arena_built:
		_build_team_arena_layout()
		return
	# Rebuild wholesale: simplest correct option since the focused enemy can change
	# the highlighted/ordered set, and there are only ever 4 panels.
	_build_team_arena_layout()
