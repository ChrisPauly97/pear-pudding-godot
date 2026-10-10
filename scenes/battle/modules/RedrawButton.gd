## Redraw (GID-185 / TID-776), owned by `BattleRealtime` (`redraw`): the one-shot
## mulligan button in the action strip, shown only while `Redraw.can_redraw`
## holds (Redraw learned, unused, inside the opening window). R on a keyboard
## (forwarded from `BattleRealtime._unhandled_key_input`). Rules live in Redraw.gd.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const Redraw = preload("res://game_logic/battle/Redraw.gd")

var _battle: _BattleScene
var _realtime: _BattleRealtime
var _btn: Button = null

func _init(battle: _BattleScene, realtime: _BattleRealtime) -> void:
	_battle = battle
	_realtime = realtime

func build(parent: Control) -> void:
	var vh: float = _battle._vh
	_btn = _UiUtil.make_button("↻ Redraw", Vector2(vh * 0.14, vh * 0.055), int(_battle._font(0.02)), press, parent)
	_btn.tooltip_text = "Swap every non-technique card in your hand for fresh draws. Once, at the start (R)."
	_btn.visible = _can()

## Per-frame: hide once the window closes or the redraw is spent.
func update() -> void:
	if _btn != null and _btn.visible != _can():
		_btn.visible = _can()

## True while the button may act.
func can_press() -> bool:
	return _can()

func press() -> void:
	if not _can():
		return
	var n: int = Redraw.redraw(_realtime.rt)
	_realtime.toast("↻ Redrew %d card%s." % [n, "" if n == 1 else "s"])
	AudioManager.play_sfx("card_draw")
	_battle._refresh_all()
	update()

func _can() -> bool:
	var rt: RealtimeCombat = _realtime.rt
	return rt != null and Redraw.can_redraw(rt)
