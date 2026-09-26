# gdlint: disable=max-file-lines
# BID-053 lint debt: oversized script. Shrink it by extraction; don't add to it.
extends Control

const GameState = preload("res://game_logic/battle/GameState.gd")
const _BattleNet = preload("res://scenes/battle/net/BattleNet.gd")
const _BattleNetSync = preload("res://scenes/battle/BattleNetSync.gd")
const _BattleModifiers = preload("res://scenes/battle/modules/BattleModifiers.gd")
const _BattleConsumables = preload("res://scenes/battle/modules/BattleConsumables.gd")
const _BattleTutorials = preload("res://scenes/battle/modules/BattleTutorials.gd")
const _BattleArena = preload("res://scenes/battle/modules/BattleArena.gd")
const _BattleTargeting = preload("res://scenes/battle/modules/BattleTargeting.gd")
const _BattleInput = preload("res://scenes/battle/modules/BattleInput.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const ScriptedBattleData = preload("res://game_logic/battle/ScriptedBattleData.gd")
const BasicAI = preload("res://ai/BasicAI.gd")
const _BattlePacing = preload("res://game_logic/battle/BattlePacing.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")
const CompanionRegistry = preload("res://autoloads/CompanionRegistry.gd")
const CompanionData = preload("res://data/CompanionData.gd")
const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
const _TutorialPopupScript = preload("res://scenes/ui/TutorialPopup.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const WeatherBanner = preload("res://scenes/battle/WeatherBanner.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const Gambits = preload("res://game_logic/battle/Gambits.gd")
const CaptureTracker = preload("res://game_logic/battle/CaptureTracker.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const BattleFx = preload("res://scenes/battle/BattleFx.gd")
const UiFx = preload("res://scenes/ui/UiFx.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const CardViewBuilder = preload("res://scenes/battle/CardViewBuilder.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const BattlePauseUI = preload("res://scenes/battle/BattlePauseUI.gd")
const BattleResultUI = preload("res://scenes/battle/BattleResultUI.gd")
const BattleNetProtocol = preload("res://game_logic/net/BattleNetProtocol.gd")
const BattleBackdrop = preload("res://scenes/battle/BattleBackdrop.gd")

# ── Spectator wagers (GID-104 / TID-387) ─────────────────────────────────────
# Spectators may bet coins on side a (players[0]) or b (players[1]) before the
# WagerSync.CUTOFF_TURN. The AUTHORITY holds escrow: the stake is deducted from
# the bettor's SessionState member record the moment the bet is accepted, and
# settlement credits payouts back on battle end (same direct-SessionStore-write
# pattern as WorldScene._grant_chest_loot_to_token). Refunds on spectator
# disconnect, draw, or abandoned match. Only coins are ever at risk — never cards.
# All inert unless NetworkManager.is_active(); single-player never touches this.
# Spectator-side UI + local mirror of the accepted bet.
const _WAGER_STEP: int = 5
const _PVP_RECONNECT_GRACE_SECONDS: float = 45.0
const _BATTLEFIELD_BANNER_DURATION: float = 3.0
const TUTORIAL_DURATION: float = 8.0

## World-encounter ambush handicaps (GID-113 / TID-421, TID-422). Mirrors
## `wounded_pride`'s shape: sets both `health` and `max_health` so the
## handicap survives the whole match instead of being healed away by the
## first heal card. `player_ambush`/`enemy_ambush` are mutually exclusive by
## construction (EnemyNPC.engage() derives them from different alert-state
## values) so only one branch below ever fires.
const _AMBUSH_HP_PCT: float = 0.2
const _AMBUSH_HP_MIN: int = 10

var enemy_data: Dictionary = {}
## Set by SceneManager when the battle is fought over the live (frozen) world
## (GID-135 / TID-528): the backdrop is skipped so the world shows through.
var in_world: bool = false
var duel_wager: int = 0
var puzzle_data: Resource = null  # PuzzleData set by SceneManager before _ready

# ── Scripted story battles (GID-108) ─────────────────────────────────────────
# Fixed-deck tutorial battles (rabbit hunt, Ch2 ambush). All inert unless
# SceneManager sets scripted_data = a ScriptedBattleData resource before _ready.
var scripted_data: Resource = null
## Networked-battle module (PvP, spectating, wagers, co-op PvE, team duels).
## A child node created in _ready and registered with BattleNetSync as an RPC
## handler target; inert in a solo battle. See scenes/battle/net/BattleNet.gd.
var battle_net: _BattleNet = null
## Single-player clusters (scenes/battle/modules/), built by `_ensure_battle_modules()`.
var modifiers: _BattleModifiers
var consumables: _BattleConsumables
var tutorials: _BattleTutorials
var arena: _BattleArena
var targeting: _BattleTargeting
var card_input: _BattleInput
var realtime: _BattleRealtime
# Listen-server: client deck relayed in challenge handshake (host builds players[1]).
var pvp_opponent_deck: Array = []
# Dedicated-server referee (GID-097 / TID-353): both player decks come from clients.
var pvp_player0_deck: Array = []
var pvp_player1_deck: Array = []

# ── PvP reconnect (GID-102 / TID-372) ────────────────────────────────────────
# Listen-server host: the opponent's identity token, so a reconnect can be verified.
# Set by SceneManager.enter_pvp_battle (sourced from WorldScene's
# _session_token_by_peer). Empty when unknown — verification then falls back to
# accepting any reconnect (same-LAN trust model, see _on_reconnect_announced).
var pvp_opponent_token: String = ""

# Wager (GID-101 / TID-368): ante_coins for the current PvP duel; 0 = unwagered.
# The host reads this to include wager info in the pvp_ended payload.
var pvp_ante_coins: int = 0

# Ranked opt-in (GID-102 / TID-373): set by SceneManager.enter_pvp_battle before
# _ready. When true, _state.ranked is set so WorldScene knows to run the TID-370
# ELO rating update on battle end (gated in WorldScene, not here).
var pvp_ranked: bool = false

# Draft duel (GID-104 / TID-385): when non-empty, the listen-server host builds
# its own players[0] deck from these TRANSIENT drafted-instance dicts instead of
# SaveManager.get_deck_instances() — a drafted deck must never read (or write)
# the persisted collection. Set by SceneManager.enter_pvp_battle before _ready.
var pvp_local_deck_override: Array = []

var _fx: BattleFx
var _view: CardViewBuilder
var _resolver: SpellEffectResolver
var _pause_ui: BattlePauseUI
var _result_ui: BattleResultUI
var _scripted_data_ref: Resource = null  # retained for turn-keyed tutorial popups
var _scripted_tutorial_turns_shown: Dictionary = {}  # int turn_number -> true, dedupe

# ── Ghost duels (GID-102 / TID-377) ──────────────────────────────────────────
# All inert unless SceneManager sets _ghost_duel = true before _ready (via
# enter_ghost_duel). This is a plain solo battle (no _pvp/_coop_pve) against an
# AI-piloted snapshot of another session member's deck — zero live networking.
# Distinct from duel_wager/friendly_duel: that path deducts/refunds a real coin
# stake on loss (BattleResultUI.show_duel_loss), which would be wrong here since
# nothing was ever staked against an offline AI opponent. Coins are granted
# win-only, exactly once, by SceneManager._on_ghost_duel_ended.
var _ghost_duel: bool = false
var _ghost_duel_reward: int = 0

# ── PvP card battles (GID-091 + GID-097) ─────────────────────────────────────
# All inert unless SceneManager sets _pvp = true before _ready. Single-player,
# NPC duel, puzzle and Spire battles never touch any of this.
var _pvp: bool = false
var _local_player_idx: int = 0       # 0 = host/challenger, 1 = client, -1 = server referee
var _net: _BattleNetSync = null       # BattleNetSync relay, added under this scene
var _last_applied_seq: int = -1      # client: last mirror seq applied
var _pvp_pending: bool = false       # client: waiting on host ack of last action
var _pvp_ended: bool = false         # guard so the result fires once
var _pvp_peer_to_idx: Dictionary = {}  # peer_id (int) → player_idx (int), referee only

# ── Duel spectating (GID-101 / TID-367) ──────────────────────────────────────
# A spectator enters BattleScene with _pvp_spectating = true. They receive state
# mirrors from the host but never send any intents. Input is fully blocked.
# The host tracks spectator peer_ids in _spectators and fans sync_state to them.
var _pvp_spectating: bool = false
# Dedicated-server referee: idx (0/1) -> identity token, for the same verification.
var _pvp_idx_to_token: Dictionary = {}
# Host/referee: idx of the combatant currently mid-grace-window after a disconnect,
# or -1 if no reconnect is pending. Set by _on_pvp_peer_disconnected, cleared by a
# successful _on_reconnect_announced or the grace timer's timeout (forfeit).
var _pvp_reconnect_idx: int = -1

# ── Co-op PvE joint battle (GID-099) ─────────────────────────────────────────
# All inert unless SceneManager sets _coop_pve = true before _ready.
# _local_player_idx is the local ally index (0 = host/ally-0, 1..N-1 = ally clients).
# The boss is always AI-controlled by the authority (host).
# Peer-to-ally mapping mirrors the referee's _pvp_peer_to_idx logic.
var _coop_pve: bool = false
# All ally deck instances: Array[Array[Dictionary]], indexed [ally_idx][card_inst].
# Set by SceneManager before _ready; only the authority uses all N entries.
var _coop_ally_decks: Array = []
# Peer-to-ally-idx map, built by the authority from the join handshake.

# ── Team PvP duels (GID-102 / TID-371) ───────────────────────────────────────────
# All inert unless SceneManager sets _team_pvp = true before _ready. 2v2 only: 4
# players, GameState.player_teams[i] is 0 or 1. _local_player_idx is the local
# player's absolute index (host is always 0, see SceneManager.enter_team_battle).
var _team_pvp: bool = false
# Per-team deck instances, indexed by the absolute player index (0..3). Set by
# SceneManager before _ready; only the authority uses all 4 entries.
var _team_decks: Array = []
# player_teams snapshot (0/1 per absolute index), set by SceneManager before _ready.
var _team_assignments: Array = []
# Manual enemy-target focus (-1 = auto lowest-HP enemy-team member). Tapping an
# enemy panel in the team status bar sets this; it drives _opp_idx() so the
# existing EnemyArea rendering + attack/spell targeting transparently follow it.
var _team_focus_target_pidx: int = -1
# Team status bar (read-only HP/mana for all 4 participants; enemy panels are
# tappable focus targets). Mirrors _coop_ally_panels/_coop_arena_built.

# Weather modifier state — determined once at battle start
var _battle_weather: String = ""  # "" if no infinite-world weather applies
var _snow_discount_used: Array[bool] = [false, false]  # per-player first-card discount
var _puzzle_data_ref: Resource = null  # retained for reset
var _give_up_btn: Button = null
var _companion_hud: Control = null
var _state: GameState
var _ai_thinking: bool = false
# True while a local action (attack lunge, card-travel) is animating. Blocks
# further input so repeated taps can't stack attacks or overlap tweens.
var _action_busy: bool = false
var _game_over_handled: bool = false
var _boss_phase2_triggered: bool = false
var _hero_power_btn: Button = null
var _hero_power_used: bool = false
var _potion_btn: Button = null
var _used_potion_this_battle: bool = false
var _gambit_badge: Control = null

# Battlefield Resonance UI (GID-059)
var _battlefield_banner: Control = null
var _battlefield_info_label: Label = null  # persistent day/night + biome label in SidePanel
var _slot_highlight_panels: Array[Control] = []  # overlay panels on affected slots

var _float_layer: CanvasLayer = null

# Click-to-target for board-card attacks (select attacker, then click enemy)
var _dragged_card: Dictionary = {}  # {card: CardInstance}
var _vh: float = 0.0
# Multiplier from the "text_scale" accessibility setting (GID-119 / TID-451).
var _text_scale: float = 1.0

# Drag-to-play: populated when native drag starts so CardViewBuilder can highlight slots.
# Cleared in NOTIFICATION_DRAG_END and after a successful drop.
var _hand_drag_card: CardInstance = null
var _cancel_btn: Button = null

# Card inspect overlay
var _inspect_overlay: Control = null

# Untargeted-spell tap confirm (GID-119 / TID-450)
var _cast_confirm_layer: CanvasLayer = null

# Battle speed (TID-254): 1.0 = normal, 0.45 = fast
var _speed_scale: float = 1.0

# Spell targeting (TID-058, extended TID-141)
var _targeting_spell: CardInstance = null
var _targeting_active: bool = false
var _targeting_friendly: bool = false

# Slot targeting (TID-294)
var _slot_targeting_spell: CardInstance = null

# Ally targeting for co-op PvE support cards (GID-100)
var _ally_targeting_spell: CardInstance = null
var _ally_targeting_active: bool = false

# Co-op arena layout (GID-100): compact ally panels above the enemy area
var _coop_arena_built: bool = false
var _coop_ally_panels: Array[Control] = []   # one panel per ally player index

# Mobile tap-to-slot placement (TID-293)
var _slot_select_card: CardInstance = null

# Soulbind capture tracker (GID-061)
var _capture_tracker: CaptureTracker = null

# First-battle tutorial overlay
var _tutorial_overlay: Node = null

# Dual-face flip tracking (GID-062): instance_ids already flipped this battle.
var _flipped_dual_ids: Dictionary = {}

@onready var _enemy_hand_view: HBoxContainer = $EnemyArea/EnemyHandView
@onready var _enemy_board_view: HBoxContainer = $EnemyArea/EnemyBoardView
@onready var _enemy_hero_view: PanelContainer = $EnemyArea/EnemyHeroView
@onready var _player_board_view: HBoxContainer = $PlayerArea/PlayerBoardView
@onready var _player_hand_view: HBoxContainer = $PlayerArea/PlayerHandView
@onready var _player_hero_view: PanelContainer = $PlayerArea/PlayerHeroView
@onready var _turn_label: Label = $SidePanel/TurnLabel
@onready var _mana_label: Label = $SidePanel/ManaLabel
@onready var _end_turn_btn: Button = $SidePanel/EndTurnButton
@onready var _menu_btn: Button = $SidePanel/MenuButton

## Creates the networked-battle module and, once BattleNetSync exists, registers
## it as an RPC handler target. Called from _ready before anything dispatches to
## it, and again from the net setup paths that build BattleNetSync.
func _ensure_battle_net() -> void:
	if battle_net == null or not is_instance_valid(battle_net):
		battle_net = _BattleNet.new()
		battle_net.name = "BattleNet"
		battle_net.set("_battle", self)
		add_child(battle_net)
	if _net != null and _net.has_method("register_handler"):
		_net.call("register_handler", battle_net)

## Creates the single-player modules. Idempotent. Called first in `_ready`, since
## setup dispatches to them straight away.
func _ensure_battle_modules() -> void:
	if modifiers != null:
		return
	modifiers = _BattleModifiers.new(self)
	modifiers.name = "BattleModifiers"
	add_child(modifiers)
	consumables = _BattleConsumables.new(self)
	consumables.name = "BattleConsumables"
	add_child(consumables)
	tutorials = _BattleTutorials.new(self)
	tutorials.name = "BattleTutorials"
	add_child(tutorials)
	arena = _BattleArena.new(self)
	arena.name = "BattleArena"
	add_child(arena)
	targeting = _BattleTargeting.new(self)
	targeting.name = "BattleTargeting"
	add_child(targeting)
	card_input = _BattleInput.new(self)
	card_input.name = "BattleInput"
	add_child(card_input)
	realtime = _BattleRealtime.new(self)
	realtime.name = "BattleRealtime"
	add_child(realtime)

func _process(delta: float) -> void:
	if battle_net != null:
		battle_net.tick(delta)

func _ready() -> void:
	_ensure_battle_modules()
	_ensure_battle_net()
	_float_layer = CanvasLayer.new()
	_float_layer.layer = 128
	add_child(_float_layer)
	_vh = get_viewport().get_visible_rect().size.y
	_text_scale = clampf(float(SceneManager.save_manager.get_setting("text_scale", 1.0)), 0.5, 2.0)
	_fx = BattleFx.new()
	_fx.setup(_vh, _float_layer,
		_enemy_hero_view, _player_hero_view,
		_enemy_board_view, _player_board_view,
		self, _text_scale)
	_view = CardViewBuilder.new()
	_view.setup(_vh, _fx, card_input._bind_card_input, card_input._on_empty_slot_input, _make_card_view, _text_scale)
	var _bs: String = str(SceneManager.save_manager.get_setting("battle_speed", "normal"))
	_speed_scale = _BattlePacing.FAST_SPEED_SCALE if _bs == "fast" else 1.0
	_apply_ui_sizes()
	_resolver = SpellEffectResolver.new()
	_pause_ui = BattlePauseUI.new()
	_result_ui = BattleResultUI.new()
	_pause_ui.setup(self, _vh, _float_layer, _make_battle_save,
		func() -> bool: return _state.puzzle_mode or _state.scripted_battle)
	_result_ui.setup(self, _vh, _float_layer, _collect_veterancy_data)
	var _saved_battle: Dictionary = SceneManager.save_manager.pending_battle_state
	if puzzle_data != null:
		_puzzle_data_ref = puzzle_data
		_state = GameState.new()
		_resolver.setup(_state)
		_state.load_puzzle(puzzle_data)
		_wire_gamebus_emitter()
	elif scripted_data != null:
		_scripted_data_ref = scripted_data
		_state = GameState.new()
		_resolver.setup(_state)
		_state.load_scripted_battle(scripted_data)
		_wire_gamebus_emitter()
	elif _pvp:
		battle_net._setup_pvp_battle()
	elif _coop_pve:
		battle_net._setup_coop_pve_battle()
	elif _team_pvp:
		battle_net._setup_team_battle()
	elif not _saved_battle.is_empty():
		_state = GameState.new()
		_resolver.setup(_state)
		_state.from_dict(_saved_battle)
		_wire_gamebus_emitter()
		_boss_phase2_triggered = bool(_saved_battle.get("_boss_phase2", false))
		_hero_power_used = bool(_saved_battle.get("_hero_power_used", false))
		_bump_card_next_id(_state)
		SceneManager.save_manager.clear_pending_battle_state()
	else:
		_setup_solo_battle()
	# Every entry path above builds its own `_state`; re-point the helpers that
	# cache it here, once, rather than in each branch (puzzle, scripted, resume and
	# the networked setups used to skip it and render against a null state).
	_bind_state()

	# Initialise capture tracker for the current enemy (no-op for puzzles/duels/PvP/ghost duels).
	if not _state.puzzle_mode and not _state.friendly_duel and not _pvp and not _ghost_duel and not _state.scripted_battle:
		var _ct_enemy_type: String = str(enemy_data.get("enemy_type", ""))
		var _ct_condition: String = EnemyRegistry.get_capture_condition(_ct_enemy_type)
		var _ct_param: int = EnemyRegistry.get_capture_param(_ct_enemy_type)
		_capture_tracker = CaptureTracker.new(_ct_condition, _ct_param)
		_resolver.capture_tracker = _capture_tracker

	_end_turn_btn.pressed.connect(_on_end_turn)
	_menu_btn.pressed.connect(_pause_ui.confirm_return_to_menu)
	UiFx.attach(_end_turn_btn)
	UiFx.attach(_menu_btn)
	_enemy_hero_view.gui_input.connect(card_input._on_enemy_hero_input)
	targeting._setup_board_drop_zone()
	_pause_ui.add_pause_button($SidePanel)
	consumables._add_hero_power_button()
	modifiers._add_companion_hud()
	consumables._add_potion_button()
	modifiers._add_gambit_badge()
	arena._add_effects_button()

	if _state.puzzle_mode:
		_end_turn_btn.text = "Check"
		_give_up_btn = _UiUtil.make_button("Give Up", Vector2(_vh * 0.16, _vh * 0.07), int(_font(0.025)),
				_on_puzzle_give_up)
		$SidePanel.add_child(_give_up_btn)
	_state.turn_ended.connect(_on_turn_ended)
	GameBus.fatigue_damage.connect(_on_fatigue_damage)

	_refresh_all()
	consumables._refresh_potion_button()

	# Catch any hero deaths that occurred during setup (e.g., fatigue on very small
	# Spire decks, or auto-resolve spells dealing damage before game-over was wired).
	_check_game_over()

	# GID-135 / TID-546: real-time mode (setting-gated, fresh solo PvE only).
	realtime.maybe_start(_saved_battle.is_empty())

	# If we resumed a battle mid-AI-turn, restart the AI (deferred so UI is ready).
	if not _saved_battle.is_empty() and _state.current_player_idx == 1 and not _state.is_game_over():
		_check_game_over.call_deferred()
		_run_ai_turn.call_deferred()

	# Show weather banner if a modifier is active
	if _battle_weather != "" and not _state.puzzle_mode and not _state.scripted_battle:
		var banner: WeatherBanner = WeatherBanner.new()
		add_child(banner)
		banner.setup(_battle_weather)

	# Battlefield backdrop (GID-126): puzzle, scripted and PvP battles carry no
	# world biome and get the neutral roofed-vault look. Fought in place, the
	# world itself is the backdrop — just dim it.
	if in_world:
		($Background as ColorRect).color = Color(0.03, 0.03, 0.06, 0.45)
	else:
		arena._setup_backdrop()

	# Battlefield Resonance UI (GID-059)
	if not _state.puzzle_mode and not _state.scripted_battle:
		arena._add_battlefield_info_label()
		arena._add_slot_highlights()
		arena._show_battlefield_banner.call_deferred()

	AudioManager.play_music("res://assets/audio/music/battle.ogg")

	if not _state.scripted_battle:
		if not SceneManager.save_manager.get_story_flag("tutorial_battle_tip"):
			tutorials._show_battle_tutorial()
		# One popup per battle entry: tap_and_hold on the first, tap_to_cast on
		# the next (GID-119 / TID-452) — both are one-shot via seen flags.
		if SceneManager.save_manager.get_story_flag("seen_tutorial_tap_and_hold"):
			GameBus.tutorial_popup_requested.emit("tap_to_cast")
		else:
			GameBus.tutorial_popup_requested.emit("tap_and_hold")
	else:
		tutorials._maybe_show_scripted_tutorial_step(_state.player_turn_numbers[0])


## Builds an ordinary single-player battle: the player deck (spire draft, saved
## collection, or the starter fallback), equipment and passive-skill effects,
## the opening hand, carried-over hero HP for spire and siege runs, and the
## tier-scaled enemy deck. The networked and scripted modes each build their own
## state above and never reach here.
func _setup_solo_battle() -> void:
	_state = GameState.new()
	_resolver.setup(_state)
	_wire_gamebus_emitter()

	# Player deck: spire run uses its run-local draft deck; otherwise use the
	# persistent player deck. Floor 1 starter gives 8 basics before any pick.
	var player_deck: Array[String] = []
	if SceneManager.save_manager.spire.is_spire_active():
		var draft: Array = SceneManager.save_manager.spire.get_spire_run().get("draft_deck", [])
		if draft.size() > 0:
			player_deck.assign(draft)
		else:
			player_deck = ["ghost", "ghost", "skeleton", "skeleton",
						   "zombie", "zombie", "ghoul", "ghoul"]
	elif SceneManager.save_manager.player_deck.size() > 0:
		# Use per-instance build so rolled stats and rank bonuses apply (GID-060).
		_state.players[0].build_deck_from_instances(SceneManager.save_manager.get_deck_instances())
	else:
		player_deck = ["ghost", "skeleton", "zombie", "ghoul",
					   "ghost", "skeleton", "zombie", "ghoul",
					   "ghost", "skeleton", "zombie", "ghoul"]
	if not player_deck.is_empty():
		var _dark_aligned: bool = CardRegistry.is_dark_aligned()
		_state.players[0].build_deck(player_deck, 0, _dark_aligned)
	modifiers._apply_equipment_effects(_state.players[0])
	modifiers._apply_passive_skills(_state.players[0])
	_state.players[0].draw_opening_hand(4)
	# Spire run: hero HP persists across floors (damage carries over).
	if SceneManager.save_manager.spire.is_spire_active():
		var _spire_hp: int = int(SceneManager.save_manager.spire.get_spire_run().get("hero_hp", 30))
		if _spire_hp > 0:
			_state.players[0].hero.health = mini(_spire_hp, _state.players[0].hero.max_health)
	# Siege gauntlet: hero HP carries over from the previous stage.
	var _siege_state: Dictionary = SceneManager.save_manager.town_siege.get_active_siege()
	if not _siege_state.is_empty():
		var _siege_hp: int = int(_siege_state.get("hero_hp", 30))
		if _siege_hp > 0:
			_state.players[0].hero.health = _siege_hp
			_state.players[0].hero.max_health = _siege_hp

	# Enemy deck — scale card stats by enemy difficulty tier
	var _enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var _enemy_tier: int = EnemyRegistry.get_difficulty_tier(_enemy_type) if _enemy_type != "" else 1
	if bool(enemy_data.get("is_boss", false)):
		_enemy_tier = 4
	# Emboldened Foe gambit: set bonus before build_deck so it is applied to the draw_deck
	# and persists for boss phase-2 rebuild via PlayerState.minion_attack_bonus.
	var _gambit_id: String = str(enemy_data.get("gambit_id", ""))
	if _gambit_id == "emboldened_foe":
		_state.players[1].minion_attack_bonus = 1
	if enemy_data.has("enemy_deck"):
		var enemy_deck: Array[String] = []
		enemy_deck.assign(enemy_data["enemy_deck"])
		_state.players[1].build_deck(enemy_deck, _enemy_tier)
		_state.players[1].draw_opening_hand(4)

	# Boss setup: override enemy hero HP and show name banner
	if bool(enemy_data.get("is_boss", false)):
		var bhp: int = int(enemy_data.get("boss_hp", 0))
		if bhp > 0:
			_state.players[1].hero.health = bhp
			_state.players[1].hero.max_health = bhp
		_result_ui.show_boss_banner(enemy_data)

	# Blighted zone buff: non-blight-heart enemies get +5 HP in blighted chunks.
	if bool(enemy_data.get("is_blighted", false)) and not enemy_data.has("blight_heart_id"):
		_state.players[1].hero.health += 5
		_state.players[1].hero.max_health += 5
		GameBus.hud_message_requested.emit("The blight empowers your foe…")

	# Apply remaining gambit handicaps now that all decks and HP are set.
	modifiers._apply_gambit_handicaps(_gambit_id)
	# World-encounter ambush modifiers (GID-113 / TID-421, TID-422).
	modifiers._apply_ambush_modifiers(enemy_data)

	# start_turn draws 1 card + bonus_draw (from passive_draw skills/equipment).
	# bonus_mana (from passive_mana skills) was set above, so gain_mana_for_turn
	# already uses it: max_mana = mini(10, 1 + bonus_mana).
	_state.players[0].start_turn(1)
	# Attuned buff (GID-068): +1 mana on turn 1 when engaged on a ley line.
	if bool(enemy_data.get("player_attuned", false)):
		_state.players[0].hero.gain_mana(1, true)
		GameBus.hud_message_requested.emit("Attuned: +1 mana this turn.")
	if duel_wager > 0:
		_state.friendly_duel = true
		_state.wager_coins = duel_wager

	# Apply weather modifiers (only in infinite world)
	_battle_weather = WeatherManager.current_weather if SceneManager.save_manager.current_map == "main" else ""
	modifiers._apply_weather_battle_init()

	# Battlefield Resonance context (GID-059): stamp biome + is_night into GameState.
	var _bf_biome: int = int(enemy_data.get("battlefield_biome", -1))
	var _bf_night: bool = bool(enemy_data.get("battlefield_is_night", false))
	_state.set_battlefield_context(_bf_biome, _bf_night)

	# Companion passive: battle-start effects (extra_mana, hero_armor) and
	# first turn-start draw (draw_card). Excluded in puzzle and duel modes.
	modifiers._apply_companion_battle_start(_state.players[0])
	modifiers._apply_companion_turn_start()
	# Flush auto-resolve spells collected from opening hand + turn-1 draw.
	# Must run after enemy deck is built so spells target the real enemy.
	_resolver.flush_auto_spells(0)

	_bind_state()

## Points every helper that caches the GameState at the current `_state`. Call it
## whenever `_state` is replaced (GID-040 pattern): the resolver applies effects to
## it, and BattleFx / CardViewBuilder render from it by view seat.
func _bind_state() -> void:
	_resolver.setup(_state)
	_fx.set_game_state(_state, _seat_idx)
	_view.set_battle_state(_state, enemy_data, _seat_idx)

## View seat → `_state.players` index: seat 0 is the local player, seat 1 the
## opponent shown on the enemy side (`_opp_idx`, which follows co-op boss and
## team-duel focus).
func _seat_idx(seat: int) -> int:
	if _my_idx() < 0:
		return seat  # headless referee has no local side: keep canonical order
	return _my_idx() if seat == 0 else _opp_idx()

func _wire_gamebus_emitter() -> void:
	_state.inject_gamebus_emitter(func(pid: int, dmg: int) -> void:
		GameBus.fatigue_damage.emit(pid, dmg))


## Wraps player.play_card() with snow first-card cost discount.
## Returns true if the card was played.
func _do_play_card(card: CardInstance, player_idx: int) -> bool:
	var apply_discount: bool = (
		(_battle_weather == "snow" or _battle_weather == "blizzard") and
		not _snow_discount_used[player_idx]
	)
	var ok: bool
	if apply_discount:
		var saved_cost: int = card.cost
		card.cost = maxi(0, card.cost - 1)
		ok = _state.players[player_idx].play_card(card)
		card.cost = saved_cost
		if ok:
			_snow_discount_used[player_idx] = true
	else:
		ok = _state.players[player_idx].play_card(card)
	if ok:
		GameBus.card_played.emit(card.template_id, "spell", -1)
		realtime.note_player_play(player_idx)
	return ok

## Font size helper: pct of viewport height × the "text_scale" setting.
func _font(pct: float) -> int:
	return int(_vh * pct * _text_scale)

func _apply_ui_sizes() -> void:
	# Co-op PvE and team PvP draw an ally status bar across the top of the
	# screen (PRESET_TOP_WIDE, 8% vh) — reserve that band and compress the rest.
	var top_bar: bool = _coop_pve or _team_pvp
	if top_bar:
		_view.set_card_scale(0.85)
	var hero_h: float = _vh * (0.08 if top_bar else 0.10)
	var board_h: float = _vh * (0.22 if top_bar else 0.27)
	# The enemy hand row (face-down card backs) is collapsed on all layouts —
	# the count is shown on the enemy hero panel instead (GID-119 / TID-448).
	# In top-bar modes it stays visible as an empty spacer under the bar.
	_enemy_hand_view.visible = top_bar
	_enemy_hand_view.custom_minimum_size   = Vector2(0, _vh * 0.085 if top_bar else 0.0)
	_enemy_hero_view.custom_minimum_size   = Vector2(0, hero_h)
	_enemy_board_view.custom_minimum_size  = Vector2(0, board_h)
	_player_board_view.custom_minimum_size = Vector2(0, board_h)
	_player_hero_view.custom_minimum_size  = Vector2(0, hero_h)
	_player_hand_view.custom_minimum_size  = Vector2(0, _vh * (0.20 if top_bar else 0.24))
	# Centre the board slots horizontally
	if _enemy_board_view is BoxContainer:
		(_enemy_board_view as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	if _player_board_view is BoxContainer:
		(_player_board_view as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	# Side panel buttons — large, easy to tap on mobile
	_end_turn_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.10)
	_end_turn_btn.add_theme_font_size_override("font_size", _font(0.035))
	_menu_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.07)
	_menu_btn.add_theme_font_size_override("font_size", _font(0.028))
	# One system control in battle (GID-120 / TID-457): the pause menu already
	# carries Return to Menu / Flee / Settings, so the dedicated Menu button is
	# redundant chrome. Wiring stays intact; only visibility changes.
	_menu_btn.visible = false
	_turn_label.add_theme_font_size_override("font_size", _font(0.022))
	_mana_label.add_theme_font_size_override("font_size", _font(0.022))
	($SidePanel as VBoxContainer).add_theme_constant_override("separation", int(_vh * 0.025))
	# Keep the side-panel controls out of display cutouts (GID-120 / TID-455).
	var ins: Dictionary = _UiUtil.safe_insets(get_viewport())
	($SidePanel as Control).offset_right = -float(ins.get("right", 0.0))

# -------------------------------------------------------------------------
# First-battle tutorial overlay
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Drag/Drop — native Godot drag-and-drop API (mouse + touch transparent)
# -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
				return  # overlay handles its own Escape
			if not _dragged_card.is_empty():
				card_input.clear_attacker_selection()
				get_viewport().set_input_as_handled()
				return
			_pause_ui.toggle()
			get_viewport().set_input_as_handled()


# ── Co-op ally targeting (GID-100) ───────────────────────────────────────────
# Ally-targeted spells (ally_heal_hero, ally_revive, etc.) need the local player
# to tap one of the compact ally panels to choose which ally to benefit.


# -------------------------------------------------------------------------
# Card inspect overlay (TID-086)
# -------------------------------------------------------------------------

func _show_card_inspect(card: CardInstance) -> void:
	if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
		return
	var overlay: CardInspectOverlay = CardInspectOverlay.new()
	overlay.mana_scale = _state.players[_my_idx()].hero.mana_scale
	overlay.present(self, card, func() -> void: _inspect_overlay = null)
	_inspect_overlay = overlay

# -------------------------------------------------------------------------
# Battle pause (TID-088)
# -------------------------------------------------------------------------


func _make_battle_save() -> Dictionary:
	var d: Dictionary = _state.to_dict()
	d["_boss_phase2"] = _boss_phase2_triggered
	d["_hero_power_used"] = _hero_power_used
	return d

func _bump_card_next_id(state: GameState) -> void:
	var max_id: int = CardInstance._next_id
	for p: PlayerState in state.players:
		for c: CardInstance in p.hand:
			var parts := c.instance_id.split("_")
			if parts.size() >= 2:
				var n: int = int(parts[-1])
				if n > max_id:
					max_id = n
		for c: CardInstance in p.board.get_cards():
			var parts := c.instance_id.split("_")
			if parts.size() >= 2:
				var n: int = int(parts[-1])
				if n > max_id:
					max_id = n
		for c: CardInstance in p.draw_deck:
			var parts := c.instance_id.split("_")
			if parts.size() >= 2:
				var n: int = int(parts[-1])
				if n > max_id:
					max_id = n
		for c: CardInstance in p.discard:
			var parts := c.instance_id.split("_")
			if parts.size() >= 2:
				var n: int = int(parts[-1])
				if n > max_id:
					max_id = n
	CardInstance._next_id = max_id

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _state != null and not _state.puzzle_mode and not _pvp and not _state.is_game_over():
			SceneManager.save_manager.set_pending_battle_state(_make_battle_save())
			SceneManager.save_manager.save()
		if _pause_ui != null and not _pause_ui.is_paused():
			_pause_ui.show_pause()
	elif what == NOTIFICATION_DRAG_END:
		# Native drag ended (dropped outside any drop zone, cancelled, or a
		# successful drop — this notification fires in all three cases).
		# Clear the slot-highlight state that was set when the drag started,
		# and restore the source hand panel's lift-dim (TID-429) — a
		# successful play already hides that panel separately
		# (_hide_hand_panel), so restoring modulate here is harmless either
		# way and the next _refresh_all() would reset it regardless
		# (update_card_view() always resets modulate/visible/scale on reuse).
		if _hand_drag_card != null:
			var dragged_panel: Control = _hand_panel_node(_hand_drag_card)
			if dragged_panel != null and is_instance_valid(dragged_panel):
				dragged_panel.modulate.a = 1.0
			_hand_drag_card = null
			_refresh_player_board()


func _make_card_ghost(card: CardInstance) -> PanelContainer:
	var panel := _make_card_view(card, "ghost")
	panel.modulate.a = 0.75
	# Fixed size already set inside _make_card_view
	return panel

## Finds `card`'s current panel in the local player's hand row by hand-array
## index (hand panels carry no per-card meta, unlike board slots). Must be
## called before the card is removed from hand (state mutation).
func _hand_panel_node(card: CardInstance) -> Control:
	var idx: int = _state.players[_my_idx()].hand.find(card)
	var children := _player_hand_view.get_children()
	if idx < 0 or idx >= children.size():
		return null
	return children[idx] as Control

## Hides the stale hand panel immediately once a card has left hand for the
## board, so the travel ghost doesn't read as a duplicate card until the next
## `_refresh_all()` rebuild frees it.
func _hide_hand_panel(panel: Control) -> void:
	if panel != null and is_instance_valid(panel):
		panel.visible = false

## Global center of the (possibly still-empty) slot panel at `slot_idx` in
## `zone_view` — stable regardless of whether the slot is filled yet.
func _slot_panel_center(zone_view: Node, slot_idx: int) -> Vector2:
	for child in zone_view.get_children():
		if child is Control and int(child.get_meta("slot_idx", -1)) == slot_idx:
			return (child as Control).get_global_rect().get_center()
	return (zone_view as Control).get_global_rect().get_center()

## Ghost-tweens a card from its hand position to its new board slot so playing
## a minion reads as a placement instead of a teleport (TID-426). `from_rect`
## must be captured before `_do_play_card_at_slot` mutates hand/board state.
func _animate_card_travel(card: CardInstance, from_rect: Rect2, to_pos: Vector2) -> void:
	if _fx != null:
		_fx.mark_board_seen(card)  # the ghost is its entrance; no pop-in on top
	if _float_layer == null or not is_instance_valid(_float_layer):
		return
	if from_rect.size == Vector2.ZERO:
		return
	var ghost: PanelContainer = _make_card_ghost(card)
	ghost.position = from_rect.position
	ghost.size = from_rect.size
	ghost.pivot_offset = from_rect.size * 0.5
	ghost.scale = Vector2(0.85, 0.85)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(ghost)
	var dur: float = BattleFx.scaled_duration(0.2, _speed_scale)
	var tw: Tween = ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "position", to_pos - from_rect.size * 0.5,
			dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(1.0, 1.0), dur)
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()

# -------------------------------------------------------------------------
# UI Refresh
# -------------------------------------------------------------------------

func _refresh_all() -> void:
	if _local_player_idx < 0:
		return  # dedicated-server referee: no rendering
	_view.update_context(
		_targeting_active, _targeting_friendly,
		_dragged_card, _hand_drag_card,
		_slot_targeting_spell, _slot_select_card
	)
	_view.refresh_board_zone(_enemy_board_view, _state.players[_opp_idx()].board, "enemy_board")
	_view.refresh_board_zone(_player_board_view, _state.players[_my_idx()].board, "board")
	_view.refresh_zone(_player_hand_view, _state.players[_my_idx()].hand, "hand")
	_view.refresh_hero(_enemy_hero_view, _state.players[_opp_idx()].hero, true,
		_state.players[_opp_idx()].hand.size())
	_view.refresh_hero(_player_hero_view, _state.players[_my_idx()].hero, false)
	_update_status()
	if _fx != null:
		_fx.pop_new_board_cards()  # GID-132 / TID-512
	if _coop_pve:
		arena._refresh_coop_ally_panels()
	if _team_pvp:
		battle_net._refresh_team_panels()
	if realtime != null:
		realtime.refresh_extra_views()  # enemies that joined a real-time fight

func _refresh_player_board() -> void:
	if _local_player_idx < 0:
		return
	_view.update_context(
		_targeting_active, _targeting_friendly,
		_dragged_card, _hand_drag_card,
		_slot_targeting_spell, _slot_select_card
	)
	_view.refresh_board_zone(_player_board_view, _state.players[_my_idx()].board, "board")
	_fx.pop_new_board_cards()


func _make_card_view(card: CardInstance, zone_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = _view.card_size()
	# Prevent HBoxContainer from expanding cards horizontally beyond minimum_size.
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if zone_id == "enemy_hand":
		var back_style := _UiUtil.make_style(Color(0.15, 0.10, 0.28), 4)
		panel.add_theme_stylebox_override("panel", back_style)
		panel.set_meta("is_card_back", true)
		return panel
	var is_board_zone: bool = (zone_id == "board" or zone_id == "enemy_board")
	panel.add_child(_view.build_card_vbox(card, is_board_zone))
	var style: StyleBoxFlat = CardViewBuilder.attach_card_style(panel)
	_view.apply_card_style(panel, card, zone_id)
	card_input._bind_card_input(panel, card, zone_id)
	if zone_id == "hand" and card.dual_card_id != "" and not _flipped_dual_ids.has(card.instance_id):
		_flipped_dual_ids[card.instance_id] = true
		_trigger_dual_face_flip(panel)
	return panel

func _trigger_dual_face_flip(panel: PanelContainer) -> void:
	panel.pivot_offset = Vector2(panel.custom_minimum_size.x * 0.5, panel.custom_minimum_size.y * 0.5)
	panel.scale = Vector2(0.01, 1.0)
	var tween := panel.create_tween()
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_status() -> void:
	if _local_player_idx < 0:
		return  # referee: no UI to update
	var player := _state.players[_my_idx()]
	_turn_label.text = "Turn %d" % _state.turn_number
	_mana_label.text = "Mana: %d/%d" % [player.hero.mana, player.hero.max_mana]
	_end_turn_btn.disabled = _state.current_player_idx != _my_idx() or _ai_thinking or _action_busy

# -------------------------------------------------------------------------
# Input handlers
# -------------------------------------------------------------------------


## Diff-based death animation: any non-hero id present in `snap` but no
## longer among the currently-alive board cards gets a death beat before the
## next `_refresh_all()` rebuilds the zone out from under it. Shared by the
## player-attack path and the AI-turn loop.
func _animate_deaths_from_snapshot(snap: Array[Dictionary]) -> void:
	var alive_ids: Array[String] = []
	for i in range(2):
		for c: CardInstance in _state.players[i].board.get_cards():
			alive_ids.append(c.instance_id)
	var dead_ids: Array[String] = BattleFx.detect_deaths(snap, alive_ids)
	if dead_ids.is_empty():
		return
	var anims: Array[Tween] = []
	for entry: Dictionary in snap:
		var eid: String = str(entry["id"])
		if not dead_ids.has(eid):
			continue
		var panel: Control = _fx.find_panel_by_snapshot_entry(entry)
		if panel != null:
			var tw: Tween = _fx.animate_death(panel, _speed_scale)
			if tw != null:
				anims.append(tw)
	for tw: Tween in anims:
		await tw.finished

# -------------------------------------------------------------------------
# Turn / AI
# -------------------------------------------------------------------------

func _on_end_turn() -> void:
	if not _can_local_act():
		return
	_hand_drag_card = null
	_dragged_card.clear()
	if _state.puzzle_mode:
		if not _state.is_game_over():
			_show_puzzle_fail()
		return
	if _is_pvp_client():
		_send_intent(BattleNetProtocol.encode_end_turn())
		return
	_state.end_turn()

func _on_turn_ended(player_idx: int) -> void:
	GameBus.turn_ended.emit(player_idx)
	var snap_sot := _fx.snapshot()
	_fx.process_start_of_turn_statuses(player_idx)
	# Desert biome rule: leftmost minion on each board takes 1 damage at turn start (daytime only).
	if _state.battlefield_biome == BattlefieldRules.BIOME_DESERT and not _state.is_night:
		modifiers._apply_desert_scorch()
	# Grow snow-discount tracking array to match player count.
	while _snow_discount_used.size() <= player_idx:
		_snow_discount_used.append(false)
	_snow_discount_used[player_idx] = false
	if _battle_weather == "blizzard" and _state.turn_number <= 2:
		for card: CardInstance in _state.players[player_idx].board.get_cards():
			card.apply_status("freeze", 1)
	_fx.trigger_fx(snap_sot)
	_refresh_all()

	# Co-op PvE: boss turn handled by authority only; ally turns handled locally.
	if _coop_pve:
		var boss_idx: int = _state.players.size() - 1
		if player_idx == _my_idx():
			# Local ally's turn just ended — buttons already disabled by end_turn().
			consumables._refresh_potion_button()
			_check_game_over()
			if not _state.is_game_over():
				AudioManager.play_sfx("card_draw")
				modifiers._apply_companion_turn_start()
				var snap_coop := _fx.snapshot()
				_resolver.flush_auto_spells(player_idx)
				_fx.trigger_fx(snap_coop)
				_refresh_all()
				_check_game_over()
		elif player_idx == boss_idx:
			# Boss turn — run AI only on the authority.
			if _potion_btn != null:
				_potion_btn.disabled = true
			_check_game_over()
			if _is_pvp_host() and not _state.is_game_over() and not _state.puzzle_mode:
				_run_ai_turn()
		# Non-local ally turn: just refresh (no local action, no companion draw).
		# (Fall through — _refresh_all was called above.)
		return

	if player_idx == 0:
		consumables._refresh_potion_button()
		_check_game_over()
		if not _state.is_game_over():
			AudioManager.play_sfx("card_draw")
			modifiers._apply_companion_turn_start()
			var snap_as := _fx.snapshot()
			_resolver.flush_auto_spells(0)
			_fx.trigger_fx(snap_as)
			_refresh_all()
			_check_game_over()
			if _state.scripted_battle:
				tutorials._maybe_show_scripted_tutorial_step(_state.player_turn_numbers[0])
	elif player_idx == 1:
		if _potion_btn != null:
			_potion_btn.disabled = true
		_check_game_over()
		# PvP: the opponent is a remote human; never run the AI. Their turn advances
		# via relayed intents (host applies them). _check_game_over above already
		# broadcast the post-turn state to the client.
		if _pvp:
			return
		if not _state.is_game_over() and not _state.puzzle_mode:
			if _resolver.extra_turn_granted:
				_resolver.extra_turn_granted = false
				_state.end_turn()
			else:
				_run_ai_turn()

func _on_fatigue_damage(pid: int, dmg: int) -> void:
	var is_enemy: bool = (pid == 1)
	var pos: Vector2 = _fx.pos_of_hero(is_enemy)
	var lbl := _UiUtil.make_label("Fatigue! -%d" % dmg, int(_font(0.025)))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0))
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = pos - Vector2(40.0, 10.0)
	if _float_layer != null and is_instance_valid(_float_layer):
		_float_layer.add_child(lbl)
		var tw: Tween = lbl.create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "position:y", pos.y - 60.0, 1.5)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.5)
		tw.chain().tween_callback(lbl.queue_free)
	_refresh_all()
	_check_game_over()

