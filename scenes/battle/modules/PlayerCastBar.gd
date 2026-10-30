## The player's cast bar in real-time fights ("Casting X (N mana)"), centred just
## above the hand (moved out of `RealtimeVisuals` for GID-189). Lives under the
## visuals' mouse-transparent root.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _battle: _BattleScene
var _panel: PanelContainer
var _lbl: Label
var _bar: ProgressBar

func _init(battle: _BattleScene, root: Control, tint: Color, bar: ProgressBar) -> void:
	_battle = battle
	var vh: float = battle._vh
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(vh * 0.5, 0.0)
	_panel.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.05, 0.05, 0.09, 0.9), 6, tint, 2))
	var vbox := _UiUtil.make_vbox(int(vh * 0.004), _panel)
	_lbl = _UiUtil.make_label("", int(battle._font(0.022)), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	_bar = bar
	vbox.add_child(_bar)
	_panel.visible = false
	root.add_child(_panel)

## `cast` = BattleRealtime._cast_info() ({} when not casting).
func update(cast: Dictionary) -> void:
	if cast.is_empty():
		_panel.visible = false
		return
	_panel.visible = true
	_lbl.text = "Casting %s  (%d mana)" % [str(cast["name"]), int(cast["cost"])]
	_bar.value = float(cast["fraction"])
	var hand_r: Rect2 = _battle._player_hand_view.get_global_rect()
	var sz: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = sz
	_panel.global_position = Vector2(hand_r.get_center().x - sz.x * 0.5, hand_r.position.y - sz.y - _battle._vh * 0.01)
