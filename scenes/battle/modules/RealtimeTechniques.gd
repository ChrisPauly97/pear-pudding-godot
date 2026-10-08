## Technique-card presentation in real-time fights (GID-175): finds a technique's
## hand panel (onboarding tips anchor to it) and pulses a held Kick / Daze while
## an enemy casts. The rules (off-GCD, Kick / Daze, builder hits) are in
## `game_logic/battle/PlayerCaster.gd` (GID-176 / TID-713). Owned by
## `BattleRealtime` (`techniques`); parents nothing.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

const _REACTIVE: Array[String] = ["kick", "daze"]

var _battle: _BattleScene
var _realtime: _BattleRealtime

func _init(battle: _BattleScene, realtime: _BattleRealtime) -> void:
	_battle = battle
	_realtime = realtime

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
	var casting: bool = _realtime.caster.casting_enemy() >= 0
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for id: String in _REACTIVE:
		var ctl: Control = control_for(id)
		if ctl != null:
			ctl.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.3), pulse) if casting else Color.WHITE