func _battle_delay(base: float) -> void:
	await get_tree().create_timer(base * _speed_scale, false).timeout

func _run_ai_turn() -> void:
	_ai_thinking = true
	_end_turn_btn.disabled = true
	# GID-112: persona + difficulty tier are looked up from EnemyRegistry (not
	# stored in enemy_data) so every AI-driven battle — regular fights,
	# duelists, rivals, martarquas, mimic, co-op siege boss — picks up the
	# right persona/tier from a single source of truth. Empty/unknown
	# enemy_type falls back to "basic"/tier 1 (EnemyRegistry defaults), so
	# this stays safe if ever reached with an empty enemy_data.
	var ai_enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var ai_persona: String = EnemyRegistry.get_ai_persona(ai_enemy_type)
	var ai_tier: int = EnemyRegistry.get_difficulty_tier(ai_enemy_type)
	var actions := BasicAI.decide_turn(_state, ai_persona)
	_fx.show_intent_banner(BasicAI.describe_turn(_state, ai_persona, ai_tier))
	await _battle_delay(_BattlePacing.AI_THINK)
	_execute_ai_actions(actions, 0)

func _execute_ai_actions(actions: Array[Callable], idx: int) -> void:
	if _state.is_game_over():
		_fx.hide_intent_banner()
		_ai_thinking = false
		_check_game_over()
		return
	if idx >= actions.size():
		_fx.hide_intent_banner()
		await _battle_delay(_BattlePacing.AI_TURN_TAIL)
		_ai_thinking = false
		_state.end_turn()
		_refresh_all()
		_check_game_over()
		return
	AudioManager.play_sfx("attack")
	var snap_ai := _fx.snapshot()
	# BID-027: the AI's own index — 1 for solo/2-player battles, but the boss's
	# actual index (players.size() - 1, always >= 2) for co-op PvE. `_run_ai_turn`
	# only ever runs on the host authority with `_local_player_idx == 0`, so
	# `_opp_idx()` ("the local player's opponent") already resolves to exactly
	# this: 1 in solo/2-player, the boss slot in co-op PvE. Reuses the same
	# accessor BID-026 established for `_execute_attack`/`_apply_remote_intent`
	# rather than re-deriving the co-op/solo branch locally.
	var ai_idx: int = _opp_idx()
	var ai_board_before: Array[CardInstance] = _state.players[ai_idx].board.get_cards().duplicate()
	actions[idx].call()
	_resolver.flush_auto_spells(ai_idx)
	for c: CardInstance in _state.players[ai_idx].board.get_cards():
		if not ai_board_before.has(c):
			_resolver.resolve_emergence(c, ai_idx)
			modifiers._apply_weather_to_summoned(c, ai_idx)
	_fx.trigger_fx(snap_ai)
	await _animate_deaths_from_snapshot(snap_ai)
	_refresh_all()
	if _state.is_game_over():
		_check_game_over()
		return
	await _battle_delay(_BattlePacing.AI_ACTION_GAP)
	_execute_ai_actions(actions, idx + 1)

