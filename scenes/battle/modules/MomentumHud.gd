## Real-time momentum widgets (GID-139), owned by `BattleRealtime` (`momentum`):
## the combo pips and the free-cast glow on the hand (melee auto-attack is always
## on — no toggle). Reads everything from `RealtimeCombat` (combo,
## next_card_free); parents its widgets under the action strip, never a module node.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

const GOLD := Color(1.0, 0.82, 0.3)

var _battle: _BattleScene
var _realtime: _BattleRealtime
var _pips: Label = null
var _was_free: bool = false

func _init(battle: _BattleScene, realtime: _BattleRealtime) -> void:
	_battle = battle
	_realtime = realtime

func build(parent: Control) -> void:
	var vh: float = _battle._vh
	var col := _UiUtil.make_vbox(int(vh * 0.004), parent)
	_pips = _UiUtil.make_label("", int(_battle._font(0.02)), GOLD, HORIZONTAL_ALIGNMENT_CENTER, col)
	_pips.tooltip_text = "Combo: skill hits build charges; your next card spends them for mana. Full = instant cast."
	_pips.mouse_filter = Control.MOUSE_FILTER_PASS

## Per-frame: pips, free-cast pulse on the hand.
func update() -> void:
	var rt: RealtimeCombat = _realtime.rt
	if rt == null or _pips == null:
		return
	var cap: int = rt.tune.get_i("combo_max")
	var full: bool = rt.combo_full()
	_pips.text = "◆".repeat(rt.combo) + "◇".repeat(maxi(0, cap - rt.combo))
	var free: bool = rt.state.players[RealtimeCombat.PLAYER].next_card_free
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
	_pips.modulate = Color.WHITE.lerp(Color(1.4, 1.2, 0.6), pulse) if full else Color.WHITE
	var glow: Color = Color.WHITE
	if free or full:
		glow = Color.WHITE.lerp(GOLD if free else Color(0.7, 0.9, 1.0), pulse)
	if free or full or _was_free:
		for c: Node in _battle._player_hand_view.get_children():
			var ctl := c as Control
			if ctl != null:
				ctl.self_modulate = glow
	_was_free = free or full

## A free-cast proc just fired (auto-attack or skill hit).
func on_proc() -> void:
	_realtime.toast("✦ Essence surge — your next card is free and instant!")
	_realtime.hit_feel(2)
	AudioManager.play_sfx("spell_resolve")
	_battle._refresh_all()
