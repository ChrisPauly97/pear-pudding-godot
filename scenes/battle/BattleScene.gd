extends Control

const GameState = preload("res://game_logic/battle/GameState.gd")
const BasicAI = preload("res://ai/BasicAI.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")
const CompanionRegistry = preload("res://autoloads/CompanionRegistry.gd")
const CompanionData = preload("res://data/CompanionData.gd")
const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
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
const CardViewBuilder = preload("res://scenes/battle/CardViewBuilder.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const BattlePauseUI = preload("res://scenes/battle/BattlePauseUI.gd")
const BattleResultUI = preload("res://scenes/battle/BattleResultUI.gd")
const BattleNetProtocol = preload("res://game_logic/net/BattleNetProtocol.gd")
const _BattleNetSyncScript = preload("res://scenes/battle/BattleNetSync.gd")

var _fx: BattleFx
var _view: CardViewBuilder
var _resolver: SpellEffectResolver
var _pause_ui: BattlePauseUI
var _result_ui: BattleResultUI

var enemy_data: Dictionary = {}
var duel_wager: int = 0
var puzzle_data: Resource = null  # PuzzleData set by SceneManager before _ready

# ── PvP card battles (GID-091 + GID-097) ─────────────────────────────────────
# All inert unless SceneManager sets _pvp = true before _ready. Single-player,
# NPC duel, puzzle and Spire battles never touch any of this.
var _pvp: bool = false
var _local_player_idx: int = 0       # 0 = host/challenger, 1 = client, -1 = server referee
var _net: Node = null                # BattleNetSync relay, added under this scene
var _state_seq: int = 0              # host: monotonic broadcast counter
var _last_applied_seq: int = -1      # client: last mirror seq applied
var _pvp_pending: bool = false       # client: waiting on host ack of last action
var _pvp_ended: bool = false         # guard so the result fires once
# Listen-server: client deck relayed in challenge handshake (host builds players[1]).
var pvp_opponent_deck: Array = []
# Dedicated-server referee (GID-097 / TID-353): both player decks come from clients.
var pvp_player0_deck: Array = []
var pvp_player1_deck: Array = []
var _pvp_peer_to_idx: Dictionary = {}  # peer_id (int) → player_idx (int), referee only

# ── Duel spectating (GID-101 / TID-367) ──────────────────────────────────────
# A spectator enters BattleScene with _pvp_spectating = true. They receive state
# mirrors from the host but never send any intents. Input is fully blocked.
# The host tracks spectator peer_ids in _spectators and fans sync_state to them.
var _pvp_spectating: bool = false
var _spectators: Array[int] = []      # host only: peer_ids watching this duel

# Wager (GID-101 / TID-368): ante_coins for the current PvP duel; 0 = unwagered.
# The host reads this to include wager info in the pvp_ended payload.
var pvp_ante_coins: int = 0

# Ranked opt-in (GID-102 / TID-373): set by SceneManager.enter_pvp_battle before
# _ready. When true, _state.ranked is set so WorldScene knows to run the TID-370
# ELO rating update on battle end (gated in WorldScene, not here).
var pvp_ranked: bool = false

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
var _coop_peer_to_idx: Dictionary = {}
var _coop_ended: bool = false  # guard so the result fires once

# Weather modifier state — determined once at battle start
var _battle_weather: String = ""  # "" if no infinite-world weather applies
var _snow_discount_used: Array[bool] = [false, false]  # per-player first-card discount
var _puzzle_data_ref: Resource = null  # retained for reset
var _give_up_btn: Button = null
var _companion_hud: Control = null
var _state: GameState
var _ai_thinking: bool = false
var _game_over_handled: bool = false
var _boss_phase2_triggered: bool = false
var _hero_power_btn: Button = null
var _hero_power_used: bool = false
var _potion_btn: Button = null
var _used_potion_this_battle: bool = false
var _gambit_badge: Control = null

# Battlefield Resonance UI (GID-059)
var _battlefield_banner: Control = null
const _BATTLEFIELD_BANNER_DURATION: float = 3.0
var _battlefield_info_label: Label = null  # persistent day/night + biome label in SidePanel
var _slot_highlight_panels: Array[Control] = []  # overlay panels on affected slots

var _float_layer: CanvasLayer = null

# Click-to-target for board-card attacks (select attacker, then click enemy)
var _dragged_card: Dictionary = {}  # {card: CardInstance}
var _vh: float = 0.0

# Drag-to-play: populated when native drag starts so CardViewBuilder can highlight slots.
# Cleared in NOTIFICATION_DRAG_END and after a successful drop.
var _hand_drag_card: CardInstance = null
var _cancel_btn: Button = null

# Card inspect overlay
var _inspect_overlay: Control = null

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
const TUTORIAL_DURATION: float = 8.0

# Dual-face flip tracking (GID-062): instance_ids already flipped this battle.
var _flipped_dual_ids: Dictionary = {}

@onready var _enemy_hand_view = $EnemyArea/EnemyHandView
@onready var _enemy_board_view = $EnemyArea/EnemyBoardView
@onready var _enemy_hero_view = $EnemyArea/EnemyHeroView
@onready var _player_board_view = $PlayerArea/PlayerBoardView
@onready var _player_hand_view = $PlayerArea/PlayerHandView
@onready var _player_hero_view = $PlayerArea/PlayerHeroView
@onready var _turn_label: Label = $SidePanel/TurnLabel
@onready var _mana_label: Label = $SidePanel/ManaLabel
@onready var _end_turn_btn: Button = $SidePanel/EndTurnButton
@onready var _menu_btn: Button = $SidePanel/MenuButton

func _ready() -> void:
	_float_layer = CanvasLayer.new()
	_float_layer.layer = 128
	add_child(_float_layer)
	_vh = get_viewport().get_visible_rect().size.y
	_fx = BattleFx.new()
	_fx.setup(_vh, _float_layer,
		_enemy_hero_view, _player_hero_view,
		_enemy_board_view, _player_board_view,
		self)
	_view = CardViewBuilder.new()
	_view.setup(_vh, _fx, _bind_card_input, _on_empty_slot_input, _make_card_view)
	var _bs: String = str(SceneManager.save_manager.get_setting("battle_speed", "normal"))
	_speed_scale = 0.45 if _bs == "fast" else 1.0
	_apply_ui_sizes()
	_resolver = SpellEffectResolver.new()
	_pause_ui = BattlePauseUI.new()
	_result_ui = BattleResultUI.new()
	_pause_ui.setup(self, _vh, _float_layer, _make_battle_save,
		func() -> bool: return _state.puzzle_mode)
	_result_ui.setup(self, _vh, _float_layer, _collect_veterancy_data)
	var _saved_battle: Dictionary = SceneManager.save_manager.pending_battle_state
	if puzzle_data != null:
		_puzzle_data_ref = puzzle_data
		_state = GameState.new()
		_resolver.setup(_state)
		_state.load_puzzle(puzzle_data)
		_wire_gamebus_emitter()
	elif _pvp:
		_setup_pvp_battle()
	elif _coop_pve:
		_setup_coop_pve_battle()
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
		_state = GameState.new()
		_resolver.setup(_state)
		_wire_gamebus_emitter()

		# Player deck: spire run uses its run-local draft deck; otherwise use the
		# persistent player deck. Floor 1 starter gives 8 basics before any pick.
		var player_deck: Array[String] = []
		if SceneManager.save_manager.is_spire_active():
			var draft: Array = SceneManager.save_manager.get_spire_run().get("draft_deck", [])
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
		_apply_equipment_effects(_state.players[0])
		_apply_passive_skills(_state.players[0])
		_state.players[0].draw_opening_hand(4)
		# Spire run: hero HP persists across floors (damage carries over).
		if SceneManager.save_manager.is_spire_active():
			var _spire_hp: int = int(SceneManager.save_manager.get_spire_run().get("hero_hp", 30))
			if _spire_hp > 0:
				_state.players[0].hero.health = mini(_spire_hp, _state.players[0].hero.max_health)
		# Siege gauntlet: hero HP carries over from the previous stage.
		var _siege_state: Dictionary = SceneManager.save_manager.get_active_siege()
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
		_apply_gambit_handicaps(_gambit_id)

		# start_turn draws 1 card + bonus_draw (from passive_draw skills/equipment).
		# bonus_mana (from passive_mana skills) was set above, so gain_mana_for_turn
		# already uses it: max_mana = mini(10, 1 + bonus_mana).
		_state.players[0].start_turn(1)
		# Attuned buff (GID-068): +1 mana on turn 1 when engaged on a ley line.
		if bool(enemy_data.get("player_attuned", false)):
			_state.players[0].hero.mana = mini(10, _state.players[0].hero.mana + 1)
			GameBus.hud_message_requested.emit("Attuned: +1 mana this turn.")
		if duel_wager > 0:
			_state.friendly_duel = true
			_state.wager_coins = duel_wager

		# Apply weather modifiers (only in infinite world)
		_battle_weather = WeatherManager.current_weather if SceneManager.save_manager.current_map == "main" else ""
		_apply_weather_battle_init()

		# Battlefield Resonance context (GID-059): stamp biome + is_night into GameState.
		var _bf_biome: int = int(enemy_data.get("battlefield_biome", -1))
		var _bf_night: bool = bool(enemy_data.get("battlefield_is_night", false))
		_state.set_battlefield_context(_bf_biome, _bf_night)

		# Companion passive: battle-start effects (extra_mana, hero_armor) and
		# first turn-start draw (draw_card). Excluded in puzzle and duel modes.
		_apply_companion_battle_start(_state.players[0])
		_apply_companion_turn_start()
		# Flush auto-resolve spells collected from opening hand + turn-1 draw.
		# Must run after enemy deck is built so spells target the real enemy.
		_resolver.flush_auto_spells(0)

	_fx.set_game_state(_state)
	_view.set_battle_state(_state, enemy_data)

	# Initialise capture tracker for the current enemy (no-op for puzzles/duels/PvP).
	if not _state.puzzle_mode and not _state.friendly_duel and not _pvp:
		var _ct_enemy_type: String = str(enemy_data.get("enemy_type", ""))
		var _ct_condition: String = EnemyRegistry.get_capture_condition(_ct_enemy_type)
		var _ct_param: int = EnemyRegistry.get_capture_param(_ct_enemy_type)
		_capture_tracker = CaptureTracker.new(_ct_condition, _ct_param)
		_resolver.capture_tracker = _capture_tracker

	_end_turn_btn.pressed.connect(_on_end_turn)
	_menu_btn.pressed.connect(_pause_ui.confirm_return_to_menu)
	_enemy_hero_view.gui_input.connect(_on_enemy_hero_input)
	_setup_board_drop_zone()
	_pause_ui.add_pause_button($SidePanel)
	_add_hero_power_button()
	_add_companion_hud()
	_add_potion_button()
	_add_gambit_badge()

	if _state.puzzle_mode:
		_end_turn_btn.text = "Check"
		_give_up_btn = Button.new()
		_give_up_btn.text = "Give Up"
		_give_up_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.07)
		_give_up_btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
		_give_up_btn.pressed.connect(_on_puzzle_give_up)
		$SidePanel.add_child(_give_up_btn)
	_state.turn_ended.connect(_on_turn_ended)
	GameBus.fatigue_damage.connect(_on_fatigue_damage)

	_refresh_all()
	_refresh_potion_button()

	# Catch any hero deaths that occurred during setup (e.g., fatigue on very small
	# Spire decks, or auto-resolve spells dealing damage before game-over was wired).
	_check_game_over()

	# If we resumed a battle mid-AI-turn, restart the AI (deferred so UI is ready).
	if not _saved_battle.is_empty() and _state.current_player_idx == 1 and not _state.is_game_over():
		_check_game_over.call_deferred()
		_run_ai_turn.call_deferred()

	# Show weather banner if a modifier is active
	if _battle_weather != "" and not _state.puzzle_mode:
		var banner: WeatherBanner = WeatherBanner.new()
		add_child(banner)
		banner.setup(_battle_weather)

	# Battlefield Resonance UI (GID-059)
	if not _state.puzzle_mode:
		_add_battlefield_info_label()
		_add_slot_highlights()
		_show_battlefield_banner.call_deferred()

	AudioManager.play_music("res://assets/audio/music/battle.ogg")

	if not SceneManager.save_manager.get_story_flag("tutorial_battle_tip"):
		_show_battle_tutorial()

	GameBus.tutorial_popup_requested.emit("tap_and_hold")