func _check_boss_phase2() -> void:
	if _boss_phase2_triggered:
		return
	if not bool(enemy_data.get("is_boss", false)):
		return
	var p2_raw: Array = enemy_data.get("phase2_deck", [])
	if p2_raw.is_empty():
		return
	var enemy_hero := _state.players[1].hero
	if enemy_hero.health > enemy_hero.max_health / 2:
		return
	_boss_phase2_triggered = true
	var p2_deck: Array[String] = []
	p2_deck.assign(p2_raw)
	var p2_enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var p2_tier: int = 4 if bool(enemy_data.get("is_boss", false)) else EnemyRegistry.get_difficulty_tier(p2_enemy_type)
	_state.players[1].build_deck(p2_deck, p2_tier)
	_state.players[1].draw_opening_hand(4)
	_refresh_all()
	_result_ui.show_phase2_banner()

## The sound + haptic every battle outcome plays, win or lose.
func _play_outcome_feedback(did_win: bool) -> void:
	AudioManager.play_sfx("battle_win" if did_win else "battle_lose")
	_fx.haptic(120 if did_win else 80)

func _check_game_over() -> void:
	if _pvp:
		battle_net._pvp_check_game_over()
		return
	if _coop_pve:
		battle_net._coop_pve_check_game_over()
		return
	if _team_pvp:
		battle_net._team_check_game_over()
		return
	_check_boss_phase2()
	if _game_over_handled:
		return
	if _state.is_game_over():
		_game_over_handled = true
		var w := _state.winner()
		if _state.puzzle_mode:
			if w == 0:
				_play_outcome_feedback(true)
				_show_puzzle_victory()
			return
		if _state.scripted_battle:
			var scripted_id: String = _state.scripted_battle_id
			_play_outcome_feedback(w == 0)
			_result_ui.show_scripted_result(w == 0, scripted_id)
			return
		GameBus.battle_ended.emit(w)
		if _ghost_duel:
			_play_outcome_feedback(w == 0)
			_result_ui.show_ghost_duel_result(w == 0, _ghost_duel_reward)
			return
		if _state.friendly_duel:
			if w == 0:
				_play_outcome_feedback(true)
				_result_ui.show_duel_victory(_state.wager_coins)
			else:
				_play_outcome_feedback(false)
				_result_ui.show_duel_loss(_state.wager_coins)
			# gdlint:ignore = max-returns
			return
		if w == 0:
			_play_outcome_feedback(true)
			_show_standard_victory()
		else:
			_play_outcome_feedback(false)
			GameBus.battle_lost.emit()

