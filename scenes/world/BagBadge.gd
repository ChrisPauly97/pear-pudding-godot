## New-card badge on the HUD's Menu/Bag button, and the post-fight fly-in
## (GID-180 / TID-747): cards won while the world was away (a battle) fly from
## the middle of the screen into the button when the world comes back, then the
## badge counts them until the deck table is opened.
extends RefCounted

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _CardJuice = preload("res://scenes/ui/inventory/CardJuice.gd")

const MAX_FLYERS: int = 5

var _btn: Button
var _hud: CanvasLayer
var _badge: PanelContainer
var _label: Label
var _vh: float = 0.0
var _shown: int = 0  # count the badge last displayed (flies the difference)


func setup(btn: Button, hud: CanvasLayer, vh: float) -> void:
	_btn = btn
	_hud = hud
	_vh = vh
	_badge = PanelContainer.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.85, 0.25, 0.2), int(vh * 0.02),
			Color(1.0, 0.85, 0.4), 2))
	_label = _UiUtil.make_label("", int(vh * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, _badge)
	btn.add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge.position += Vector2(-vh * 0.01, -vh * 0.015)
	_shown = SceneManager.save_manager.new_card_uids.size()
	_paint(_shown)
	GameBus.new_cards_changed.connect(_on_changed)
	# Back from a battle: let the transition wipe finish, then fly the winnings in.
	hud.tree_entered.connect(func() -> void:
		if hud.is_inside_tree():
			hud.get_tree().create_timer(0.8).timeout.connect(_catch_up))


func _on_changed(count: int) -> void:
	if _btn == null or not is_instance_valid(_btn) or not _btn.is_inside_tree():
		return  # the world is away; _catch_up runs when it returns
	if count > _shown:
		_fly(count - _shown, count)
	else:
		_shown = count
		_paint(count)


func _catch_up() -> void:
	if _btn == null or not is_instance_valid(_btn) or not _btn.is_inside_tree():
		return
	var count: int = SceneManager.save_manager.new_card_uids.size()
	if count > _shown:
		_fly(count - _shown, count)
	else:
		_shown = count
		_paint(count)


func _paint(count: int) -> void:
	_badge.visible = count > 0
	_label.text = str(count) if count < 100 else "99+"
	_btn.tooltip_text = "%d new card%s in your bag" % [count, "" if count == 1 else "s"] if count > 0 else ""


## Little card backs arc from the screen centre into the bag button.
func _fly(n: int, final_count: int) -> void:
	_shown = final_count
	var vp: Vector2 = _btn.get_viewport().get_visible_rect().size
	var target: Vector2 = _btn.get_global_rect().get_center()
	var flyers: int = mini(n, MAX_FLYERS)
	for i in range(flyers):
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size = Vector2(_vh * 0.06, _vh * 0.085)
		card.pivot_offset = card.size * 0.5
		card.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.3, 0.2, 0.45), int(_vh * 0.008),
				Color(1.0, 0.85, 0.4), 2))
		_hud.add_child(card)
		card.global_position = vp * 0.5 - card.size * 0.5 + Vector2((i - flyers * 0.5) * _vh * 0.03, 0.0)
		card.scale = Vector2(1.4, 1.4)
		card.modulate.a = 0.0
		var last: bool = i == flyers - 1
		var tw := card.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(card, "modulate:a", 1.0, 0.12)
		tw.tween_property(card, "global_position", target - card.size * 0.5, 0.55) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(card, "scale", Vector2(0.35, 0.35), 0.55)
		tw.parallel().tween_property(card, "rotation", 0.6, 0.55)
		tw.tween_callback(func() -> void:
			card.queue_free()
			_CardJuice.sound("place")
			if last:
				_paint(final_count)
				_CardJuice.pop(_badge, 0.4))