func _wire_gamebus_emitter() -> void:
	_state.inject_gamebus_emitter(func(pid: int, dmg: int) -> void:
		GameBus.fatigue_damage.emit(pid, dmg))

func _apply_equipment_effects(player: PlayerState) -> void:
	var sm := SceneManager.save_manager
	var slot_ids: Array[String] = [
		sm.equipped_weapon,
		sm.equipped_armor,
		sm.equipped_ring,
		sm.equipped_trinket,
	]
	var injected_any: bool = false
	for item_id in slot_ids:
		if item_id == "":
			continue
		var weapon: WeaponData = WeaponRegistry.get_weapon(item_id)
		if weapon == null:
			continue
		var level: int = 0
		if weapon.slot == "weapon":
			var inst: Dictionary = sm.get_owned_weapon_by_id(item_id)
			level = int(inst.get("upgrade_level", 0))
		match weapon.battle_effect_type:
			"deck_inject":
				var count: int = UpgradeDefs.effective_inject_count(weapon, level)
				for i in count:
					var tmpl: Dictionary = CardRegistry.get_template(weapon.injected_card_id)
					if tmpl.is_empty():
						continue
					player.draw_deck.append(CardInstance.new(tmpl))
				injected_any = true
			"starting_mana":
				player.hero.bonus_mana += UpgradeDefs.effective_stat(weapon, level)
			"starting_hp":
				var hp_bonus: int = UpgradeDefs.effective_stat(weapon, level)
				player.hero.health += hp_bonus
				player.hero.max_health += hp_bonus
			"passive_atk":
				player.hero.attack += UpgradeDefs.effective_stat(weapon, level)
	if injected_any:
		player.draw_deck.shuffle()

func _apply_passive_skills(player: PlayerState) -> void:
	for skill_id: String in SceneManager.save_manager.unlocked_skills:
		var skill: SkillData = SkillRegistry.get_skill(skill_id)
		if skill == null or skill.skill_type != "passive":
			continue
		match skill.effect_type:
			"passive_hp":
				player.hero.health += skill.effect_value
				player.hero.max_health += skill.effect_value
			"passive_mana":
				player.hero.bonus_mana += skill.effect_value
			"passive_atk":
				player.hero.attack += skill.effect_value
			"passive_draw":
				player.bonus_draw += skill.effect_value

## Apply once-per-battle companion passives (extra_mana, hero_armor).
## Call after start_turn(1) so the base mana is already established.
## Excluded in puzzle_mode and friendly_duel.
func _apply_companion_battle_start(player: PlayerState) -> void:
	if _state.puzzle_mode or _state.friendly_duel:
		return
	var companion_id: String = SceneManager.save_manager.active_companion
	if companion_id == "" or not CompanionRegistry.is_unlocked(companion_id):
		return
	var companion: CompanionData = CompanionRegistry.get_companion(companion_id)
	if companion == null:
		return
	match companion.passive_type:
		"extra_mana":
			player.hero.mana = mini(player.hero.mana + companion.passive_value, 10)
		"hero_armor":
			player.hero.apply_status("armor", companion.passive_value)

## Draw extra card(s) from the companion's draw_card passive.
## Called at the start of every player turn (initial setup + each subsequent player turn).
## No-op in puzzle_mode, friendly_duel, or when no draw_card companion is active.
func _apply_companion_turn_start() -> void:
	if _state.puzzle_mode or _state.friendly_duel:
		return
	var companion_id: String = SceneManager.save_manager.active_companion
	if companion_id == "" or not CompanionRegistry.is_unlocked(companion_id):
		return
	var companion: CompanionData = CompanionRegistry.get_companion(companion_id)
	if companion == null or companion.passive_type != "draw_card":
		return
	for _i in range(companion.passive_value):
		_state.players[0].draw_card()

## Add a compact companion display to SidePanel (name + passive description).
## No-op if no companion is equipped or the companion is not unlocked.
func _add_companion_hud() -> void:
	if _state.puzzle_mode:
		return
	var companion_id: String = SceneManager.save_manager.active_companion
	if companion_id == "" or not CompanionRegistry.is_unlocked(companion_id):
		return
	var companion: CompanionData = CompanionRegistry.get_companion(companion_id)
	if companion == null:
		return
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.003))
	$SidePanel.add_child(vbox)
	_companion_hud = vbox

	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", int(_vh * 0.005))
	vbox.add_child(portrait_row)

	if companion.portrait != null:
		var tex := TextureRect.new()
		tex.texture = companion.portrait
		tex.custom_minimum_size = Vector2(_vh * 0.045, _vh * 0.045)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_row.add_child(tex)
	else:
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.4, 0.6, 0.8)
		placeholder.custom_minimum_size = Vector2(_vh * 0.045, _vh * 0.045)
		portrait_row.add_child(placeholder)

	var name_lbl := Label.new()
	name_lbl.text = companion.display_name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.02))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_row.add_child(name_lbl)

	var passive_lbl := Label.new()
	passive_lbl.text = companion.description
	passive_lbl.add_theme_font_size_override("font_size", int(_vh * 0.017))
	passive_lbl.modulate = Color(0.85, 1.0, 0.85)
	passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(passive_lbl)

## Apply init-time weather modifiers (ash_fall poison) and reset snow discount tracking.
func _apply_weather_battle_init() -> void:
	_snow_discount_used = [false, false]
	match _battle_weather:
		"ash_fall", "volcanic":
			_state.players[1].hero.apply_status("poison", 2)

## Apply weather modifier to a newly summoned card (rain ghost bonus, sandstorm debuff).
func _apply_weather_to_summoned(card: CardInstance, _player_idx: int) -> void:
	match _battle_weather:
		"rain":
			if card.template_id == "ghost":
				card.health += 1
				card.max_health += 1
		"heavy_rain":
			if card.template_id == "ghost":
				card.health += 2
				card.max_health += 2
		"sandstorm", "dust_devil":
			if _state.turn_number <= 2:
				card.attack = maxi(0, card.attack - 1)

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
		GameBus.card_played.emit(card.card_id, "spell", -1)
	return ok

func _apply_ui_sizes() -> void:
	var hero_h: float = _vh * 0.10
	var board_h: float = _vh * 0.20
	_enemy_hand_view.custom_minimum_size   = Vector2(0, board_h)
	_enemy_hero_view.custom_minimum_size   = Vector2(0, hero_h)
	_enemy_board_view.custom_minimum_size  = Vector2(0, board_h)
	_player_board_view.custom_minimum_size = Vector2(0, board_h)
	_player_hero_view.custom_minimum_size  = Vector2(0, hero_h)
	_player_hand_view.custom_minimum_size  = Vector2(0, board_h)
	# Centre the board slots horizontally
	if _enemy_board_view is BoxContainer:
		(_enemy_board_view as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	if _player_board_view is BoxContainer:
		(_player_board_view as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	# Side panel buttons — large, easy to tap on mobile
	_end_turn_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.10)
	_end_turn_btn.add_theme_font_size_override("font_size", int(_vh * 0.035))
	_menu_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.07)
	_menu_btn.add_theme_font_size_override("font_size", int(_vh * 0.028))
	_turn_label.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_mana_label.add_theme_font_size_override("font_size", int(_vh * 0.022))
	($SidePanel as VBoxContainer).add_theme_constant_override("separation", int(_vh * 0.025))

# -------------------------------------------------------------------------
# First-battle tutorial overlay
# -------------------------------------------------------------------------

func _show_battle_tutorial() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = int(_vh * 0.025)
	var panel_w: float = vp.x * 0.65
	var panel_h: float = _vh * 0.32

	var layer := CanvasLayer.new()
	layer.layer = 150
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(panel_w * 0.06))
	margin.add_theme_constant_override("margin_right",  int(panel_w * 0.06))
	margin.add_theme_constant_override("margin_top",    int(panel_h * 0.08))
	margin.add_theme_constant_override("margin_bottom", int(panel_h * 0.08))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.02))
	margin.add_child(vbox)

	var label := Label.new()
	label.text = "Drag a card from your hand to the board to play it.\nTap an enemy minion to attack with your minion."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(label)

	var btn := Button.new()
	btn.text = "Got it"
	btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.pressed.connect(_dismiss_battle_tutorial)
	vbox.add_child(btn)

	_tutorial_overlay = layer
	get_tree().create_timer(TUTORIAL_DURATION, false).timeout.connect(_dismiss_battle_tutorial)

func _dismiss_battle_tutorial() -> void:
	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null
	SceneManager.save_manager.set_story_flag("tutorial_battle_tip")

# -------------------------------------------------------------------------
# Drag/Drop — native Godot drag-and-drop API (mouse + touch transparent)
# -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
				return  # overlay handles its own Escape
			_pause_ui.toggle()
			get_viewport().set_input_as_handled()