## Rolls and presents the reward screen for an ordinary (non-puzzle, non-scripted,
## non-ghost, non-friendly) win. Boss fights drop the whole pool plus a weapon;
## everything else drops one card, with the soulbind capture check on top.
func _show_standard_victory() -> void:
	var enemy_type: String = str(enemy_data.get("enemy_type", "undead_basic"))
	var is_boss_win: bool = bool(enemy_data.get("is_boss", false))
	var gambit_id_win: String = str(enemy_data.get("gambit_id", ""))
	var pool: Array[String] = EnemyRegistry.get_drop_pool(enemy_type)
	# Compute drop tier here so the overlay can display the rolled rarity.
	var drop_tier_win: int = EnemyRegistry.get_difficulty_tier(enemy_type) if enemy_type != "" else 1
	if is_boss_win:
		drop_tier_win = 4
	elif EnemyRegistry.get_night_drop_boost(enemy_type):
		drop_tier_win = mini(drop_tier_win + 1, 4)
	drop_tier_win = mini(drop_tier_win + Gambits.get_rarity_tier_bonus(gambit_id_win), 4)
	var coins_win: int = EnemyRegistry.get_coin_reward(enemy_type) if enemy_type != "" else 0
	var xp_win: int = EnemyRegistry.get_xp_reward(enemy_type, is_boss_win)
	var hero_hp_win: int = _state.players[0].hero.health
	var currency_win: Dictionary = _state.players[0].cross_currency_earned()
	if is_boss_win:
		var weapon_pool: Array[String] = []
		for pid in pool:
			if WeaponRegistry.has_weapon(pid):
				weapon_pool.append(pid)
		if weapon_pool.is_empty():
			var all_ids: Array[String] = WeaponRegistry.get_all_ids()
			var owned_w: Array[String] = SceneManager.save_manager.get_owned_by_slot("weapon")
			for wid in all_ids:
				if not owned_w.has(wid):
					weapon_pool.append(wid)
		var weapon_reward_id: String = ""
		if not weapon_pool.is_empty():
			weapon_reward_id = weapon_pool[randi() % weapon_pool.size()]
		# Pre-roll rarities for all boss reward cards.
		var boss_rarities: Array[String] = []
		var boss_stats_list: Array[Dictionary] = []
		for cid: String in pool:
			var br: String = CardDropUtil.effective_rarity(cid, CardDropUtil.roll_rarity(drop_tier_win))
			boss_rarities.append(br)
			boss_stats_list.append(CardDropUtil.roll_stats(cid, br))
		_result_ui.show_victory_boss(pool, weapon_reward_id, boss_rarities, boss_stats_list, coins_win, xp_win,
				hero_hp_win, currency_win)
	else:
		var reward_card_id: String = ""
		if pool.size() > 0:
			reward_card_id = pool[randi() % pool.size()]
		# Pre-roll rarity for the card reward.
		var rolled_rarity: String = ""
		var rolled_stats: Dictionary = {}
		if reward_card_id != "":
			rolled_rarity = CardDropUtil.effective_rarity(reward_card_id, CardDropUtil.roll_rarity(drop_tier_win))
			rolled_stats = CardDropUtil.roll_stats(reward_card_id, rolled_rarity)
		# Check soulbind capture condition.
		var _ct_sig: String = EnemyRegistry.get_signature_card(enemy_type)
		var _ct_captured: bool = SceneManager.save_manager.is_signature_captured(_ct_sig)
		var _ct_met: bool = _capture_tracker != null and not _ct_sig.is_empty() and _capture_tracker.is_satisfied(_state)
		if not _ct_sig.is_empty() and not _ct_captured and _ct_met:
			_result_ui.show_soulbind(reward_card_id, _ct_sig, _capture_tracker.condition_text(), hero_hp_win,
					currency_win, rolled_rarity, rolled_stats)
		elif not _ct_sig.is_empty() and not _ct_captured:
			var _ct_text: String = _capture_tracker.condition_text() if _capture_tracker != null else ""
			_result_ui.show_victory(reward_card_id, "", _ct_sig, _ct_text, false, rolled_rarity, rolled_stats,
					coins_win, xp_win, hero_hp_win, currency_win)
		else:
			_result_ui.show_victory(reward_card_id, "", "", "", false, rolled_rarity, rolled_stats, coins_win, xp_win,
					hero_hp_win, currency_win)
		# First-session soulbinding teaser (GID-117): explain the hunt line the
		# first time an uncaptured signature surfaces on a victory screen.
		if not _ct_sig.is_empty() and not _ct_captured:
			GameBus.tutorial_popup_requested.emit("soulbinding")

