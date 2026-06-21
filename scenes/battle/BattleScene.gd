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
const SettingsScene = preload("res://scenes/ui/SettingsScene.gd")
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

var _fx: BattleFx
var _view: CardViewBuilder
var _resolver: SpellEffectResolver

var enemy_data: Dictionary = {}
var duel_wager: int = 0
var puzzle_data: Resource = null  # PuzzleData set by SceneManager before _ready

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
var _boss_banner: Control = null
const _BOSS_BANNER_DURATION: float = 2.5
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

# Drag-to-play: hand card being dragged onto the board
var _hand_drag_card: CardInstance = null
var _drag_visual: Control = null
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _cancel_btn: Button = null

# Card inspect overlay
var _inspect_overlay: Control = null

# Battle speed (TID-254): 1.0 = normal, 0.45 = fast
var _speed_scale: float = 1.0

# Battle pause
var _paused: bool = false
var _pause_overlay: CanvasLayer = null

# Spell targeting (TID-058, extended TID-141)
var _targeting_spell: CardInstance = null
var _targeting_active: bool = false
var _targeting_friendly: bool = false

# Slot targeting (TID-294)
var _slot_targeting_spell: CardInstance = null

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
	var _saved_battle: Dictionary = SceneManager.save_manager.pending_battle_state
	if puzzle_data != null:
		_puzzle_data_ref = puzzle_data
		_state = GameState.new()
		_resolver.setup(_state)
		_state.load_puzzle(puzzle_data)
	elif not _saved_battle.is_empty():
		_state = GameState.new()
		_resolver.setup(_state)
		_state.from_dict(_saved_battle)
		_boss_phase2_triggered = bool(_saved_battle.get("_boss_phase2", false))
		_hero_power_used = bool(_saved_battle.get("_hero_power_used", false))
		_bump_card_next_id(_state)
		SceneManager.save_manager.clear_pending_battle_state()
	else:
		_state = GameState.new()
		_resolver.setup(_state)

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
			_show_boss_banner()

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

	# Initialise capture tracker for the current enemy (no-op for puzzles/duels).
	if not _state.puzzle_mode and not _state.friendly_duel:
		var _ct_enemy_type: String = str(enemy_data.get("enemy_type", ""))
		var _ct_condition: String = EnemyRegistry.get_capture_condition(_ct_enemy_type)
		var _ct_param: int = EnemyRegistry.get_capture_param(_ct_enemy_type)
		_capture_tracker = CaptureTracker.new(_ct_condition, _ct_param)
		_resolver.capture_tracker = _capture_tracker

	_end_turn_btn.pressed.connect(_on_end_turn)
	_menu_btn.pressed.connect(_confirm_return_to_menu)
	_enemy_hero_view.gui_input.connect(_on_enemy_hero_input)
	_add_pause_button()
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
# Drag/Drop — scene-level input catches mouse move and release globally
# -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
				return  # overlay handles its own Escape
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return

	if _hand_drag_card == null:
		return

	if event is InputEventMouseMotion:
		_drag_moved = true
		if _drag_visual:
			_drag_visual.position = get_viewport().get_mouse_position() - _drag_visual.size * 0.5
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if not _drag_moved:
				# Tap without drag — enter slot-select or inspect
				var card_tapped := _hand_drag_card
				_cancel_hand_drag()
				_on_hand_card_tap(card_tapped)
			else:
				_finish_hand_drag()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_hand_drag()
			get_viewport().set_input_as_handled()