## Wire _player_board_view as the native drop target for hand-card drags.
## Called once from _ready() after the board node is ready.
func _setup_board_drop_zone() -> void:
	_player_board_view.set_drag_forwarding(
		func(_pos: Vector2) -> Variant: return null,
		func(pos: Vector2, data: Variant) -> bool: return _board_can_drop(pos, data),
		func(pos: Vector2, data: Variant) -> void: _board_drop(pos, data)
	)

## Called by Godot when the dragged card is released over _player_board_view.
func _board_drop(local_pos: Vector2, data: Variant) -> void:
	if not data is Dictionary or not data.has("card"):
		return
	var played_card: CardInstance = data["card"] as CardInstance
	if played_card == null:
		return
	_hand_drag_card = null
	_refresh_player_board()

	var global_pos: Vector2 = _player_board_view.to_global(local_pos)
	var is_enemy_targeted: bool = SpellEffectResolver.ENEMY_TARGETED_EFFECTS.has(played_card.spell_effect)
	var is_friendly_targeted: bool = SpellEffectResolver.FRIENDLY_TARGETED_EFFECTS.has(played_card.spell_effect)
	var is_slot_targeted: bool = SpellEffectResolver.SLOT_TARGETED_EFFECTS.has(played_card.spell_effect)
	var is_ally_targeted: bool = SpellEffectResolver.ALLY_TARGETED_EFFECTS.has(played_card.spell_effect)

	if played_card.card_class == "spell" and is_slot_targeted and _state.players[_my_idx()].can_play(played_card):
		_enter_slot_targeting_mode(played_card)
		return

	if played_card.card_class == "spell" and is_ally_targeted and _coop_pve and _state.players[_my_idx()].can_play(played_card):
		_enter_ally_targeting_mode(played_card)
		return

	if played_card.card_class == "spell" and (is_enemy_targeted or is_friendly_targeted) and _state.players[_my_idx()].can_play(played_card):
		if is_friendly_targeted and _state.players[_my_idx()].board.get_cards().is_empty():
			return
		elif is_enemy_targeted and played_card.spell_effect != "deal_damage_single" and _state.players[_opp_idx()].board.get_cards().is_empty():
			return
		else:
			_enter_targeting_mode(played_card, is_friendly_targeted)
			return

	if played_card.card_class != "spell":
		var target_slot_idx: int = _slot_idx_at_point(global_pos, _player_board_view)
		if target_slot_idx == -1 or _state.players[_my_idx()].board.slots[target_slot_idx] != null:
			return
		if _is_pvp_client():
			var hi: int = _state.players[_my_idx()].hand.find(played_card)
			if hi != -1 and _state.players[_my_idx()].can_play(played_card):
				AudioManager.play_sfx("card_play")
				_fx.haptic(20)
				_send_intent(BattleNetProtocol.encode_play_card_at_slot(hi, target_slot_idx))
				_dismiss_battle_tutorial()
			return
		if _do_play_card_at_slot(played_card, _my_idx(), target_slot_idx):
			AudioManager.play_sfx("card_play")
			_fx.haptic(20)
			if played_card.emergence_effect != "":
				var snap_em := _fx.snapshot()
				_resolver.resolve_emergence(played_card, _my_idx())
				_fx.trigger_fx(snap_em)
			else:
				_apply_weather_to_summoned(played_card, _my_idx())
			_refresh_all()
			_check_game_over()
			_dismiss_battle_tutorial()
	else:
		# Non-targeted spell: slot doesn't matter
		if _is_pvp_client():
			var hi2: int = _state.players[_my_idx()].hand.find(played_card)
			if hi2 != -1 and _state.players[_my_idx()].can_play(played_card):
				AudioManager.play_sfx("card_play")
				_fx.haptic(20)
				_send_intent(BattleNetProtocol.encode_play_spell(hi2, {}))
				_dismiss_battle_tutorial()
			return
		if _do_play_card(played_card, _my_idx()):
			AudioManager.play_sfx("card_play")
			_fx.haptic(20)
			var snap_fhd := _fx.snapshot()
			_resolver.resolve_spell(played_card, _my_idx())
			_fx.trigger_fx(snap_fhd)
			_refresh_all()
			_check_game_over()
			_dismiss_battle_tutorial()

## Returns true so Godot highlights the board zone when a hand-card drag is over it.
func _board_can_drop(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("card"):
		return false
	var card: CardInstance = data["card"] as CardInstance
	return card != null and _can_local_act() and _state.players[_my_idx()].can_play(card)

func _show_cancel_btn(label: String = "✕ Cancel", callback: Callable = Callable()) -> void:
	if _cancel_btn != null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var vw: float = vp.x
	_cancel_btn = Button.new()
	_cancel_btn.text = label
	_cancel_btn.custom_minimum_size = Vector2(vh * 0.14, vh * 0.06)
	_cancel_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	_cancel_btn.position = Vector2((vw - vh * 0.14) * 0.5, vh * 0.02)
	var cb: Callable = callback if callback.is_valid() else _hide_cancel_btn
	_cancel_btn.pressed.connect(cb)
	add_child(_cancel_btn)

func _hide_cancel_btn() -> void:
	if _cancel_btn != null:
		_cancel_btn.queue_free()
		_cancel_btn = null

func _enter_targeting_mode(card: CardInstance, friendly: bool = false) -> void:
	_targeting_spell = card
	_targeting_active = true
	_targeting_friendly = friendly
	_show_cancel_btn("✕ Cancel Spell", _cancel_targeting)
	_refresh_all()

func _cancel_targeting() -> void:
	_targeting_active = false
	_targeting_friendly = false
	_targeting_spell = null
	_hide_cancel_btn()
	_refresh_all()

# ── Co-op ally targeting (GID-100) ───────────────────────────────────────────
# Ally-targeted spells (ally_heal_hero, ally_revive, etc.) need the local player
# to tap one of the compact ally panels to choose which ally to benefit.

func _enter_ally_targeting_mode(card: CardInstance) -> void:
	_ally_targeting_spell = card
	_ally_targeting_active = true
	_show_cancel_btn("✕ Cancel Spell", _cancel_ally_targeting)
	_build_coop_arena_layout()

func _cancel_ally_targeting() -> void:
	_ally_targeting_active = false
	_ally_targeting_spell = null
	_hide_cancel_btn()

func _resolve_ally_spell(spell: CardInstance, target_pidx: int) -> void:
	_ally_targeting_active = false
	_ally_targeting_spell = null
	_hide_cancel_btn()
	var tgt: Dictionary = {"pidx": target_pidx}
	if _is_pvp_client():
		var hi: int = _state.players[_my_idx()].hand.find(spell)
		if hi != -1 and _state.players[_my_idx()].can_play(spell):
			AudioManager.play_sfx("card_play")
			_fx.haptic(20)
			_send_intent(BattleNetProtocol.encode_play_spell(hi, tgt))
		return
	if _do_play_card(spell, _my_idx()):
		AudioManager.play_sfx("card_play")
		_fx.haptic(20)
		var snap := _fx.snapshot()
		_resolver.resolve_spell(spell, _my_idx(), tgt)
		_fx.trigger_fx(snap)
	_refresh_all()
	_check_game_over()

# Builds (or rebuilds) the top ally bar showing compact hero panels for each
# non-boss player. Tapping a panel during ally targeting resolves the spell.
func _build_coop_arena_layout() -> void:
	if not _coop_pve or _state == null:
		return
	# Remove stale panels
	for p in _coop_ally_panels:
		if is_instance_valid(p):
			p.queue_free()
	_coop_ally_panels.clear()

	var boss_idx: int = _state.players.size() - 1
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = _vh * 0.08
	add_child(bar)
	_coop_ally_panels.append(bar)

	for pidx in range(_state.players.size()):
		if pidx == boss_idx:
			continue
		var ps: PlayerState = _state.players[pidx]
		var btn := Button.new()
		btn.text = "P%d  HP:%d/%d  Mana:%d" % [pidx + 1, ps.hero.health, ps.hero.max_health, ps.hero.mana]
		btn.custom_minimum_size = Vector2(_vh * 0.20, _vh * 0.06)
		if _ally_targeting_active:
			var cap_pidx: int = pidx  # capture for lambda
			btn.pressed.connect(func() -> void:
				if _ally_targeting_spell != null:
					_resolve_ally_spell(_ally_targeting_spell, cap_pidx)
			)
		bar.add_child(btn)
	_coop_arena_built = true

func _refresh_coop_ally_panels() -> void:
	if not _coop_pve or _state == null:
		return
	if not _coop_arena_built:
		_build_coop_arena_layout()
		return
	var boss_idx: int = _state.players.size() - 1
	var btn_idx: int = 0
	# bar is the first (and only) element in _coop_ally_panels
	if _coop_ally_panels.is_empty():
		return
	var bar: HBoxContainer = _coop_ally_panels[0] as HBoxContainer
	if bar == null or not is_instance_valid(bar):
		return
	for pidx in range(_state.players.size()):
		if pidx == boss_idx:
			continue
		var ps: PlayerState = _state.players[pidx]
		var btn: Button = bar.get_child(btn_idx) as Button
		if btn != null:
			btn.text = "P%d  HP:%d/%d  Mana:%d" % [pidx + 1, ps.hero.health, ps.hero.max_health, ps.hero.mana]
		btn_idx += 1

func _slot_idx_at_point(point: Vector2, board_view: Node) -> int:
	for child in board_view.get_children():
		if child is Control:
			var ctrl := child as Control
			if ctrl.get_global_rect().has_point(point):
				var idx: int = int(ctrl.get_meta("slot_idx", -1))
				if idx >= 0:
					return idx
	return -1

func _do_play_card_at_slot(card: CardInstance, player_idx: int, slot_idx: int) -> bool:
	var apply_discount: bool = (
		(_battle_weather == "snow" or _battle_weather == "blizzard") and
		not _snow_discount_used[player_idx]
	)
	var ok: bool
	if apply_discount:
		var saved_cost: int = card.cost
		card.cost = maxi(0, card.cost - 1)
		ok = _state.players[player_idx].play_card_at_slot(card, slot_idx)
		card.cost = saved_cost
		if ok:
			_snow_discount_used[player_idx] = true
	else:
		ok = _state.players[player_idx].play_card_at_slot(card, slot_idx)
	if ok:
		GameBus.card_played.emit(card.card_id, "board", slot_idx)
	return ok

func _enter_slot_select_mode(card: CardInstance) -> void:
	_slot_select_card = card
	_show_cancel_btn("✕ Cancel", _exit_slot_select_mode)
	_refresh_player_board()

func _exit_slot_select_mode() -> void:
	_slot_select_card = null
	_hide_cancel_btn()
	_refresh_player_board()

func _on_empty_slot_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _slot_targeting_spell != null:
				var spell := _slot_targeting_spell
				_exit_slot_targeting_mode()
				_resolve_slot_spell(spell, slot_idx)
				return
			if _slot_select_card != null:
				var card := _slot_select_card
				_exit_slot_select_mode()
				if _is_pvp_client():
					var hi: int = _state.players[_my_idx()].hand.find(card)
					if hi != -1 and _state.players[_my_idx()].can_play(card):
						AudioManager.play_sfx("card_play")
						_fx.haptic(20)
						_send_intent(BattleNetProtocol.encode_play_card_at_slot(hi, slot_idx))
						_dismiss_battle_tutorial()
					return
				if _do_play_card_at_slot(card, _my_idx(), slot_idx):
					AudioManager.play_sfx("card_play")
					_fx.haptic(20)
					if card.emergence_effect != "":
						var snap_se := _fx.snapshot()
						_resolver.resolve_emergence(card, _my_idx())
						_fx.trigger_fx(snap_se)
					else:
						_apply_weather_to_summoned(card, _my_idx())
					_refresh_all()
					_check_game_over()
					_dismiss_battle_tutorial()
				return

func _enter_slot_targeting_mode(spell: CardInstance) -> void:
	_slot_targeting_spell = spell
	_targeting_active = true
	_show_cancel_btn("✕ Cancel Spell", _exit_slot_targeting_mode)
	_refresh_player_board()

func _exit_slot_targeting_mode() -> void:
	_slot_targeting_spell = null
	_targeting_active = false
	_hide_cancel_btn()
	_refresh_player_board()

func _resolve_slot_spell(spell: CardInstance, slot_idx: int) -> void:
	if not _state.players[_my_idx()].can_play(spell):
		return
	if _is_pvp_client():
		var hi: int = _state.players[_my_idx()].hand.find(spell)
		if hi != -1:
			AudioManager.play_sfx("spell_resolve")
			_fx.haptic(20)
			_send_intent(BattleNetProtocol.encode_play_spell(hi, {"slot": slot_idx}))
		return
	_do_play_card(spell, _my_idx())
	AudioManager.play_sfx("spell_resolve")
	_fx.haptic(20)
	match spell.spell_effect:
		"bless_slot":
			_state.players[_my_idx()].board.enhance_slot(slot_idx, "atk_bonus", spell.spell_power)
		"ward_slot":
			_state.players[_my_idx()].board.enhance_slot(slot_idx, "shroud", 1)
	_refresh_all()
	_check_game_over()

# -------------------------------------------------------------------------
# Card inspect overlay (TID-086)
# -------------------------------------------------------------------------

func _show_card_inspect(card: CardInstance) -> void:
	if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
		return
	var overlay: CardInspectOverlay = CardInspectOverlay.new()
	add_child(overlay)
	move_child(overlay, get_child_count() - 1)
	overlay.show_card(card)
	overlay.closed.connect(func() -> void: _inspect_overlay = null)
	_inspect_overlay = overlay

# -------------------------------------------------------------------------
# Battle pause (TID-088)
# -------------------------------------------------------------------------

func _add_hero_power_button() -> void:
	var active_skill: SkillData = _get_active_skill()
	if active_skill == null:
		return
	_hero_power_btn = Button.new()
	_hero_power_btn.text = active_skill.display_name
	_hero_power_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.05)
	_hero_power_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	_hero_power_btn.pressed.connect(_use_hero_power)
	$SidePanel.add_child(_hero_power_btn)