func _collect_veterancy_data() -> Dictionary:
	var data: Dictionary = {}
	var player: PlayerState = _state.players[0]
	var all_cards: Array[CardInstance] = []
	all_cards.append_array(player.hand)
	all_cards.append_array(player.board.get_cards())
	all_cards.append_array(player.draw_deck)
	all_cards.append_array(player.discard)
	all_cards.append_array(player.pending_auto_spells)
	for card: CardInstance in all_cards:
		if card.collection_uid == "":
			continue
		var uid: String = card.collection_uid
		if not data.has(uid):
			data[uid] = {"kills": 0, "survived": true}
		data[uid]["kills"] = int(data[uid]["kills"]) + card.battle_kills
	return data

# -------------------------------------------------------------------------
# Puzzle overlays
# -------------------------------------------------------------------------

func _show_puzzle_fail() -> void:
	_state = GameState.new()
	_state.load_puzzle(_puzzle_data_ref)
	_bind_state()
	_wire_gamebus_emitter()
	_refresh_all()
	var pd: Resource = _puzzle_data_ref
	var hint_text: String = pd.get("hint_text") if pd != null else ""
	_result_ui.show_puzzle_fail_overlay(hint_text)


func _show_puzzle_victory() -> void:
	GameBus.puzzle_solved.emit(_state.puzzle_data_id)
	_result_ui.show_puzzle_victory_overlay()


