## Technique cards in real-time fights (GID-175 / TID-709): Kick / Daze act on
## enemy casts and skip the GCD, damaging techniques build momentum, and a held
## Kick pulses while an enemy casts. Owned by `BattleRealtime` (`techniques`);
## parents nothing, so the module add_child / self rules don't arise.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")

const _REACTIVE: Array[String] = ["kick", "daze"]

var _battle: _BattleScene
var _realtime: _BattleRealtime

func _init(battle: _BattleScene, realtime: _BattleRealtime) -> void:
	_battle = battle
	_realtime = realtime

## True for a technique that is off the global cooldown in real time (Kick, Daze).
func is_off_gcd(card: CardInstance) -> bool:
	return _realtime.rt != null and TechniqueDefs.off_gcd(card.template_id)

## Why technique `card` can't be played right now, or "".
func blocker(card: CardInstance) -> String:
	if _realtime.rt == null:
		return ""
	if card.template_id == "tech_kick" and casting_enemy() < 0:
		return "Nothing to interrupt"
	if is_off_gcd(card) and _realtime.is_casting():
		return "Busy casting"
	return ""

## Kick / Daze act on enemy casts instead of their turn-based minion stun /
## freeze. Returns true when it handled `card` (the caller skips the resolver).
func resolve_reactive(card: CardInstance) -> bool:
	var rt: RealtimeCombat = _realtime.rt
	if rt == null:
		return false
	match card.template_id:
		"tech_kick":
			var side: int = casting_enemy()
			var cut: CardInstance = rt.interrupt_enemy_cast(side) if side >= 0 else null
			if cut != null:
				_realtime.toast("Interrupted %s!" % cut.name)
				_realtime.note_skill_used("interrupt")
			return true
		"tech_daze":
			var side: int = casting_enemy()
			if side < 0:
				side = rt.target_enemy()
			rt.state.players[side].hero.apply_status("stun", 1)
			rt.interrupt_enemy_cast(side)
			_realtime.toast("Dazed!")
			return true
	return false

## After a technique resolved: damaging ones are builders (siphon, combo, proc
## roll — GID-139), plus stats and the "use what you learned" quest progress.
func after_resolve(card: CardInstance, dealt: int) -> void:
	var rt: RealtimeCombat = _realtime.rt
	if card == null or rt == null or not TechniqueDefs.is_technique(card.template_id):
		return
	if _battle._state.players[RealtimeCombat.PLAYER].hand.has(card):
		return  # never left the hand (fizzled / refused)
	if dealt > 0 and rt.on_player_hit(dealt, true):
		_realtime.momentum.on_proc()
	if card.template_id != "tech_kick":
		_realtime.note_skill_used(card.spell_effect)
	SceneManager.save_manager.quests.progress_event("use_skill", TechniqueDefs.ability_for(card.template_id))

## The enemy side to interrupt: your target if it is casting, else any caster (-1 = none).
func casting_enemy() -> int:
	var rt: RealtimeCombat = _realtime.rt
	var first: int = rt.target_enemy()
	if first < rt.casting.size() and rt.casting[first] != null:
		return first
	for side: int in rt.enemy_sides():
		if rt.casting[side] != null:
			return side
	return -1

## The hand card panel holding technique `ability_id` ("mend"), or null.
func control_for(ability_id: String) -> Control:
	var hand: Array[CardInstance] = _battle._state.players[RealtimeCombat.PLAYER].hand
	var view: Node = _battle._player_hand_view
	if view.get_child_count() != hand.size():
		return null
	for i: int in hand.size():
		if hand[i].template_id == "tech_" + ability_id:
			return view.get_child(i) as Control
	return null

## A held Kick / Daze pulses while an enemy casts: react without looking up.
func pulse_reactive() -> void:
	var casting: bool = casting_enemy() >= 0
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for id: String in _REACTIVE:
		var ctl: Control = control_for(id)
		if ctl != null:
			ctl.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.3), pulse) if casting else Color.WHITE