func _finish_hand_drag() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var board_rect: Rect2 = _player_board_view.get_global_rect()
	if board_rect.has_point(mouse_pos):
		var played_card := _hand_drag_card
		# Targeted spells: enter appropriate targeting mode
		var is_enemy_targeted: bool = SpellEffectResolver.ENEMY_TARGETED_EFFECTS.has(played_card.spell_effect)
		var is_friendly_targeted: bool = SpellEffectResolver.FRIENDLY_TARGETED_EFFECTS.has(played_card.spell_effect)
		var is_slot_targeted: bool = SpellEffectResolver.SLOT_TARGETED_EFFECTS.has(played_card.spell_effect)
		if played_card.card_class == "spell" and is_slot_targeted and _state.players[0].can_play(played_card):
			_hand_drag_card = null
			if _drag_visual:
				_drag_visual.queue_free()
				_drag_visual = null
			_hide_cancel_btn()
			_enter_slot_targeting_mode(played_card)
			return
		if played_card.card_class == "spell" and (is_enemy_targeted or is_friendly_targeted) and _state.players[0].can_play(played_card):
			# Refuse targeted spells when there are no valid targets — return to hand.
			if is_friendly_targeted and _state.players[0].board.get_cards().is_empty():
				_cancel_hand_drag()
				return
			elif is_enemy_targeted and played_card.spell_effect != "deal_damage_single" and _state.players[1].board.get_cards().is_empty():
				_cancel_hand_drag()
				return
			else:
				_hand_drag_card = null
				if _drag_visual:
					_drag_visual.queue_free()
					_drag_visual = null
				_hide_cancel_btn()
				_enter_targeting_mode(played_card, is_friendly_targeted)
				return
		# Minions: find which slot the mouse is over
		if played_card.card_class != "spell":
			var target_slot_idx: int = _slot_idx_at_point(mouse_pos, _player_board_view)
			if target_slot_idx == -1 or _state.players[0].board.slots[target_slot_idx] != null:
				_cancel_hand_drag()
				return
			if _do_play_card_at_slot(played_card, 0, target_slot_idx):
				AudioManager.play_sfx("card_play")
				_fx.haptic(20)
				if played_card.emergence_effect != "":
					var snap_em := _fx.snapshot()
					_resolver.resolve_emergence(played_card, 0)
					_fx.trigger_fx(snap_em)
				else:
					_apply_weather_to_summoned(played_card, 0)
				_refresh_all()
				_check_game_over()
				_dismiss_battle_tutorial()
		else:
			# Non-targeted spells: slot doesn't matter
			if _do_play_card(played_card, 0):
				AudioManager.play_sfx("card_play")
				_fx.haptic(20)
				var snap_fhd := _fx.snapshot()
				_resolver.resolve_spell(played_card, 0)
				_fx.trigger_fx(snap_fhd)
				_refresh_all()
				_check_game_over()
				_dismiss_battle_tutorial()
	_cancel_hand_drag()

func _cancel_hand_drag() -> void:
	_hide_cancel_btn()
	if _drag_visual:
		_drag_visual.queue_free()
		_drag_visual = null
	_hand_drag_card = null
	_refresh_player_board()

func _start_hand_drag(card: CardInstance, from_pos: Vector2) -> void:
	_hand_drag_card = card
	_drag_start_pos = from_pos
	_drag_moved = false
	if not _state.players[0].can_play(card):
		# Still track for tap-to-inspect; don't show drag ghost for unplayable
		return
	_drag_visual = _make_card_ghost(card)
	_drag_visual.position = from_pos - _drag_visual.size * 0.5
	_drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_visual)
	move_child(_drag_visual, get_child_count() - 1)
	_show_cancel_btn("✕ Cancel", _cancel_hand_drag)
	# Trigger board refresh so slot panels update to highlight state
	_refresh_player_board()

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
	var cb: Callable = callback if callback.is_valid() else _cancel_hand_drag
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
				if _do_play_card_at_slot(card, 0, slot_idx):
					AudioManager.play_sfx("card_play")
					_fx.haptic(20)
					if card.emergence_effect != "":
						var snap_se := _fx.snapshot()
						_resolver.resolve_emergence(card, 0)
						_fx.trigger_fx(snap_se)
					else:
						_apply_weather_to_summoned(card, 0)
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
	if not _state.players[0].can_play(spell):
		return
	_do_play_card(spell, 0)
	AudioManager.play_sfx("spell_resolve")
	_fx.haptic(20)
	match spell.spell_effect:
		"bless_slot":
			_state.players[0].board.enhance_slot(slot_idx, "atk_bonus", spell.spell_power)
		"ward_slot":
			_state.players[0].board.enhance_slot(slot_idx, "shroud", 1)
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

func _add_pause_button() -> void:
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(_vh * 0.055, _vh * 0.055)
	pause_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(_toggle_pause)
	$SidePanel.add_child(pause_btn)
	$SidePanel.move_child(pause_btn, 0)

func _toggle_pause() -> void:
	if _paused:
		_hide_pause_overlay()
	else:
		_show_pause_overlay()

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
	_potion_btn.disabled = _used_potion_this_battle or not has_potions or _state.current_player_idx != 0
	_potion_btn.visible = has_potions