func _on_puzzle_give_up() -> void:
	SceneManager.return_from_puzzle()

# -------------------------------------------------------------------------
# Battlefield Resonance (GID-059)
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# PvP Card Battles (GID-091)
#
# Host-authoritative state mirroring. The co-op host owns the one canonical
# GameState (players[0] = host, players[1] = client). The client never simulates:
# it sends intents over BattleNetSync and renders the broadcast mirror from its
# own perspective (_local_player_idx == 1). All of this is guarded by `_pvp`; in
# single-player _local_player_idx == 0, so the perspective accessors are no-ops.
# -------------------------------------------------------------------------

## Index of the local player in the canonical state (host = 0, client = 1).
func _my_idx() -> int:
	return _local_player_idx

## Index of the opponent in the canonical state.
## In co-op PvE, the local ally's opponent is always the boss (last player slot).
## In team PvP, the opponent is the manually focused enemy-team member if one is
## set and still alive, else the auto-picked lowest-HP enemy-team member
## (GameState.opponent_idx()). Every existing render/target-building call site
## already routes through this accessor, so manual focus propagates for free.
func _opp_idx() -> int:
	if _coop_pve and _state != null and _state.players.size() > 2:
		return _state.players.size() - 1
	if _team_pvp and _state != null and _state.team_battle:
		var f: int = _team_focus_target_pidx
		if f >= 0 and f < _state.players.size() \
				and f < _state.player_teams.size() and _local_player_idx < _state.player_teams.size() \
				and _state.player_teams[f] != _state.player_teams[_local_player_idx] \
				and _state.players[f].hero.is_alive():
			return f
		return _state.opponent_idx()
	return 1 - _local_player_idx