func _add_potion_button() -> void:
	if _state.puzzle_mode:
		return
	var has_any: bool = false
	for potion_id: String in SceneManager.save_manager.potions:
		if int(SceneManager.save_manager.potions[potion_id]) > 0:
			has_any = true
			break
	if not has_any:
		return
	_potion_btn = Button.new()
	_potion_btn.text = "Potion"
	_potion_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.05)
	_potion_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	_potion_btn.pressed.connect(_on_potion_button_pressed)
	$SidePanel.add_child(_potion_btn)

func _apply_gambit_handicaps(gambit_id: String) -> void:
	if gambit_id.is_empty():
		return
	match gambit_id:
		"wounded_pride":
			_state.players[0].hero.health = 25
			_state.players[0].hero.max_health = 25
		"slow_start":
			_state.players[0].skip_next_draw = true
		"iron_veil":
			_state.players[1].hero.apply_status("armor", 5)
		# "emboldened_foe" is handled before build_deck via minion_attack_bonus.

func _add_gambit_badge() -> void:
	var gambit_id: String = str(enemy_data.get("gambit_id", ""))
	if gambit_id.is_empty():
		return
	var gdata: Dictionary = Gambits.get_gambit(gambit_id)
	if gdata.is_empty():
		return
	_gambit_badge = PanelContainer.new()
	var badge_lbl := Label.new()
	badge_lbl.text = "Gambit: %s" % str(gdata.get("name", gambit_id))
	badge_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_gambit_badge.add_child(badge_lbl)
	$SidePanel.add_child(_gambit_badge)

func _refresh_potion_button() -> void:
	if _potion_btn == null:
		return
	var has_potions: bool = false
	for potion_id: String in SceneManager.save_manager.potions:
		if int(SceneManager.save_manager.potions[potion_id]) > 0:
			has_potions = true
			break
	_potion_btn.disabled = _used_potion_this_battle or not has_potions or _state.current_player_idx != _my_idx()
	_potion_btn.visible = has_potions

func _on_potion_button_pressed() -> void:
	if _used_potion_this_battle or _state.current_player_idx != _my_idx():
		return
	_show_potion_picker()

func _show_potion_picker() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 160
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = minf(vp.x * 0.7, _vh * 0.55)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.97)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, 0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, vp.y * 0.3)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vh * 0.025))
	margin.add_theme_constant_override("margin_right",  int(_vh * 0.025))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.025))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.025))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.015))
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Use a Potion"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var sm := SceneManager.save_manager
	for potion_id: String in GardenDefs.POTIONS:
		var count: int = int(sm.potions.get(potion_id, 0))
		if count <= 0:
			continue
		var potion_data: Dictionary = GardenDefs.POTIONS[potion_id]
		var display_name: String = str(potion_data.get("display_name", potion_id))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(_vh * 0.012))
		var lbl := Label.new()
		lbl.text = "%s  ×%d" % [display_name, count]
		lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var use_btn := Button.new()
		use_btn.text = "Use"
		use_btn.custom_minimum_size = Vector2(_vh * 0.1, _vh * 0.055)
		use_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		var pid: String = potion_id
		use_btn.pressed.connect(func() -> void:
			layer.queue_free()
			_apply_potion_effect(pid)
		)
		row.add_child(use_btn)
		vbox.add_child(row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(panel_w * 0.5, _vh * 0.055)
	cancel_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	cancel_btn.pressed.connect(layer.queue_free)
	var center := CenterContainer.new()
	center.add_child(cancel_btn)
	vbox.add_child(center)

func _apply_potion_effect(potion_id: String) -> void:
	var sm := SceneManager.save_manager
	if not sm.remove_potions(potion_id, 1):
		return
	_used_potion_this_battle = true
	if _is_pvp_client():
		# Inventory consumed locally; the host applies the state effect to players[1].
		_send_intent(BattleNetProtocol.encode_potion(potion_id))
		GameBus.potion_used.emit(potion_id)
		_refresh_potion_button()
		return
	var player: PlayerState = _state.players[_my_idx()]
	var snap_pot := _fx.snapshot()
	match potion_id:
		"healing_draught":
			player.hero.health = mini(player.hero.health + 8, player.hero.max_health)
			_fx.spawn_float_labels(snap_pot)
			_fx.spawn_float_label(_fx.pos_of_hero(false), "+8 HP", Color(0.267, 1.0, 0.533))
		"clarity_brew":
			player.draw_card()
			player.draw_card()
		"ember_tonic":
			player.hero.mana = mini(player.hero.mana + 1, player.hero.max_mana)
			_fx.spawn_float_label(_fx.pos_of_hero(false), "+1 Mana", Color(0.4, 0.8, 1.0))
	GameBus.potion_used.emit(potion_id)
	_refresh_all()
	_refresh_potion_button()
	if _pvp:
		_check_game_over()

func _get_active_skill() -> SkillData:
	var result: SkillData = null
	for skill_id: String in SceneManager.save_manager.unlocked_skills:
		var sk: SkillData = SkillRegistry.get_skill(skill_id)
		if sk != null and sk.skill_type == "active":
			result = sk
	return result

func _use_hero_power() -> void:
	if _hero_power_used:
		return
	if _pvp and not _can_local_act():
		return
	var active_skill: SkillData = _get_active_skill()
	if active_skill == null:
		return
	_hero_power_used = true
	if _hero_power_btn != null:
		_hero_power_btn.disabled = true
	if _is_pvp_client():
		# Host doesn't know the client's skill — relay the effect itself.
		_send_intent(BattleNetProtocol.encode_hero_power({}, active_skill.effect_type, active_skill.effect_value))
		return
	_apply_hero_power_effect(_my_idx(), active_skill.effect_type, active_skill.effect_value)
	_refresh_all()
	_check_game_over()

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
		# Native drag ended (dropped outside any drop zone or cancelled).
		# Clear the slot-highlight state that was set when the drag started.
		if _hand_drag_card != null:
			_hand_drag_card = null
			_refresh_player_board()

func _on_target_chosen_card(target: CardInstance) -> void:
	var spell := _targeting_spell
	_targeting_active = false
	_targeting_friendly = false
	_targeting_spell = null
	_hide_cancel_btn()
	if _is_pvp_client():
		var hi: int = _state.players[_my_idx()].hand.find(spell)
		if hi != -1 and _state.players[_my_idx()].can_play(spell):
			AudioManager.play_sfx("card_play")
			_fx.haptic(20)
			_send_intent(BattleNetProtocol.encode_play_spell(hi, _pvp_target_dict_for_card(target)))
			_dismiss_battle_tutorial()
		return
	if _do_play_card(spell, _my_idx()):
		AudioManager.play_sfx("card_play")
		_fx.haptic(20)
		var snap_otc := _fx.snapshot()
		_resolver.resolve_spell(spell, _my_idx(), {"type": "minion", "card": target})
		_fx.trigger_fx(snap_otc)
	_refresh_all()
	_check_game_over()
	_dismiss_battle_tutorial()

func _on_target_chosen_hero() -> void:
	var spell := _targeting_spell
	_targeting_active = false
	_targeting_friendly = false
	_targeting_spell = null
	_hide_cancel_btn()
	if _is_pvp_client():
		var hi: int = _state.players[_my_idx()].hand.find(spell)
		if hi != -1 and _state.players[_my_idx()].can_play(spell):
			AudioManager.play_sfx("card_play")
			_fx.haptic(20)
			_send_intent(BattleNetProtocol.encode_play_spell(hi, {"hero": true}))
			_dismiss_battle_tutorial()
		return
	if _do_play_card(spell, _my_idx()):
		AudioManager.play_sfx("card_play")
		_fx.haptic(20)
		var snap_oth := _fx.snapshot()
		_resolver.resolve_spell(spell, _my_idx(), {"type": "hero"})
		_fx.trigger_fx(snap_oth)
	_refresh_all()
	_check_game_over()
	_dismiss_battle_tutorial()

func _make_card_ghost(card: CardInstance) -> PanelContainer:
	var panel := _make_card_view(card, "ghost")
	panel.modulate.a = 0.75
	# Fixed size already set inside _make_card_view
	return panel

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
	_view.refresh_zone(_enemy_hand_view, _state.players[_opp_idx()].hand, "enemy_hand")
	_view.refresh_board_zone(_enemy_board_view, _state.players[_opp_idx()].board, "enemy_board")
	_view.refresh_board_zone(_player_board_view, _state.players[_my_idx()].board, "board")
	_view.refresh_zone(_player_hand_view, _state.players[_my_idx()].hand, "hand")
	_view.refresh_hero(_enemy_hero_view, _state.players[_opp_idx()].hero, true)
	_view.refresh_hero(_player_hero_view, _state.players[_my_idx()].hero, false)
	_update_status()
	if _coop_pve:
		_refresh_coop_ally_panels()

func _refresh_player_board() -> void:
	if _local_player_idx < 0:
		return
	_view.update_context(
		_targeting_active, _targeting_friendly,
		_dragged_card, _hand_drag_card,
		_slot_targeting_spell, _slot_select_card
	)
	_view.refresh_board_zone(_player_board_view, _state.players[_my_idx()].board, "board")

func _bind_card_input(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	for conn in panel.gui_input.get_connections():
		panel.gui_input.disconnect(conn["callable"])
	if zone_id == "hand" and _state.current_player_idx == _my_idx():
		# Tap/click handler fires on release; it only fires when no native drag was started.
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_hand_card_input(event, card))
		# Native drag forwarding: drag threshold handled by Godot (mouse + touch transparent).
		# LongPressDetector remains independent; it cancels itself if movement > SLOP_PX,
		# which happens before the drag threshold is reached, so inspect and drag don't conflict.
		panel.set_drag_forwarding(
			func(_pos: Vector2) -> Variant:
				if not _can_local_act():
					return null
				if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
					return null
				if not _state.players[_my_idx()].can_play(card):
					return null
				_hand_drag_card = card
				panel.set_drag_preview(_make_card_ghost(card))
				_refresh_player_board()
				return {"card": card},
			func(_pos: Vector2, _data: Variant) -> bool: return false,
			func(_pos: Vector2, _data: Variant) -> void: pass
		)
	elif zone_id == "board" and _state.current_player_idx == _my_idx():
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_board_card_input(event, card))
	elif zone_id == "enemy_board":
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_enemy_card_input(event, card))
	# Right-click inspect — not on enemy hand (hidden information)
	if zone_id != "enemy_hand":
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_show_card_inspect(card)
		)
		# Long-press inspect (mobile) — reuse existing detector to avoid node churn
		var lpd: LongPressDetector = panel.get_node_or_null("_lpd") as LongPressDetector
		if lpd == null:
			lpd = LongPressDetector.new()
			lpd.name = "_lpd"
			panel.add_child(lpd)
		else:
			for conn in lpd.long_pressed.get_connections():
				lpd.long_pressed.disconnect(conn["callable"])
		lpd.long_pressed.connect(func() -> void: _show_card_inspect(card))