func _on_potion_button_pressed() -> void:
	if _used_potion_this_battle or _state.current_player_idx != 0:
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
	var player: PlayerState = _state.players[0]
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
	var active_skill: SkillData = _get_active_skill()
	if active_skill == null:
		return
	_hero_power_used = true
	if _hero_power_btn != null:
		_hero_power_btn.disabled = true
	var player: PlayerState = _state.players[0]
	var enemy: PlayerState = _state.players[1]
	match active_skill.effect_type:
		"active_damage_all":
			for card: CardInstance in enemy.board.get_cards().duplicate():
				card.take_damage(active_skill.effect_value)
				if not card.is_alive():
					enemy.board.remove_card(card)
					enemy.discard.append(card)
		"active_heal":
			player.hero.health = mini(
				player.hero.health + active_skill.effect_value,
				player.hero.max_health)
		"active_draw":
			for _i in active_skill.effect_value:
				player.draw_card()
			_resolver.flush_auto_spells(0)
		"active_mana":
			player.hero.mana = mini(
				player.hero.mana + active_skill.effect_value,
				player.hero.max_mana)
	_refresh_all()

func _show_pause_overlay() -> void:
	if _paused:
		return
	_paused = true
	get_tree().paused = true
	if _float_layer:
		_float_layer.hide()

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause_overlay = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.55
	var panel_h: float = _vh * 0.52
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.97)
	style.corner_radius_top_left    = 12
	style.corner_radius_top_right   = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(_vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.03))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.03))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.025))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", int(_vh * 0.05))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(_vh * 0.3, _vh * 0.07)
	resume_btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(_hide_pause_overlay)
	vbox.add_child(resume_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(_vh * 0.3, _vh * 0.07)
	settings_btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	settings_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_btn.pressed.connect(_open_settings_from_pause)
	vbox.add_child(settings_btn)

	var flee_btn := Button.new()
	flee_btn.text = "Flee Battle"
	flee_btn.custom_minimum_size = Vector2(_vh * 0.3, _vh * 0.07)
	flee_btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	flee_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	flee_btn.pressed.connect(_on_flee_pressed)
	vbox.add_child(flee_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(_vh * 0.3, _vh * 0.07)
	menu_btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.pressed.connect(_confirm_return_to_menu)
	vbox.add_child(menu_btn)

func _on_flee_pressed() -> void:
	get_tree().paused = false
	_paused = false
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null
	GameBus.battle_fled.emit()

func _hide_pause_overlay() -> void:
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null
	if _float_layer:
		_float_layer.show()

func _open_settings_from_pause() -> void:
	var overlay: SettingsScene = SettingsScene.new()
	_pause_overlay.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.closed.connect(overlay.queue_free)

func _confirm_return_to_menu() -> void:
	# Simple inline confirm dialog
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var dialog := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.05, 0.05, 0.98)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	dialog.add_theme_stylebox_override("panel", style)
	var dlg_w: float = vp.x * 0.5
	var dlg_h: float = _vh * 0.28
	dialog.custom_minimum_size = Vector2(dlg_w, dlg_h)
	dialog.position = Vector2((vp.x - dlg_w) * 0.5, (vp.y - dlg_h) * 0.5)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vh * 0.025))
	margin.add_theme_constant_override("margin_right",  int(_vh * 0.025))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.025))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.025))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.022))
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Return to menu?\nYour battle will be saved."
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(_vh * 0.03))
	vbox.add_child(row)

	var yes_btn := Button.new()
	yes_btn.text = "Yes, leave"
	yes_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.065)
	yes_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	yes_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	yes_btn.pressed.connect(func() -> void:
		if not _state.puzzle_mode and not _state.is_game_over():
			SceneManager.save_manager.set_pending_battle_state(_make_battle_save())
		SceneManager.save_manager.save()
		get_tree().paused = false
		SceneManager.go_to_menu()
	)
	row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.065)
	no_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	no_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	no_btn.pressed.connect(dialog.queue_free)
	row.add_child(no_btn)

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
		if _state != null and not _state.puzzle_mode and not _state.is_game_over():
			SceneManager.save_manager.set_pending_battle_state(_make_battle_save())
			SceneManager.save_manager.save()
		if not _paused:
			_show_pause_overlay()

