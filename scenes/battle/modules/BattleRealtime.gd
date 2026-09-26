## Real-time battle mode (GID-135 / TID-546 prototype): drives
## `RealtimeCombat` from `_process`, renders its events, and gates player
## plays on the global cooldown. Inert unless `maybe_start()` enabled it —
## Settings > Battle Mode = Real-time / Real-time (slow), solo PvE only (no PvP, co-op, team,
## puzzle, scripted or resumed battles).
##
## A child of BattleScene (`BattleScene.realtime`), created by
## `_ensure_battle_modules()`. Reach the scene as `_battle.<name>`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _TutorialPopup = preload("res://scenes/ui/TutorialPopup.gd")
const _RealtimeVisuals = preload("res://scenes/battle/modules/RealtimeVisuals.gd")

var rt: RealtimeCombat = null
var _battle: _BattleScene
var _gcd_bar: ProgressBar = null
var _swing_bar: ProgressBar = null
var _focus_lbl: Label = null
var _status_box: VBoxContainer = null
var _visuals: _RealtimeVisuals = null
## Player cast in progress: the card, seconds left / total, the deferred
## resolution, and an optional unit target that must still be alive.
var _cast_card: CardInstance = null
var _cast_left: float = 0.0
var _cast_total: float = 0.0
var _cast_finish: Callable = Callable()
var _cast_target: CardInstance = null
var _resolving_cast: bool = false

func _init(battle: _BattleScene) -> void:
	_battle = battle

func is_active() -> bool:
	return rt != null

## Real time applies only to plain solo PvE fights started fresh.
static func eligible(mode_setting: String, is_fresh: bool, networked: bool, puzzle: bool, scripted: bool) -> bool:
	return mode_setting.begins_with("realtime") and is_fresh and not networked and not puzzle and not scripted

func maybe_start(is_fresh: bool) -> void:
	var mode: String = str(SceneManager.save_manager.get_setting("battle_mode", "turn"))
	var networked: bool = _battle._pvp or _battle._coop_pve or _battle._team_pvp or _battle._pvp_spectating
	if not eligible(mode, is_fresh, networked, _battle._state.puzzle_mode, _battle._state.scripted_battle):
		return
	var player_level: int = SceneManager.save_manager.level
	var tier: int = _EnemyRegistry.get_difficulty_tier(str(_battle.enemy_data.get("enemy_type", "")))
	rt = RealtimeCombat.new(_battle._state, [player_level, enemy_level_for_tier(tier)])
	rt.unarmed[RealtimeCombat.ENEMY] = RealtimeCombat.ENEMY_UNARMED_DAMAGE + maxi(0, tier - 1)
	_build_ui()
	_visuals = _RealtimeVisuals.new(_battle)
	_visuals.build(str(_battle.enemy_data.get("enemy_type", "")), bool(_battle.enemy_data.get("is_boss", false)))
	_visuals.set_status_box(_status_box)
	_battle._refresh_all()