func _make_card_view(card: CardInstance, zone_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_vh * 0.10, _vh * 0.19)
	if zone_id == "enemy_hand":
		var back_style := StyleBoxFlat.new()
		back_style.bg_color = Color(0.15, 0.10, 0.28)
		back_style.corner_radius_top_left = 4
		back_style.corner_radius_top_right = 4
		back_style.corner_radius_bottom_left = 4
		back_style.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", back_style)
		panel.set_meta("is_card_back", true)
		return panel
	var is_board_zone: bool = (zone_id == "board" or zone_id == "enemy_board")
	panel.add_child(_view.build_card_vbox(card, is_board_zone))
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.set_meta("card_style", style)
	_view.apply_card_style(panel, card, zone_id)
	_bind_card_input(panel, card, zone_id)
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
	_end_turn_btn.disabled = _state.current_player_idx != _my_idx() or _ai_thinking

# -------------------------------------------------------------------------
# Input handlers
# -------------------------------------------------------------------------

## Handles tap (press+release without drag). Fires only when native drag was NOT started,
## because Godot consumes the release event when a drag is in progress.
func _on_hand_card_input(event: InputEvent, card: CardInstance) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if not _can_local_act():
				return
			_on_hand_card_tap(card)

func _on_hand_card_tap(card: CardInstance) -> void:
	if not _can_local_act():
		return
	if card.card_class != "spell" and _state.players[_my_idx()].can_play(card):
		_enter_slot_select_mode(card)
	elif SpellEffectResolver.SLOT_TARGETED_EFFECTS.has(card.spell_effect) and _state.players[_my_idx()].can_play(card):
		_enter_slot_targeting_mode(card)
	else:
		_show_card_inspect(card)

func _on_board_card_input(event: InputEvent, my_card: CardInstance) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _targeting_active and _targeting_friendly:
			_on_target_chosen_card(my_card)
			return
		if not my_card.can_attack():
			return
		# Always enter selection mode — player clicks a target (minion or hero)
		_dragged_card = {"card": my_card}
		_refresh_all()

func _on_enemy_card_input(event: InputEvent, target: CardInstance) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _targeting_active and not _targeting_friendly:
			_on_target_chosen_card(target)
			return
		if _dragged_card.is_empty():
			return
		var attacker: CardInstance = _dragged_card["card"]
		if not attacker.can_attack():
			_dragged_card.clear()
			return
		# Ward: if any enemy minion has Ward, only those are valid targets
		var valid_targets: Array[CardInstance] = _view.get_ward_valid_targets(_state.players[_opp_idx()].board.get_cards())
		if not valid_targets.has(target):
			return  # keep attacker selected; player must click a Ward minion
		_attempt_attack(attacker, target)

func _on_enemy_hero_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _targeting_active and not _targeting_friendly:
			_on_target_chosen_hero()
			return
		if not _can_local_act():
			return
		if _dragged_card.is_empty():
			return
		var attacker: CardInstance = _dragged_card["card"]
		if not attacker.can_attack():
			_dragged_card.clear()
			_refresh_all()
			return
		# Ward: cannot attack hero while any Ward minion is alive on enemy board
		for ec: CardInstance in _state.players[_opp_idx()].board.get_cards():
			if ec.keywords.has(Keywords.WARD):
				return  # keep attacker selected; player must target the Ward minion
		_attempt_attack(attacker, null)

## Routes a chosen attack: client sends an intent; host/single-player resolves
## locally via _execute_attack (which broadcasts through _check_game_over).
func _attempt_attack(attacker: CardInstance, target: CardInstance) -> void:
	if _is_pvp_client():
		var a_slot: int = _state.players[_my_idx()].board.slots.find(attacker)
		var t_slot: int = BattleNetProtocol.TARGET_HERO
		if target != null:
			t_slot = _state.players[_opp_idx()].board.slots.find(target)
		_dragged_card.clear()
		if a_slot != -1 and (target == null or t_slot != -1):
			_send_intent(BattleNetProtocol.encode_attack(a_slot, t_slot))
		_refresh_all()
		return
	_execute_attack(attacker, target)

## Resolves a player minion attack against target (CardInstance) or the enemy hero (null).
## Handles damage, counterattack, death removal, FX, and the card_attacked signal.
func _execute_attack(attacker: CardInstance, target: CardInstance) -> void:
	AudioManager.play_sfx("attack")
	var attacker_panel := _fx.get_card_panel(attacker, false)
	var snap := _fx.snapshot()
	var attacker_dmg: int = BattlefieldRules.modify_damage(attacker.attack, _state.battlefield_biome)
	if target != null:
		var target_dmg: int = BattlefieldRules.modify_damage(target.attack, _state.battlefield_biome)
		target.take_damage(attacker_dmg)
		attacker.take_damage(target_dmg)
		attacker.attack_count -= 1
		var target_panel := _fx.get_card_panel(target, true)
		_fx.flash_node(target_panel, Color(1.0, 0.3, 0.3, 1.0))
		_fx.flash_node(attacker_panel, Color(1.0, 0.3, 0.3, 1.0))
		if not target.is_alive():
			attacker.battle_kills += 1
			_state.players[1].board.remove_card(target)
			_state.players[1].discard.append(target)
		GameBus.card_attacked.emit(attacker.card_id, target.card_id)
	else:
		if _capture_tracker != null:
			_capture_tracker.note_minion_attacked_hero(0)
		var hero := _state.players[1].hero
		hero.take_damage(attacker_dmg)
		attacker.take_damage(BattlefieldRules.modify_damage(hero.attack, _state.battlefield_biome))
		attacker.attack_count -= 1
		_fx.flash_node(_enemy_hero_view, Color(1.0, 0.3, 0.3, 1.0))
		_fx.flash_node(attacker_panel, Color(1.0, 0.3, 0.3, 1.0))
		GameBus.card_attacked.emit(attacker.card_id, "hero")
	if not attacker.is_alive():
		_state.players[0].board.remove_card(attacker)
		_state.players[0].discard.append(attacker)
	_fx.spawn_float_labels(snap)
	_fx.check_shake(snap)
	_dragged_card.clear()
	_refresh_all()
	_check_game_over()

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
		_apply_desert_scorch()
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
			_refresh_potion_button()
			_check_game_over()
			if not _state.is_game_over():
				AudioManager.play_sfx("card_draw")
				_apply_companion_turn_start()
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
		_refresh_potion_button()
		_check_game_over()
		if not _state.is_game_over():
			AudioManager.play_sfx("card_draw")
			_apply_companion_turn_start()
			var snap_as := _fx.snapshot()
			_resolver.flush_auto_spells(0)
			_fx.trigger_fx(snap_as)
			_refresh_all()
			_check_game_over()
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
	var lbl := Label.new()
	lbl.text = "Fatigue! -%d" % dmg
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.025))
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
	var actions := BasicAI.decide_turn(_state)
	_fx.show_intent_banner(BasicAI.describe_turn(_state))
	await _battle_delay(1.5)
	_execute_ai_actions(actions, 0)

