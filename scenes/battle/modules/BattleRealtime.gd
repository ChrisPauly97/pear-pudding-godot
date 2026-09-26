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
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

var rt: RealtimeCombat = null
var _battle: _BattleScene
var _gcd_bar: ProgressBar = null
var _swing_bar: ProgressBar = null
var _focus_lbl: Label = null

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
	_build_ui()
	_battle._refresh_all()

func _build_ui() -> void:
	var vh: float = _battle._vh
	_battle._end_turn_btn.visible = false
	var side: Control = _battle.get_node("SidePanel") as Control
	_gcd_bar = ProgressBar.new()
	_gcd_bar.min_value = 0.0
	_gcd_bar.max_value = 1.0
	_gcd_bar.show_percentage = false
	_gcd_bar.custom_minimum_size = Vector2(vh * 0.16, vh * 0.03)
	_gcd_bar.tooltip_text = "Global cooldown — full bar = ready to play a card"
	side.add_child(_gcd_bar)
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
	_focus_lbl.custom_minimum_size = Vector2(vh * 0.16, 0.0)

## Enemy level-equivalent for mana until zone levels land (TID-536): tier 1 → 1, each tier +3.
static func enemy_level_for_tier(tier: int) -> int:
	return 1 + maxi(0, tier - 1) * 3

## True while the local player is on global cooldown (blocks plays).
func on_cooldown() -> bool:
	return rt != null and not rt.gcd_ready(RealtimeCombat.PLAYER)

## Called after any successful local card play.
func note_player_play(player_idx: int) -> void:
	if rt != null and player_idx == RealtimeCombat.PLAYER:
		rt.start_gcd(RealtimeCombat.PLAYER)

## Tap on an enemy minion (when not targeting a spell): focus it for Ally and hero
## swings; tapping it again, or tapping the enemy hero (null), goes back to the hero.
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
	if rt == null or _battle._state.is_game_over() or _battle._pause_ui.is_paused():
		return
	var snap: Array[Dictionary] = _battle._fx.snapshot()
	var events: Array[Dictionary] = rt.advance(delta * _speed_factor())
	if _gcd_bar != null:
		_gcd_bar.value = rt.gcd_fraction(RealtimeCombat.PLAYER)
	if _swing_bar != null:
		_swing_bar.value = rt.hero_swing_fraction(RealtimeCombat.PLAYER)
	# Mana ticks every frame in points; the labels are cheap to update, the full
	# board refresh only runs on events (a whole cost unit, swings, casts).
	_battle._view.refresh_hero(_battle._player_hero_view, _battle._state.players[RealtimeCombat.PLAYER].hero, false)
	_battle._update_status()
	if events.is_empty():
		return
	var swung: bool = false
	for ev: Dictionary in events:
		match str(ev.get("type", "")):
			"swing":
				swung = true
			"enemy_cast_start":
				var c: CardInstance = ev["card"] as CardInstance
				_battle._fx.show_intent_banner("Casting %s…" % c.name)
			"enemy_cast":
				_battle._fx.hide_intent_banner()
				_after_enemy_play(ev["card"] as CardInstance)
	if swung:
		AudioManager.play_sfx("attack")
		_battle._fx.trigger_fx(snap)
		# Death ghosts are built synchronously from the old panels, so the
		# board can rebuild straight away without awaiting the tween.
		_battle._animate_deaths_from_snapshot(snap)
	_update_focus_label()
	_battle._refresh_all()
	_battle._check_game_over()

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