func _on_target_chosen_card(target: CardInstance) -> void:
	var spell := _targeting_spell
	_targeting_active = false
	_targeting_friendly = false
	_targeting_spell = null
	_hide_cancel_btn()
	if _do_play_card(spell, 0):
		AudioManager.play_sfx("card_play")
		_fx.haptic(20)
		var snap_otc := _fx.snapshot()
		_resolver.resolve_spell(spell, 0, {"type": "minion", "card": target})
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
	if _do_play_card(spell, 0):
		AudioManager.play_sfx("card_play")
		_fx.haptic(20)
		var snap_oth := _fx.snapshot()
		_resolver.resolve_spell(spell, 0, {"type": "hero"})
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
	_view.update_context(
		_targeting_active, _targeting_friendly,
		_dragged_card, _hand_drag_card,
		_slot_targeting_spell, _slot_select_card
	)
	_view.refresh_zone(_enemy_hand_view, _state.players[1].hand, "enemy_hand")
	_view.refresh_board_zone(_enemy_board_view, _state.players[1].board, "enemy_board")
	_view.refresh_board_zone(_player_board_view, _state.players[0].board, "board")
	_view.refresh_zone(_player_hand_view, _state.players[0].hand, "hand")
	_view.refresh_hero(_enemy_hero_view, _state.players[1].hero, true)
	_view.refresh_hero(_player_hero_view, _state.players[0].hero, false)
	_update_status()

func _refresh_player_board() -> void:
	_view.update_context(
		_targeting_active, _targeting_friendly,
		_dragged_card, _hand_drag_card,
		_slot_targeting_spell, _slot_select_card
	)
	_view.refresh_board_zone(_player_board_view, _state.players[0].board, "board")

func _bind_card_input(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	for conn in panel.gui_input.get_connections():
		panel.gui_input.disconnect(conn["callable"])
	if zone_id == "hand" and _state.current_player_idx == 0:
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_hand_card_input(event, card, panel))
	elif zone_id == "board" and _state.current_player_idx == 0:
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
	var player := _state.players[0]
	_turn_label.text = "Turn %d" % _state.turn_number
	_mana_label.text = "Mana: %d/%d" % [player.hero.mana, player.hero.max_mana]
	_end_turn_btn.disabled = _state.current_player_idx != 0 or _ai_thinking

# -------------------------------------------------------------------------
# Input handlers
# -------------------------------------------------------------------------

func _on_hand_card_input(event: InputEvent, card: CardInstance, panel: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _state.current_player_idx != 0 or _ai_thinking:
				return
			_start_hand_drag(card, panel.get_global_rect().get_center())

func _on_hand_card_tap(card: CardInstance) -> void:
	if _state.current_player_idx != 0 or _ai_thinking:
		return
	if card.card_class != "spell" and _state.players[0].can_play(card):
		_enter_slot_select_mode(card)
	elif SpellEffectResolver.SLOT_TARGETED_EFFECTS.has(card.spell_effect) and _state.players[0].can_play(card):
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
		var valid_targets: Array[CardInstance] = _view.get_ward_valid_targets(_state.players[1].board.get_cards())
		if not valid_targets.has(target):
			return  # keep attacker selected; player must click a Ward minion
		_execute_attack(attacker, target)

func _on_enemy_hero_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _targeting_active and not _targeting_friendly:
			_on_target_chosen_hero()
			return
		if _state.current_player_idx != 0 or _ai_thinking:
			return
		if _dragged_card.is_empty():
			return
		var attacker: CardInstance = _dragged_card["card"]
		if not attacker.can_attack():
			_dragged_card.clear()
			_refresh_all()
			return
		# Ward: cannot attack hero while any Ward minion is alive on enemy board
		for ec: CardInstance in _state.players[1].board.get_cards():
			if ec.keywords.has(Keywords.WARD):
				return  # keep attacker selected; player must target the Ward minion
		_execute_attack(attacker, null)

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
	if _state.current_player_idx != 0 or _ai_thinking:
		return
	_cancel_hand_drag()
	_dragged_card.clear()
	if _state.puzzle_mode:
		if not _state.is_game_over():
			_show_puzzle_fail()
		return
	_state.end_turn()

func _on_turn_ended(player_idx: int) -> void:
	GameBus.turn_ended.emit(player_idx)
	var snap_sot := _fx.snapshot()
	_fx.process_start_of_turn_statuses(player_idx)
	# Desert biome rule: leftmost minion on each board takes 1 damage at turn start (daytime only).
	if _state.battlefield_biome == BattlefieldRules.BIOME_DESERT and not _state.is_night:
		_apply_desert_scorch()
	_snow_discount_used[player_idx] = false
	if _battle_weather == "blizzard" and _state.turn_number <= 2:
		for card: CardInstance in _state.players[player_idx].board.get_cards():
			card.apply_status("freeze", 1)
	_fx.trigger_fx(snap_sot)
	_refresh_all()
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

func _show_boss_banner() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = int(_vh * 0.045)
	var enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var lbl := Label.new()
	lbl.text = "* %s *" % EnemyRegistry.get_display_name(enemy_type)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x, font_size * 2)
	lbl.position = Vector2(0.0, _vh * 0.08)
	add_child(lbl)
	move_child(lbl, get_child_count() - 1)
	if _boss_banner != null and is_instance_valid(_boss_banner):
		_boss_banner.queue_free()
	_boss_banner = lbl
	_start_banner_fade(lbl)