func _execute_ai_actions(actions: Array[Callable], idx: int) -> void:
	if _state.is_game_over():
		_fx.hide_intent_banner()
		_ai_thinking = false
		_check_game_over()
		return
	if idx >= actions.size():
		_fx.hide_intent_banner()
		await _battle_delay(0.5)
		_ai_thinking = false
		_state.end_turn()
		_refresh_all()
		_check_game_over()
		return
	AudioManager.play_sfx("attack")
	var snap_ai := _fx.snapshot()
	var ai_board_before: Array[CardInstance] = _state.players[1].board.get_cards().duplicate()
	actions[idx].call()
	_resolver.flush_auto_spells(1)
	for c: CardInstance in _state.players[1].board.get_cards():
		if not ai_board_before.has(c):
			_resolver.resolve_emergence(c, 1)
			_apply_weather_to_summoned(c, 1)
	_fx.trigger_fx(snap_ai)
	_refresh_all()
	if _state.is_game_over():
		_check_game_over()
		return
	await _battle_delay(0.6)
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

func _check_game_over() -> void:
	if _pvp:
		_pvp_check_game_over()
		return
	if _coop_pve:
		_coop_pve_check_game_over()
		return
	_check_boss_phase2()
	if _game_over_handled:
		return
	if _state.is_game_over():
		_game_over_handled = true
		var w := _state.winner()
		if _state.puzzle_mode:
			if w == 0:
				AudioManager.play_sfx("battle_win")
				_fx.haptic(120)
				_show_puzzle_victory()
			return
		GameBus.battle_ended.emit(w)
		if _state.friendly_duel:
			if w == 0:
				AudioManager.play_sfx("battle_win")
				_fx.haptic(120)
				_result_ui.show_duel_victory(_state.wager_coins)
			else:
				AudioManager.play_sfx("battle_lose")
				_fx.haptic(80)
				_result_ui.show_duel_loss(_state.wager_coins)
			return
		if w == 0:
			AudioManager.play_sfx("battle_win")
			_fx.haptic(120)
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
			var dawn_win: int = _state.players[0].dawn_cards_played
			var dusk_win: int = _state.players[0].dusk_cards_played
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
				_result_ui.show_victory_boss(pool, weapon_reward_id, boss_rarities, boss_stats_list, coins_win, xp_win, hero_hp_win, dawn_win, dusk_win)
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
					_result_ui.show_soulbind(reward_card_id, _ct_sig, _capture_tracker.condition_text(), hero_hp_win, dawn_win, dusk_win, rolled_rarity, rolled_stats)
				elif not _ct_sig.is_empty() and not _ct_captured:
					var _ct_text: String = _capture_tracker.condition_text() if _capture_tracker != null else ""
					_result_ui.show_victory(reward_card_id, "", _ct_sig, _ct_text, false, rolled_rarity, rolled_stats, coins_win, xp_win, hero_hp_win, dawn_win, dusk_win)
				else:
					_result_ui.show_victory(reward_card_id, "", "", "", false, rolled_rarity, rolled_stats, coins_win, xp_win, hero_hp_win, dawn_win, dusk_win)
		else:
			AudioManager.play_sfx("battle_lose")
			_fx.haptic(80)
			GameBus.battle_lost.emit()

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
	_resolver.setup(_state)
	_wire_gamebus_emitter()
	_view.set_battle_state(_state, enemy_data)
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

## Desert biome rule: damage the leftmost minion on each board at turn start.
## Does NOT use the Scorched modifier — this is a separate status tick.
func _apply_desert_scorch() -> void:
	for pid in range(2):
		for si in range(5):
			var c: CardInstance = _state.players[pid].board.slots[si]
			if c != null:
				c.take_damage(1)
				if not c.is_alive():
					_state.players[pid].board.remove_card(c)
					_state.players[pid].discard.append(c)
				break

## Adds a persistent compact label in SidePanel showing biome name and day/night indicator.
func _add_battlefield_info_label() -> void:
	var biome: int = _state.battlefield_biome
	if biome == -1:
		return
	var night: bool = _state.is_night
	var sun_moon: String = "☽" if night else "☀"
	var info_lbl := Label.new()
	info_lbl.text = "%s %s" % [BattlefieldRules.get_biome_name(biome), sun_moon]
	info_lbl.add_theme_font_size_override("font_size", int(_vh * 0.02))
	info_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$SidePanel.add_child(info_lbl)
	_battlefield_info_label = info_lbl

## Adds coloured overlay panels on affected board slots (Forest 0/4, Mountains 2).
func _add_slot_highlights() -> void:
	var highlights: Array[int] = BattlefieldRules.get_slot_highlights(_state.battlefield_biome)
	if highlights.is_empty():
		return
	var tint: Color = Color(0.4, 0.9, 1.0, 0.18)  # distinct from cyan spell-target and yellow attack
	for board_view in [_player_board_view, _enemy_board_view]:
		for si in highlights:
			var overlay := ColorRect.new()
			overlay.color = tint
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var slot_lbl := Label.new()
			slot_lbl.text = "★"
			slot_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
			slot_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.7))
			slot_lbl.set_meta("bf_slot_idx", si)
			board_view.add_child(overlay)
			board_view.add_child(slot_lbl)
			_slot_highlight_panels.append(overlay)
			_slot_highlight_panels.append(slot_lbl)

## Shows a transient banner at battle start with the biome rule text.
## Deferred so the scene is fully set up before showing.
func _show_battlefield_banner() -> void:
	var biome: int = _state.battlefield_biome
	if biome == -1:
		return
	var night: bool = _state.is_night
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.16, 0.88)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = Color(0.4, 0.9, 1.0, 0.6)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_lbl := Label.new()
	var time_str: String = "Night" if night else "Day"
	title_lbl.text = "%s — %s" % [BattlefieldRules.get_biome_name(biome), time_str]
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule_lbl := Label.new()
	rule_lbl.text = BattlefieldRules.get_rule_text(biome)
	rule_lbl.add_theme_font_size_override("font_size", int(_vh * 0.021))
	rule_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	rule_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)
	vbox.add_child(rule_lbl)
	panel.add_child(vbox)
	panel.custom_minimum_size = Vector2(vp.x * 0.55, _vh * 0.12)
	panel.position = Vector2((vp.x - panel.custom_minimum_size.x) * 0.5, _vh * 0.3)
	if _float_layer != null:
		_float_layer.add_child(panel)
	else:
		add_child(panel)
	_battlefield_banner = panel
	var tw: Tween = panel.create_tween()
	tw.tween_interval(_BATTLEFIELD_BANNER_DURATION)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(func() -> void: _battlefield_banner = null)

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
func _opp_idx() -> int:
	if _coop_pve and _state != null and _state.players.size() > 2:
		return _state.players.size() - 1
	return 1 - _local_player_idx

## True when this peer owns the canonical simulation: ENet host in any mode
## (listen-server host/player-0 or dedicated-server referee).
## Uses self.multiplayer (resolved to the node's own SceneMultiplayer subtree)
## so it works correctly both in production and in smoke tests that register
## custom multiplayer instances via set_multiplayer().
func _is_pvp_host() -> bool:
	return (_pvp or _coop_pve) and multiplayer.is_server()

## True when this peer is a thin client renderer (never the ENet host).
## Also true for co-op PvE ally clients.
func _is_pvp_client() -> bool:
	return (_pvp or _coop_pve) and not multiplayer.is_server()


## True when this peer is a read-only spectator (TID-367). Spectators mirror
## the state but never send intents; all input gates check this.
func _is_spectator() -> bool:
	return _pvp_spectating

## True when local input is allowed: it's our turn, AI/round-trip not pending,
## and we have a local player (not the headless referee, _local_player_idx = -1).
func _can_local_act() -> bool:
	if _pvp_spectating:
		return false  # spectators never act
	if _local_player_idx < 0:
		return false  # dedicated-server referee has no local player
	if _ai_thinking:
		return false
	if _state == null:
		return false
	if _is_pvp_client() and _pvp_pending:
		return false
	return _state.current_player_idx == _my_idx()

## Builds the relay node + canonical state for a PvP battle. Host builds both
## decks and starts turn 1; the client waits for the first sync_state mirror.
## If _pvp_spectating is true, we skip simulation entirely and only receive mirrors.
func _setup_pvp_battle() -> void:
	_state = GameState.new()
	_state.ranked = pvp_ranked
	_resolver.setup(_state)
	_wire_gamebus_emitter()
	_net = _BattleNetSyncScript.new()
	_net.name = "BattleNetSync"
	add_child(_net)
	_net.battle_scene = self
	if _pvp_spectating:
		# Spectator: send request_spectate so the host registers us and sends the state.
		_connect_pvp_net_signals()
		_net.rpc_id(1, "request_spectate")
		return
	_connect_pvp_net_signals()
	if _is_pvp_host():
		_build_pvp_decks()
		_state.players[0].start_turn(1)
		# Initial state is broadcast by the _check_game_over() call at the end of
		# _ready (host branch), so the client populates from the mirror.

var _pvp_sync_retry_accum: float = 0.0

## Client/spectator: keep asking the host for the initial state until the first
## mirror lands (handles the race where the host broadcasts before this scene exists).
func _process(delta: float) -> void:
	if _coop_pve:
		_process_coop_sync(delta)
		return
	if not (_is_pvp_client() or _pvp_spectating) or _last_applied_seq >= 0 or _net == null:
		return
	_pvp_sync_retry_accum += delta
	if _pvp_sync_retry_accum >= 0.4:
		_pvp_sync_retry_accum = 0.0
		if _pvp_spectating:
			_net.rpc_id(1, "request_spectate")  # re-send until host registers us
		else:
			_net.rpc_id(1, "request_sync")

