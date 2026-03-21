extends Control

const BASE_RADIUS: float = 90.0
const KNOB_RADIUS: float = 38.0
const DEADZONE: float = 0.25

var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.has_feature("android")

func _get_base_center() -> Vector2:
	return get_viewport_rect().size - Vector2(150.0, 150.0)

func _draw() -> void:
	var c: Vector2 = _get_base_center()
	draw_circle(c, BASE_RADIUS, Color(1.0, 1.0, 1.0, 0.18))
	draw_arc(c, BASE_RADIUS, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.50), 2.5)
	draw_circle(c + _knob_offset, KNOB_RADIUS, Color(1.0, 1.0, 1.0, 0.55))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _touch_index == -1:
			if touch.position.distance_to(_get_base_center()) <= BASE_RADIUS * 1.5:
				_touch_index = touch.index
				_update_knob(touch.position)
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_knob_offset = Vector2.ZERO
			_release_all()
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _touch_index:
			_update_knob(drag.position)

func _update_knob(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - _get_base_center()
	if offset.length() > BASE_RADIUS:
		offset = offset.normalized() * BASE_RADIUS
	_knob_offset = offset
	var dir: Vector2 = _knob_offset / BASE_RADIUS
	_set_action("move_up",    dir.y < -DEADZONE)
	_set_action("move_down",  dir.y >  DEADZONE)
	_set_action("move_left",  dir.x < -DEADZONE)
	_set_action("move_right", dir.x >  DEADZONE)
	queue_redraw()

func _set_action(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _release_all() -> void:
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_right")