func _start_banner_fade(banner: Control) -> void:
	var tween := create_tween()
	tween.tween_interval(_BOSS_BANNER_DURATION - 0.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(banner):
			banner.queue_free()
		if _boss_banner == banner:
			_boss_banner = null
	)

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
	# Show phase 2 announcement banner
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = int(_vh * 0.04)
	var lbl := Label.new()
	lbl.text = "- PHASE 2 -"
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x, font_size * 2)
	lbl.position = Vector2(0.0, _vh * 0.4)
	add_child(lbl)
	move_child(lbl, get_child_count() - 1)
	if _boss_banner != null and is_instance_valid(_boss_banner):
		_boss_banner.queue_free()
	_boss_banner = lbl
	_start_banner_fade(lbl)

func _check_game_over() -> void:
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
				_show_duel_victory_overlay(_state.wager_coins)
			else:
				AudioManager.play_sfx("battle_lose")
				_fx.haptic(80)
				_show_duel_loss_overlay(_state.wager_coins)
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
				_show_victory_overlay_boss(pool, weapon_reward_id, boss_rarities, boss_stats_list, coins_win, xp_win)
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
					_show_soulbind_overlay(reward_card_id, _ct_sig, _capture_tracker.condition_text())
				elif not _ct_sig.is_empty() and not _ct_captured:
					var _ct_text: String = _capture_tracker.condition_text() if _capture_tracker != null else ""
					_show_victory_overlay(reward_card_id, "", _ct_sig, _ct_text, false, rolled_rarity, rolled_stats, coins_win, xp_win)
				else:
					_show_victory_overlay(reward_card_id, "", "", "", false, rolled_rarity, rolled_stats, coins_win, xp_win)
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

func _show_victory_overlay(reward_card_id: String, weapon_reward_id: String = "",
		sig_card_id: String = "", condition_text_arg: String = "", condition_met: bool = false,
		reward_rarity: String = "", reward_stats: Dictionary = {},
		coins_earned: int = 0, xp_earned: int = 0) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Victory!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title_lbl)

	var reward_lbl := Label.new()
	if reward_card_id != "":
		var tmpl: Dictionary = CardRegistry.get_template(reward_card_id)
		var card_name: String = str(tmpl.get("name", reward_card_id))
		var rarity_suffix: String = " [%s]" % reward_rarity.capitalize() if reward_rarity != "" else ""
		reward_lbl.text = "You earned: " + card_name + rarity_suffix
		if reward_rarity != "":
			reward_lbl.modulate = _rarity_color(reward_rarity)
	else:
		reward_lbl.text = "No card dropped."
	reward_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward_lbl)

	if coins_earned > 0:
		var coins_lbl := Label.new()
		coins_lbl.text = "+ %d Coins" % coins_earned
		coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coins_lbl.modulate = Color(1.0, 0.85, 0.3)
		vbox.add_child(coins_lbl)

	if xp_earned > 0:
		var xp_lbl := Label.new()
		xp_lbl.text = "+ %d XP" % xp_earned
		xp_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_lbl.modulate = Color(0.5, 1.0, 0.7)
		vbox.add_child(xp_lbl)

	if weapon_reward_id != "":
		var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_reward_id)
		var weapon_lbl := Label.new()
		var wname: String = weapon.display_name if weapon != null else weapon_reward_id
		weapon_lbl.text = "Weapon found: " + wname
		weapon_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_lbl.modulate = Color(0.8, 1.0, 0.5)
		vbox.add_child(weapon_lbl)

	# Hunt-status line: show when a signature is available but condition was not met.
	if sig_card_id != "" and condition_text_arg != "":
		var hunt_lbl := Label.new()
		hunt_lbl.text = "Soulbind: %s — %s" % [condition_text_arg, "MET" if condition_met else "not met"]
		hunt_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		hunt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hunt_lbl.modulate = Color(0.7, 0.5, 1.0)
		hunt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(hunt_lbl)

	var btn := Button.new()
	btn.text = "Collect" if (reward_card_id != "" or weapon_reward_id != "") else "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	var final_card: String = reward_card_id
	var final_weapon: String = weapon_reward_id
	var final_rarity: String = reward_rarity
	var final_stats: Dictionary = reward_stats
	var veterancy_data: Dictionary = _collect_veterancy_data()
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({
			"card_reward": final_card,
			"weapon_reward": final_weapon,
			"hero_hp": _state.players[0].hero.health,
			"veterancy": veterancy_data,
			"reward_rarity": final_rarity,
			"reward_stats": final_stats,
		})
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.85, 0.85, 0.85)
		"rare":      return Color(0.3, 0.6, 1.0)
		"epic":      return Color(0.8, 0.3, 1.0)
		"legendary": return Color(1.0, 0.65, 0.1)
	return Color.WHITE