## Host: a client asked for the current state — send it.
func _on_pvp_sync_request() -> void:
	if _is_pvp_host():
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
	if _local_player_idx < 0:
		# Dedicated-server referee: both decks supplied by clients.
		var insts0: Array[Dictionary] = []
		for inst in pvp_player0_deck:
			if inst is Dictionary:
				insts0.append(inst)
		if insts0.size() > 0:
			_state.players[0].build_deck_from_instances(insts0)
		else:
			_state.players[0].build_deck(fallback)
		var insts1: Array[Dictionary] = []
		for inst in pvp_player1_deck:
			if inst is Dictionary:
				insts1.append(inst)
		if insts1.size() > 0:
			_state.players[1].build_deck_from_instances(insts1)
		else:
			_state.players[1].build_deck(fallback)
	else:
		# Listen-server host: players[0] is local, players[1] from the challenged peer.
		var my_insts: Array[Dictionary] = SceneManager.save_manager.get_deck_instances()
		if my_insts.size() > 0:
			_state.players[0].build_deck_from_instances(my_insts)
		else:
			_state.players[0].build_deck(fallback)
		var opp_insts: Array[Dictionary] = []
		for inst in pvp_opponent_deck:
			if inst is Dictionary:
				opp_insts.append(inst)
		if opp_insts.size() > 0:
			_state.players[1].build_deck_from_instances(opp_insts)
		else:
			_state.players[1].build_deck(fallback)
	_state.players[0].draw_opening_hand(4)
	_state.players[1].draw_opening_hand(4)

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
func _send_intent(payload: Dictionary) -> void:
	if _net != null:
		_pvp_pending = true
		var rpc_name: String = "send_coop_intent" if _coop_pve else "send_intent"
		_net.rpc_id(1, rpc_name, payload)

## Host → client: broadcast the full canonical state with a fresh seq.
## Also fans to any registered spectators (TID-367).
func _broadcast_state() -> void:
	if not _is_pvp_host() or _net == null:
		return
	_state_seq += 1
	var payload: Dictionary = BattleNetProtocol.encode_state(_state.to_dict(), _state_seq)
	_net.rpc("sync_state", payload)
	for spec_id in _spectators:
		_net.rpc_id(spec_id, "sync_state", payload)

## Client/spectator: receive and apply an authoritative state mirror.
func _on_pvp_state(payload: Dictionary) -> void:
	if not (_is_pvp_client() or _pvp_spectating):
		return
	var decoded: Dictionary = BattleNetProtocol.decode_state(payload)
	if not bool(decoded["valid"]):
		return
	var seq: int = int(decoded["seq"])
	if seq <= _last_applied_seq:
		return
	_last_applied_seq = seq
	_pvp_pending = false
	var state_dict: Dictionary = decoded["state"]
	_state = GameState.new()
	_state.from_dict(state_dict)
	_wire_gamebus_emitter()
	_bump_card_next_id(_state)
	# Re-wire the helpers that cache a GameState reference (GID-040 pattern).
	# from_dict built a brand-new GameState, so its turn_ended signal must be
	# reconnected — the original connection in _ready was to the now-discarded state.
	if not _state.turn_ended.is_connected(_on_turn_ended):
		_state.turn_ended.connect(_on_turn_ended)
	_resolver.setup(_state)
	_fx.set_game_state(_state)
	_view.set_battle_state(_state, enemy_data)
	_refresh_all()
	_refresh_potion_button()

## Authority: validate + apply a client intent, then re-render (broadcast happens
## in _check_game_over). In referee mode both players send intents; in
## listen-server mode only the single client (player 1) does.
func _on_pvp_intent(sender: int, payload: Dictionary) -> void:
	if not _is_pvp_host():
		return
	var intent: Dictionary = BattleNetProtocol.decode_intent(payload)
	var t: String = str(intent["type"])
	if t == "":
		return
	# Determine which player index the sender maps to.
	# Listen-server: the only remote sender is always player 1.
	# Dedicated-server referee: look up the per-peer mapping.
	var acting_idx: int = 1
	if _local_player_idx < 0:
		acting_idx = int(_pvp_peer_to_idx.get(sender, -1))
		if acting_idx < 0:
			return  # unknown sender — ignore
	if t == BattleNetProtocol.INTENT_SURRENDER:
		_apply_remote_surrender(acting_idx)
		return
	if _state.current_player_idx != acting_idx:
		_broadcast_state()
		return
	var changed: bool = _apply_remote_intent(intent, acting_idx)
	if changed:
		_refresh_all()
		_check_game_over()
	else:
		_broadcast_state()  # reject → re-sync the client

## Authority: apply a validated remote-player intent to the canonical state.
## `player_idx` is 1 in listen-server mode (the single client); either 0 or 1 in
## referee mode (determined by _pvp_peer_to_idx lookup in _on_pvp_intent).
## Returns true if the state changed (and should be re-broadcast).
func _apply_remote_intent(intent: Dictionary, player_idx: int) -> bool:
	var t: String = str(intent["type"])
	var p1: PlayerState = _state.players[player_idx]
	var opp_idx: int = 1 - player_idx
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
			if not _do_play_card_at_slot(card, player_idx, slot_idx):
				return false
			if card.emergence_effect != "":
				_resolver.resolve_emergence(card, player_idx)
			else:
				_apply_weather_to_summoned(card, player_idx)
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
				if not _do_play_card(spell, player_idx):
					return false
				match spell.spell_effect:
					"bless_slot":
						p1.board.enhance_slot(s_slot, "atk_bonus", spell.spell_power)
					"ward_slot":
						p1.board.enhance_slot(s_slot, "shroud", 1)
				return true
			var resolver_target: Dictionary = _pvp_resolver_target(tgt)
			if not _do_play_card(spell, player_idx):
				return false
			_resolver.resolve_spell(spell, player_idx, resolver_target)
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
				target = _state.players[opp_idx].board.slots[t_slot]
				if target == null:
					return false
				# Ward gating: if any enemy minion has Ward, only Ward minions are valid.
				var valid: Array[CardInstance] = _view.get_ward_valid_targets(_state.players[opp_idx].board.get_cards())
				if not valid.has(target):
					return false
			else:
				# Cannot attack hero while a Ward minion stands.
				for ec: CardInstance in _state.players[opp_idx].board.get_cards():
					if ec.keywords.has(Keywords.WARD):
						return false
			_resolve_remote_attack(attacker, target, player_idx)
			return true
		BattleNetProtocol.INTENT_HERO_POWER:
			_apply_hero_power_effect(player_idx, str(intent["effect_type"]), int(intent["effect_value"]))
			return true
		BattleNetProtocol.INTENT_POTION:
			_apply_potion_state_effect(player_idx, str(intent["potion_id"]))
			return true
		BattleNetProtocol.INTENT_END_TURN:
			_state.end_turn()
			return true
	return false

## Translates a wire target dict ({hero}/{side,slot}/{pidx}) into a resolver target.
func _pvp_resolver_target(tgt: Dictionary) -> Dictionary:
	if tgt.is_empty():
		return {}
	if tgt.has("pidx"):
		return {"pidx": int(tgt["pidx"])}
	if bool(tgt.get("hero", false)):
		return {"type": "hero"}
	if tgt.has("side") and tgt.has("slot"):
		var side: int = int(tgt["side"])
		var slot: int = int(tgt["slot"])
		if side >= 0 and side < 2 and slot >= 0 and slot < 5:
			var c: CardInstance = _state.players[side].board.slots[slot]
			if c != null:
				return {"type": "minion", "card": c}
	return {}

## State-only attack resolution (no side-specific FX) for relayed/remote attacks.
func _resolve_remote_attack(attacker: CardInstance, target: CardInstance, attacker_pid: int) -> void:
	var defender_pid: int = 1 - attacker_pid
	var attacker_dmg: int = BattlefieldRules.modify_damage(attacker.attack, _state.battlefield_biome)
	if target != null:
		var target_dmg: int = BattlefieldRules.modify_damage(target.attack, _state.battlefield_biome)
		target.take_damage(attacker_dmg)
		attacker.take_damage(target_dmg)
		attacker.attack_count -= 1
		if not target.is_alive():
			attacker.battle_kills += 1
			_state.players[defender_pid].board.remove_card(target)
			_state.players[defender_pid].discard.append(target)
		GameBus.card_attacked.emit(attacker.template_id, target.template_id)
	else:
		var hero := _state.players[defender_pid].hero
		hero.take_damage(attacker_dmg)
		attacker.take_damage(BattlefieldRules.modify_damage(hero.attack, _state.battlefield_biome))
		attacker.attack_count -= 1
		GameBus.card_attacked.emit(attacker.template_id, "hero")
	if not attacker.is_alive():
		_state.players[attacker_pid].board.remove_card(attacker)
		_state.players[attacker_pid].discard.append(attacker)

## Applies a hero-power effect to player_idx. Shared by the local host power and
## the relayed client power (host doesn't know the client's skill, so the effect
## is carried in the intent).
func _apply_hero_power_effect(player_idx: int, effect_type: String, value: int) -> void:
	var player: PlayerState = _state.players[player_idx]
	var enemy: PlayerState = _state.players[1 - player_idx]
	match effect_type:
		"active_damage_all":
			for card: CardInstance in enemy.board.get_cards().duplicate():
				card.take_damage(value)
				if not card.is_alive():
					enemy.board.remove_card(card)
					enemy.discard.append(card)
		"active_heal":
			player.hero.health = mini(player.hero.health + value, player.hero.max_health)
		"active_draw":
			for _i in value:
				player.draw_card()
			_resolver.flush_auto_spells(player_idx)
		"active_mana":
			player.hero.mana = mini(player.hero.mana + value, player.hero.max_mana)

## Applies the game-state portion of a potion to player_idx (no inventory I/O —
## the acting peer already consumed it from its own SaveManager).
func _apply_potion_state_effect(player_idx: int, potion_id: String) -> void:
	var player: PlayerState = _state.players[player_idx]
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
	var my_slot: int = _state.players[_my_idx()].board.slots.find(card)
	if my_slot != -1:
		return {"side": _my_idx(), "slot": my_slot}
	var opp_slot: int = _state.players[_opp_idx()].board.slots.find(card)
	if opp_slot != -1:
		return {"side": _opp_idx(), "slot": opp_slot}
	return {}

# ── PvP end-of-battle (host detect + sync) ────────────────────────────────────

## Routed from _check_game_over when _pvp. Host detects the winner, broadcasts
## the final state + pvp_ended, and shows its own overlay. Otherwise (host, not
## over) it pushes the latest state to the client.
func _pvp_check_game_over() -> void:
	if not _is_pvp_host():
		return
	if _state.is_game_over():
		if _pvp_ended:
			return
		_pvp_ended = true
		var w: int = _state.winner()
		_broadcast_state()
		if _net != null:
			_net.rpc("pvp_ended", {"winner_idx": w, "forfeit": false, "ante_coins": pvp_ante_coins})
			for spec_id in _spectators:
				_net.rpc_id(spec_id, "pvp_ended", {"winner_idx": w, "forfeit": false, "ante_coins": 0})
		_finish_pvp(w == _local_player_idx)
		return
	_broadcast_state()

## Client/spectator: the host says the battle is over. Show the matching overlay.
func _on_pvp_ended(payload: Dictionary) -> void:
	if not (_is_pvp_client() or _pvp_spectating) or _pvp_ended:
		return
	_pvp_ended = true
	var w: int = int(payload.get("winner_idx", _opp_idx()))
	pvp_ante_coins = int(payload.get("ante_coins", 0))
	_finish_pvp(w == _local_player_idx)

