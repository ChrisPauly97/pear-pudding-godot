## Locked Ally slots (BID-085): before `feat_minions` is learned a real-time fight
## has no hand, but your Ally slots stay on the board under "Locked · Allies at
## Lv N" plates, so the enemy's summons read as something you'll get too.
##
## Owned by `RealtimeVisuals`; the plates live under its mouse-transparent root
## (a slot is a container, so a child would be stretched) and follow the empty
## slots every frame. They swallow taps, so a locked slot does nothing.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _battle: _BattleScene
var _root: Control
var _level: int
var _covers: Array[PanelContainer] = []

func _init(battle: _BattleScene, root: Control, level: int) -> void:
	_battle = battle
	_root = root
	_level = level

## Places one plate over each visible empty Ally slot.
func update() -> void:
	var slots: Array[Control] = []
	for c: Node in _battle._player_board_view.get_children():
		var ctl := c as Control
		if ctl != null and ctl.visible and bool(ctl.get_meta("is_empty_slot", false)):
			slots.append(ctl)
	while _covers.size() < slots.size():
		_covers.append(_make_cover())
	for i: int in _covers.size():
		var cover: PanelContainer = _covers[i]
		cover.visible = i < slots.size()
		if cover.visible:
			var r: Rect2 = slots[i].get_global_rect()
			cover.global_position = r.position
			cover.size = r.size

func _make_cover() -> PanelContainer:
	var vh: float = _battle._vh
	var cover := PanelContainer.new()
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.05, 0.05, 0.08, 0.75), 4,
			Color(0.55, 0.5, 0.35, 0.8), 2))
	var vbox := _UiUtil.make_vbox(int(vh * 0.006), cover)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold := Color(0.95, 0.85, 0.55)
	for line: Array in [["Locked", 0.026, gold], ["Allies at", 0.019, Color(0.75, 0.75, 0.8)],
			["Lv %d" % _level, 0.024, gold]]:
		var lbl := _UiUtil.make_label(str(line[0]), _battle._font(float(line[1])), line[2] as Color,
				HORIZONTAL_ALIGNMENT_CENTER, vbox)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cover)
	return cover