func _show_soulbind_overlay(reward_card_id: String, sig_card_id: String, condition_text_arg: String) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.12, 0.95)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.028))

	var title_lbl := Label.new()
	title_lbl.text = "Victory!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title_lbl)

	var soul_lbl := Label.new()
	soul_lbl.text = "Soulbind Achieved!"
	soul_lbl.add_theme_font_size_override("font_size", int(_vh * 0.04))
	soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul_lbl.modulate = Color(0.8, 0.4, 1.0)
	vbox.add_child(soul_lbl)

	var cond_lbl := Label.new()
	cond_lbl.text = condition_text_arg
	cond_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	cond_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cond_lbl.modulate = Color(0.75, 0.6, 1.0)
	cond_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(cond_lbl)

	if reward_card_id != "":
		var rtmpl: Dictionary = CardRegistry.get_template(reward_card_id)
		var reward_lbl := Label.new()
		reward_lbl.text = "You earned: " + str(rtmpl.get("name", reward_card_id))
		reward_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(reward_lbl)

	var stmpl: Dictionary = CardRegistry.get_template(sig_card_id)
	var sig_lbl := Label.new()
	sig_lbl.text = "Signature captured: " + str(stmpl.get("name", sig_card_id))
	sig_lbl.add_theme_font_size_override("font_size", int(_vh * 0.032))
	sig_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sig_lbl.modulate = Color(0.9, 0.5, 1.0)
	vbox.add_child(sig_lbl)

	var btn := Button.new()
	btn.text = "Collect All"
	btn.custom_minimum_size = Vector2(_vh * 0.22, _vh * 0.065)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.028))
	var fc: String = reward_card_id
	var sc: String = sig_card_id
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({
			"card_reward": fc,
			"weapon_reward": "",
			"hero_hp": _state.players[0].hero.health,
			"signature_capture": sc,
		})
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)