## Host/referee: player_idx surrenders → the other player wins.
func _apply_remote_surrender(player_idx: int) -> void:
	if _pvp_ended:
		return
	_pvp_ended = true
	var winner_idx: int = 1 - player_idx
	_state.players[player_idx].hero.health = 0
	_broadcast_state()
	if _net != null:
		_net.rpc("pvp_ended", {"winner_idx": winner_idx, "forfeit": true, "ante_coins": pvp_ante_coins})
		for spec_id in _spectators:
			_net.rpc_id(spec_id, "pvp_ended", {"winner_idx": winner_idx, "forfeit": true, "ante_coins": 0})
	_finish_pvp(_local_player_idx >= 0 and winner_idx == _local_player_idx)

## Local surrender request (from the pause menu Flee). Host ends immediately;
## client tells the host, which marks it the loser and ends for both.
## Referee (_local_player_idx < 0) has no local player — nothing to do.
func _pvp_surrender() -> void:
	if _pvp_ended or _local_player_idx < 0:
		return
	if _is_pvp_host():
		_pvp_ended = true
		_state.players[_local_player_idx].hero.health = 0
		_broadcast_state()
		if _net != null:
			_net.rpc("pvp_ended", {"winner_idx": 1 - _local_player_idx, "forfeit": true, "ante_coins": pvp_ante_coins})
			for spec_id in _spectators:
				_net.rpc_id(spec_id, "pvp_ended", {"winner_idx": 1 - _local_player_idx, "forfeit": true, "ante_coins": 0})
		_finish_pvp(false)
	else:
		_send_intent(BattleNetProtocol.encode_surrender())

## Disconnect = forfeit win for whoever remains.
func _on_pvp_peer_disconnected(_pid: int) -> void:
	if not _pvp or _pvp_ended:
		return
	_pvp_ended = true
	if _is_pvp_host():
		_broadcast_state()
	_finish_pvp(true)

func _on_pvp_session_ended() -> void:
	if not _pvp or _pvp_ended:
		return
	_pvp_ended = true
	_finish_pvp(true)

## Shows the synced duel-style result overlay and emits the SceneManager
## completion signal once dismissed. Headless referee has no _result_ui —
## emit the signal directly. Spectators dismiss back to world too.
func _finish_pvp(did_win: bool) -> void:
	_disconnect_pvp_net_signals()
	# Remove self from spectator list if we are one (cleanup on battle end).
	if _pvp_spectating and _net != null:
		_net.rpc_id(1, "stop_spectate")
	if _result_ui != null:
		_result_ui.show_pvp_result(did_win, pvp_ante_coins if did_win else -pvp_ante_coins)
	elif _local_player_idx < 0:
		GameBus.pvp_battle_ended.emit(false)
	elif _pvp_spectating:
		GameBus.pvp_battle_ended.emit(false)


# ── Spectator handlers (GID-101 / TID-367) ───────────────────────────────────

## Host: a peer wants to spectate — add them to the list and send the current state.
func _on_spectate_request(sender: int) -> void:
	if not _is_pvp_host() or _pvp_ended:
		return
	if not _spectators.has(sender):
		_spectators.append(sender)
	if _net != null and _state != null:
		var payload: Dictionary = BattleNetProtocol.encode_state(_state.to_dict(), _state_seq)
		_net.rpc_id(sender, "sync_state", payload)


## Host: a spectator is leaving — remove them from the list.
func _on_stop_spectate(sender: int) -> void:
	_spectators.erase(sender)


## Spectator: receives state mirrors via the same _on_pvp_state path (reused).
## The _pvp_spectating flag ensures _can_local_act() returns false so no input fires.

# ── Co-op PvE joint battle (GID-099) ─────────────────────────────────────────

const _CoopBattleScaling = preload("res://game_logic/battle/CoopBattleScaling.gd")

## Builds the relay node + canonical co-op state. Authority builds N ally states +
## the scaled boss; each client waits for the first sync_coop_state mirror.
func _setup_coop_pve_battle() -> void:
	_state = GameState.new()
	_resolver.setup(_state)
	_wire_gamebus_emitter()
	_net = _BattleNetSyncScript.new()
	_net.name = "BattleNetSync"
	add_child(_net)
	_net.battle_scene = self
	_connect_pvp_net_signals()  # reuse PvP disconnect handlers
	if _is_pvp_host():
		_build_coop_pve_state()
		# Boss skips start_turn (AI acts on boss's turn via _run_ai_turn in _on_turn_ended).
		_state.players[_my_idx()].start_turn(1)

## Authority-only: build N-player co-op GameState from ally decks + enemy_data.
func _build_coop_pve_state() -> void:
	var n: int = maxi(1, _coop_ally_decks.size())
	var boss_hp_base: int = int(enemy_data.get("boss_hp", 30))
	if boss_hp_base <= 0:
		boss_hp_base = 30
	var enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var base_tier: int = EnemyRegistry.get_difficulty_tier(enemy_type) if enemy_type != "" else 1
	if bool(enemy_data.get("is_boss", false)):
		base_tier = 4
	var scaled_hp: int = _CoopBattleScaling.scale_boss_hp(boss_hp_base, n)
	var scaled_tier: int = _CoopBattleScaling.scale_boss_tier(base_tier, n)
	var fallback: Array[String] = ["ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul"]
	var p_idx_ref: Array[int] = [0]  # closure-safe counter
	_state.setup_coop_battle(n,
		func(ally_idx: int, ally: PlayerState) -> void:
			var deck_arr: Array = _coop_ally_decks[ally_idx] if ally_idx < _coop_ally_decks.size() else []
			var insts: Array[Dictionary] = []
			for inst in deck_arr:
				if inst is Dictionary:
					insts.append(inst)
			if insts.size() > 0:
				ally.build_deck_from_instances(insts)
			else:
				ally.build_deck(fallback)
			ally.draw_opening_hand(4)
			p_idx_ref[0] += 1,
		func(boss_ps: PlayerState) -> void:
			var raw: Array = enemy_data.get("enemy_deck", [])
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
	if not _is_pvp_client():
		return
	var decoded: Dictionary = BattleNetProtocol.decode_state(payload)
	if not bool(decoded["valid"]):
		return
	var seq: int = int(decoded["seq"])
	if seq <= _last_applied_seq:
		return
	_last_applied_seq = seq
	_pvp_pending = false
	var state_dict: Dictionary = decoded["state"]
	_state = GameState.new()
	_state.from_dict(state_dict)
	_wire_gamebus_emitter()
	_bump_card_next_id(_state)
	if not _state.turn_ended.is_connected(_on_turn_ended):
		_state.turn_ended.connect(_on_turn_ended)
	_resolver.setup(_state)
	_fx.set_game_state(_state)
	_view.set_battle_state(_state, enemy_data)
	_refresh_all()
	_refresh_potion_button()

## Authority: validate + apply an ally client's intent for the co-op battle.
func _on_coop_intent(sender: int, payload: Dictionary) -> void:
	if not _is_pvp_host() or not _coop_pve:
		return
	var intent: Dictionary = BattleNetProtocol.decode_intent(payload)
	var t: String = str(intent["type"])
	if t == "":
		return
	# Map peer → ally_idx. Host-as-ally-0 never sends intents to itself.
	var acting_idx: int = int(_coop_peer_to_idx.get(sender, -1))
	if acting_idx < 0:
		return
	if t == BattleNetProtocol.INTENT_SURRENDER:
		# Ally surrenders: mark that ally dead (spectating) and broadcast.
		_state.players[acting_idx].hero.health = 0
		_broadcast_coop_state()
		_coop_pve_check_game_over()
		return
	if _state.current_player_idx != acting_idx:
		_broadcast_coop_state()
		return
	# Resolve opponent index for this intent (always the boss in ally turns).
	var changed: bool = _apply_remote_intent(intent, acting_idx)
	if changed:
		_refresh_all()
		_coop_pve_check_game_over()
	else:
		_broadcast_coop_state()

## Host: a client asked for the current co-op state — send it.
func _on_coop_sync_request() -> void:
	if _is_pvp_host() and _coop_pve:
		_broadcast_coop_state()

## Authority: broadcast the full canonical co-op state.
func _broadcast_coop_state() -> void:
	if not _is_pvp_host() or _net == null:
		return
	_state_seq += 1
	_net.rpc("sync_coop_state", BattleNetProtocol.encode_state(_state.to_dict(), _state_seq))

## Authority-only: detect co-op battle end, compute rewards, and broadcast.
func _coop_pve_check_game_over() -> void:
	if not _is_pvp_host():
		return
	if _state.is_game_over():
		if _coop_ended:
			return
		_coop_ended = true
		var w: int = _state.winner()
		var did_win: bool = (w == 0)  # 0 = party wins
		_broadcast_coop_state()
		var reward_payload: Dictionary = _build_coop_reward_payload(did_win)
		if _net != null:
			_net.rpc("coop_battle_ended", reward_payload)
		_finish_coop_pve(did_win, reward_payload)
		return
	_broadcast_coop_state()

## Computes the reward payload for the co-op battle result.
## Each ally gets: full coins, full XP, and the soulbound card (if won).
func _build_coop_reward_payload(did_win: bool) -> Dictionary:
	if not did_win:
		return {"winner_ally": false, "card_id": "", "rarity": "", "stats": {}, "coins": 0, "xp": 0}
	var enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var is_boss: bool = bool(enemy_data.get("is_boss", false))
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
	return {"winner_ally": true, "card_id": card_id, "rarity": rarity, "stats": stats, "coins": coins, "xp": xp}

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
		_fx.haptic(120)
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
		_fx.haptic(80)
	# Minimal result: show HUD message and return. Full ceremony is GID-100.
	var msg: String = "Party victorious!" if did_win else "The party was defeated."
	GameBus.hud_message_requested.emit(msg)
	await get_tree().create_timer(2.0, false).timeout
	GameBus.coop_pve_battle_ended.emit(did_win)

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
	sm.add_card_instance(card_id, rarity, atk, hp, cst)

## Co-op PvE retry sync (mirrors _process for PvP).
var _coop_sync_retry_accum: float = 0.0
func _process_coop_sync(delta: float) -> void:
	if not _coop_pve or not _is_pvp_client() or _last_applied_seq >= 0 or _net == null:
		return
	_coop_sync_retry_accum += delta
	if _coop_sync_retry_accum >= 0.4:
		_coop_sync_retry_accum = 0.0
		_net.rpc_id(1, "request_coop_sync")