## True when this peer owns the canonical simulation: ENet host in any mode
## (listen-server host/player-0 or dedicated-server referee).
## Uses self.multiplayer (resolved to the node's own SceneMultiplayer subtree)
## so it works correctly both in production and in smoke tests that register
## custom multiplayer instances via set_multiplayer().
func _is_pvp_host() -> bool:
	return (_pvp or _coop_pve or _team_pvp) and multiplayer.is_server()

## True when this peer is a thin client renderer (never the ENet host).
## Also true for co-op PvE ally clients.
func _is_pvp_client() -> bool:
	return (_pvp or _coop_pve or _team_pvp) and not multiplayer.is_server()


## True when local input is allowed: it's our turn, AI/round-trip not pending,
## and we have a local player (not the headless referee, _local_player_idx = -1).
## `ignore_gcd`: Ally attack commands are off the real-time global cooldown.
func _can_local_act(ignore_gcd: bool = false) -> bool:
	if _pvp_spectating:
		return false  # spectators never act
	if _local_player_idx < 0:
		return false  # dedicated-server referee has no local player
	if _ai_thinking or _action_busy or (not ignore_gcd and realtime != null and realtime.on_cooldown()):
		return false  # busy, or on the real-time global cooldown (TID-546)
	if _state == null:
		return false
	if _is_pvp_client() and _pvp_pending:
		return false
	return _state.current_player_idx == _my_idx()

## Builds the relay node + canonical state for a PvP battle. Host builds both
## decks and starts turn 1; the client waits for the first sync_state mirror.
## If _pvp_spectating is true, we skip simulation entirely and only receive mirrors.


func _send_intent(payload: Dictionary) -> void:
	if _net != null:
		_pvp_pending = true
		var rpc_name: String = "send_intent"
		if _coop_pve:
			rpc_name = "send_coop_intent"
		elif _team_pvp:
			rpc_name = "send_team_intent"
		_net.rpc_id(1, rpc_name, payload)


## Applies the game-state portion of a potion to player_idx (no inventory I/O —
## the acting peer already consumed it from its own SaveManager).