func _build_ui() -> void:
	var vh: float = _battle._vh
	_battle._end_turn_btn.visible = false
	_battle._turn_label.visible = false  # no turns in real time
	# Your combat readouts get their own box; RealtimeVisuals places it bottom-right.
	var side: VBoxContainer = _UiUtil.make_vbox(int(vh * 0.006), _battle)
	side.name = "RealtimeStatus"
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_box = side
	var small: int = int(_battle._font(0.018))
	_UiUtil.make_label("Cooldown", small, Color(0.75, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, side)
	_gcd_bar = ProgressBar.new()
	_gcd_bar.min_value = 0.0
	_gcd_bar.max_value = 1.0
	_gcd_bar.show_percentage = false
	_gcd_bar.custom_minimum_size = Vector2(vh * 0.16, vh * 0.03)
	_gcd_bar.tooltip_text = "Global cooldown — full bar = ready to play a card"
	side.add_child(_gcd_bar)
	_UiUtil.make_label("Auto-attack", small, Color(1.0, 0.8, 0.55), HORIZONTAL_ALIGNMENT_CENTER, side)
	_swing_bar = ProgressBar.new()
	_swing_bar.min_value = 0.0
	_swing_bar.max_value = 1.0
	_swing_bar.show_percentage = false
	_swing_bar.custom_minimum_size = Vector2(vh * 0.16, vh * 0.018)
	_swing_bar.modulate = Color(1.0, 0.75, 0.45)
	_swing_bar.tooltip_text = "Auto-attack — your weapon swings when the bar fills"
	side.add_child(_swing_bar)
	_focus_lbl = _UiUtil.make_label("Target: enemy hero", int(_battle._font(0.022)), Color(1.0, 0.85, 0.5),
			HORIZONTAL_ALIGNMENT_CENTER, side)
	_focus_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_focus_lbl.custom_minimum_size = Vector2(vh * 0.26, 0.0)

## Enemy level-equivalent for mana until zone levels land (TID-536): tier 1 → 1, each tier +3.
static func enemy_level_for_tier(tier: int) -> int:
	return 1 + maxi(0, tier - 1) * 3

## The clock stops while the player is reading something: pause menu, card
## inspect (long-press), the first-battle tip, or any tutorial popup.
func is_blocked() -> bool:
	if _battle._pause_ui.is_paused():
		return true
	if is_instance_valid(_battle._inspect_overlay) or is_instance_valid(_battle._tutorial_overlay):
		return true
	return not get_tree().get_nodes_in_group(_TutorialPopup.MODAL_GROUP).is_empty()

## True while the local player is on global cooldown or mid-cast (blocks plays).
func on_cooldown() -> bool:
	return rt != null and (not rt.gcd_ready(RealtimeCombat.PLAYER) or _cast_card != null)

## Called after any successful local card play. A cast's GCD already started
## when the cast began, so its resolution doesn't restart it.
func note_player_play(player_idx: int) -> void:
	if rt != null and player_idx == RealtimeCombat.PLAYER and not _resolving_cast:
		rt.start_gcd(RealtimeCombat.PLAYER)

## Real time: starts a visible cast for `card` and runs `finish` when it
## completes (the GCD starts now — it is only the minimum between actions).
## Returns false when the caller should resolve immediately: turn-based mode,
## or a 0-cost instant. A unit `target` that dies mid-cast fizzles the spell
## (card stays in hand, no mana spent).
func run_cast(card: CardInstance, finish: Callable, target: CardInstance = null) -> bool:
	if rt == null or _cast_card != null:
		return false
	var t: float = RealtimeCombat.cast_time_for(card.cost)
	if t <= 0.0:
		return false
	_cast_card = card
	_cast_total = t
	_cast_left = t
	_cast_finish = finish
	_cast_target = target
	rt.start_gcd(RealtimeCombat.PLAYER)
	_battle._refresh_all()
	return true

func _tick_cast(dt: float) -> void:
	if _cast_card == null:
		return
	_cast_left -= dt
	if _cast_left > 0.0:
		return
	var finish: Callable = _cast_finish
	var target: CardInstance = _cast_target
	_cast_card = null
	_cast_finish = Callable()
	_cast_target = null
	if target != null and not (target.is_alive() and _target_on_board(target)):
		_visuals.toast("Target lost — spell fizzled")
		_battle._refresh_all()
		return
	_resolving_cast = true
	finish.call()
	_resolving_cast = false

func _target_on_board(c: CardInstance) -> bool:
	for p: PlayerState in _battle._state.players:
		if p.board.get_cards().has(c):
			return true
	return false

func _cast_info() -> Dictionary:
	if _cast_card == null:
		return {}
	return {"name": _cast_card.name, "fraction": 1.0 - _cast_left / _cast_total,
		"cost": _battle._state.players[RealtimeCombat.PLAYER].effective_cost(_cast_card)}

## Tap on an enemy minion with no Ally selected: focus it for the hero's auto-attack;
## tapping it again, or tapping the enemy hero (null), goes back to the hero.
func set_focus(target: CardInstance) -> void:
	if rt == null:
		return
	rt.focus_target = null if (target == null or rt.focus_target == target) else target
	_update_focus_label()

func _update_focus_label() -> void:
	if _focus_lbl == null:
		return
	var t: CardInstance = rt.focus_target
	_focus_lbl.text = "Target: %s" % (t.name if t != null else "enemy hero")

func _process(delta: float) -> void:
	# Also hold the clock during a commanded Ally attack's lunge (`_action_busy`):
	# a swing landing mid-resolution could remove its attacker or target.
	if rt == null or _battle._state.is_game_over() or is_blocked() or _battle._action_busy:
		return
	var dt: float = delta * _speed_factor()
	_tick_cast(dt)
	if _battle._state.is_game_over():
		return
	var snap: Array[Dictionary] = _battle._fx.snapshot()
	var events: Array[Dictionary] = rt.advance(dt)
	if _gcd_bar != null:
		_gcd_bar.value = rt.gcd_fraction(RealtimeCombat.PLAYER)
	if _swing_bar != null:
		_swing_bar.value = rt.hero_swing_fraction(RealtimeCombat.PLAYER)
	# Mana ticks every frame in points; the labels are cheap to update, the full
	# board refresh only runs on events (a whole cost unit, swings, casts).
	_battle._view.refresh_hero(_battle._player_hero_view, _battle._state.players[RealtimeCombat.PLAYER].hero, false)
	_battle._update_status()
	_visuals.update(rt, _cast_info())
	if events.is_empty():
		return
	var swings: Array[Dictionary] = []
	for ev: Dictionary in events:
		match str(ev.get("type", "")):
			"swing":
				swings.append(ev)
			"enemy_cast":
				_after_enemy_play(ev["card"] as CardInstance)
	if not swings.is_empty():
		AudioManager.play_sfx("attack")
		_battle._fx.trigger_fx(snap)
		# Death ghosts are built synchronously from the old panels, so the
		# board can rebuild straight away without awaiting the tween.
		_battle._animate_deaths_from_snapshot(snap)
	_update_focus_label()
	_battle._refresh_all()
	for ev: Dictionary in swings:
		_animate_swing(ev)
	_battle._check_game_over()

## Lunge the attacker (hero token or enemy unit) at its target.
func _animate_swing(ev: Dictionary) -> void:
	var side: int = int(ev.get("side", 0))
	var target: CardInstance = ev.get("target") as CardInstance
	var to: Vector2 = _visuals.target_pos(target, 1 - side)
	var attacker: CardInstance = ev.get("attacker") as CardInstance
	if attacker == null:
		_visuals.lunge_token(side, to)
		return
	var panel: Control = _battle._fx.get_card_panel(attacker, side == RealtimeCombat.ENEMY)
	if panel != null:
		_battle._fx.animate_attack(panel, to, 1.0)

## Mirrors the post-action steps of BattleScene._execute_ai_actions.
func _after_enemy_play(card: CardInstance) -> void:
	var ai_idx: int = RealtimeCombat.ENEMY
	_battle._resolver.flush_auto_spells(ai_idx)
	if card.card_class != "spell":
		_battle._resolver.resolve_emergence(card, ai_idx)
		_battle.modifiers._apply_weather_to_summoned(card, ai_idx)
		GameBus.card_played.emit(card.template_id, "board", _battle._state.players[ai_idx].board.slots.find(card))
	else:
		GameBus.card_played.emit(card.template_id, "spell", -1)

## Clock rate: "realtime_slow" (tactical) runs at 60 %, and the Fast battle-speed
## setting runs real time 25 % quicker. Plain inverse of `_speed_scale` would be 2.2×.
func _speed_factor() -> float:
	var mode: String = str(SceneManager.save_manager.get_setting("battle_mode", "turn"))
	if mode == "realtime_slow":
		return 0.6
	return 1.25 if _battle._speed_scale < 1.0 else 1.0
