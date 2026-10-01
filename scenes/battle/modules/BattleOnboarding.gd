## Real-time onboarding in the fight (GID-135 / TID-552, TID-553; ladder-based
## since GID-141 / TID-588): hides the hand (Ally slots shown locked) until minions are learned, slows the
## very first fight's clock, and
## shows one-shot tips the first time something happens — each a
## `TutorialRegistry` popup (pauses the clock, remembered via "seen_tutorial_*"
## story flags) plus a gold spotlight on the thing to press once it closes.
##
## Owned by `BattleRealtime` (`onboarding`); parents its widgets under the
## battle scene, never a module node.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const CombatOnboarding = preload("res://game_logic/battle/CombatOnboarding.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _TutorialPopup = preload("res://scenes/ui/TutorialPopup.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
## Seconds the spotlight stays after its tip closes.
const SPOT_SECONDS: float = 3.5
## HP fraction that triggers the Mend tip.
const LOW_HP: float = 0.4

## -1 = full fight; otherwise how many combat unlocks are learned (CombatOnboarding).
var stage: int = -1
var _hand: bool = true
var _slow: bool = false
var _battle: _BattleScene
var _realtime: _BattleRealtime
var _fired: Dictionary = {}
var _spot: Panel = null
var _spot_target: Control = null
var _spot_left: float = 0.0

func _init(battle: _BattleScene, realtime: _BattleRealtime) -> void:
	_battle = battle
	_realtime = realtime

## Reads what this player has learned and counts the fight. `count` is false
## for the training dummy (TID-557) — practice doesn't use up the slow first fight.
func begin(count: bool = true) -> void:
	var sm := SceneManager.save_manager
	stage = CombatOnboarding.stage_for(sm.learned_abilities)
	_hand = CombatOnboarding.shows_hand(sm.learned_abilities)
	_slow = CombatOnboarding.slow_clock(sm.realtime_fights, sm.learned_abilities)
	if count:
		sm.realtime_fights += 1
		sm.mark_dirty()

func shows_hand() -> bool:
	return _hand

func slow_clock() -> bool:
	return _slow

## After the UI is built: hide what isn't taught yet and show the opening tip.
func apply() -> void:
	if not shows_hand():
		# No cards yet: hide the hand, but show your Ally slots locked so the
		# enemy's summons have something to look forward to.
		_battle._player_hand_view.visible = false
		_realtime.lock_ally_slots(UnlockLadder.level_req(UnlockLadder.FEAT_MINIONS))
	tip("rt_intro", _realtime.skills.button_for("strike"))
	# First fight with a newly learned skill: its tip (each shows once ever).
	for id: String in ["mend", "kick"]:
		if _realtime.skills.button_for(id) != null:
			tip("rt_skill_" + id, _realtime.skills.button_for(id))
	if shows_hand():
		tip("rt_cards", _battle._player_hand_view)

## Per-frame: fire tips whose moment has come; move / expire the spotlight.
func update(dt: float) -> void:
	var rt: RealtimeCombat = _realtime.rt
	var me: PlayerState = rt.state.players[RealtimeCombat.PLAYER]
	var mend: Control = _realtime.skills.button_for("mend")
	if mend != null and me.hero.health <= int(me.hero.max_health * LOW_HP):
		tip("rt_low_hp", mend)
	var kick: Control = _realtime.skills.button_for("kick")
	for side: int in rt.enemy_sides():
		if kick != null and rt.casting[side] != null:
			tip("rt_enemy_cast", kick)
	if me.hero.mana < _realtime.skills.cheapest_cost():
		tip("rt_out_of_mana", _realtime.token(RealtimeCombat.PLAYER))
	if shows_hand() and not me.board.get_cards().is_empty():
		var ally: CardInstance = me.board.get_cards()[0]
		tip("rt_ally", _realtime.unit_panel(ally, RealtimeCombat.PLAYER))
	_tick_spot(dt)

## A second enemy joined.
func on_add(side: int) -> void:
	tip("rt_add", _realtime.token(side))

## Shows tip `id` once ever (skipped when `target` is required but missing).
func tip(id: String, target: Control) -> void:
	if _fired.has(id):
		return
	_fired[id] = true
	if SceneManager.save_manager.get_story_flag("seen_tutorial_" + id):
		return
	GameBus.tutorial_popup_requested.emit(id)
	if target != null:
		_spotlight(target)

func _spotlight(target: Control) -> void:
	if _spot == null:
		_spot = Panel.new()
		_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spot.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(1.0, 0.85, 0.3, 0.12), 10,
				Color(1.0, 0.85, 0.3), 4))
		_spot.z_index = 60
		_battle.add_child(_spot)
	_spot_target = target
	_spot_left = SPOT_SECONDS

func _tick_spot(dt: float) -> void:
	if _spot == null:
		return
	var valid: bool = is_instance_valid(_spot_target) and _spot_target.is_visible_in_tree()
	# The countdown only runs once the tip popup is closed.
	var modal: bool = not _battle.get_tree().get_nodes_in_group(_TutorialPopup.MODAL_GROUP).is_empty()
	if not modal:
		_spot_left -= dt
	_spot.visible = valid and _spot_left > 0.0
	if not _spot.visible:
		return
	var r: Rect2 = _spot_target.get_global_rect().grow(_battle._vh * 0.012)
	_spot.global_position = r.position
	_spot.size = r.size
	# Gentle pulse so the eye finds it.
	_spot.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01)