func _show_victory_overlay_boss(reward_cards: Array[String], weapon_reward_id: String = "",
		rarities: Array[String] = [], stats_list: Array[Dictionary] = [],
		coins_earned: int = 0, xp_earned: int = 0) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.025))

	var title_lbl := Label.new()
	title_lbl.text = "Boss Defeated!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.75, 0.0)
	vbox.add_child(title_lbl)

	if reward_cards.is_empty():
		var no_drop_lbl := Label.new()
		no_drop_lbl.text = "No cards dropped."
		no_drop_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		no_drop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_drop_lbl)
	else:
		for ri in range(reward_cards.size()):
			var cid: String = reward_cards[ri]
			var tmpl: Dictionary = CardRegistry.get_template(cid)
			var card_name: String = str(tmpl.get("name", cid))
			var rarity: String = rarities[ri] if ri < rarities.size() else ""
			var rlbl := Label.new()
			rlbl.text = card_name + (" [%s]" % rarity.capitalize() if rarity != "" else "")
			if rarity != "":
				rlbl.modulate = _rarity_color(rarity)
			rlbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
			rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(rlbl)

	if coins_earned > 0:
		var coins_lbl := Label.new()
		coins_lbl.text = "+ %d Coins" % coins_earned
		coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coins_lbl.modulate = Color(1.0, 0.85, 0.3)
		vbox.add_child(coins_lbl)

	if xp_earned > 0:
		var xp_lbl := Label.new()
		xp_lbl.text = "+ %d XP" % xp_earned
		xp_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_lbl.modulate = Color(0.5, 1.0, 0.7)
		vbox.add_child(xp_lbl)

	if weapon_reward_id != "":
		var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_reward_id)
		var weapon_lbl := Label.new()
		var wname: String = weapon.display_name if weapon != null else weapon_reward_id
		weapon_lbl.text = "Weapon found: " + wname
		weapon_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_lbl.modulate = Color(0.8, 1.0, 0.5)
		vbox.add_child(weapon_lbl)

	var btn := Button.new()
	btn.text = "Collect" if (not reward_cards.is_empty() or weapon_reward_id != "") else "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	var final_rewards: Array[String] = []
	final_rewards.assign(reward_cards)
	var final_weapon: String = weapon_reward_id
	var final_rarities: Array[String] = []
	final_rarities.assign(rarities)
	var final_stats_list: Array[Dictionary] = stats_list.duplicate()
	var veterancy_data_boss: Dictionary = _collect_veterancy_data()
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({
			"card_rewards": final_rewards,
			"weapon_reward": final_weapon,
			"hero_hp": _state.players[0].hero.health,
			"veterancy": veterancy_data_boss,
			"reward_rarities": final_rarities,
			"reward_stats_list": final_stats_list,
		})
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)

func _show_duel_victory_overlay(wager: int) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.05, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Duel Won!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.4)
	vbox.add_child(title_lbl)

	var coins_lbl := Label.new()
	coins_lbl.text = "+%d coins" % wager if wager > 0 else "Wager was free!"
	coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(coins_lbl)

	var btn := Button.new()
	btn.text = "Collect"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		if wager > 0:
			SceneManager.save_manager.add_coins(wager)
		GameBus.duel_won.emit()
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)

func _show_duel_loss_overlay(wager: int) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.05, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Duel Lost"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.4, 0.4)
	vbox.add_child(title_lbl)

	var coins_lbl := Label.new()
	coins_lbl.text = "-%d coins" % wager if wager > 0 else "No wager."
	coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.modulate = Color(1.0, 0.6, 0.6)
	vbox.add_child(coins_lbl)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		if wager > 0:
			SceneManager.save_manager.coins = maxi(0, SceneManager.save_manager.coins - wager)
			SceneManager.save_manager.save()
		GameBus.duel_lost.emit()
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)

# -------------------------------------------------------------------------
# Puzzle overlays
# -------------------------------------------------------------------------

func _show_puzzle_fail() -> void:
	const GameState = preload("res://game_logic/battle/GameState.gd")
	_state = GameState.new()
	_state.load_puzzle(_puzzle_data_ref)
	_refresh_all()

	var overlay := PanelContainer.new()
	overlay.name = "PuzzleFailOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.05, 0.88)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var lbl := Label.new()
	lbl.text = "Not quite — try again!"
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.05))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(1.0, 0.5, 0.3)
	vbox.add_child(lbl)

	var hint_lbl := Label.new()
	var pd: Resource = _puzzle_data_ref
	hint_lbl.text = pd.get("hint_text") if pd != null else ""
	hint_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.modulate = Color(0.85, 0.85, 0.85)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(_vh * 0.5, 0)
	vbox.add_child(hint_lbl)

	var btn := Button.new()
	btn.text = "Try Again"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void: overlay.queue_free())
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)


func _show_puzzle_victory() -> void:
	GameBus.puzzle_solved.emit(_state.puzzle_data_id)

	var overlay := PanelContainer.new()
	overlay.name = "PuzzleVictoryOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.10, 0.04, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Puzzle Solved!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.5)
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Reward delivered to your collection."
	sub_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.modulate = Color(0.8, 1.0, 0.8)
	vbox.add_child(sub_lbl)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		SceneManager.return_from_puzzle()
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)


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
