extends Control

const BASE_RADIUS: float = 90.0
const KNOB_RADIUS: float = 38.0
const JUMP_RADIUS: float = 55.0
const DEADZONE: float = 0.25

var _joy_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
var _jump_index: int = -1
var _jump_pressed: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.has_feature("android")

func _get_joy_center() -> Vector2:
	return get_viewport_rect().size - Vector2(150.0, 150.0)

func _get_jump_center() -> Vector2:
	var s: Vector2 = get_viewport_rect().size
	return Vector2(150.0, s.y - 150.0)

func _draw() -> void:
	# Joystick
	var jc: Vector2 = _get_joy_center()
	draw_circle(jc, BASE_RADIUS, Color(1.0, 1.0, 1.0, 0.18))
	draw_arc(jc, BASE_RADIUS, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.50), 2.5)
	draw_circle(jc + _knob_offset, KNOB_RADIUS, Color(1.0, 1.0, 1.0, 0.55))
	# Jump button
	var jump_col: Color = Color(1.0, 1.0, 1.0, 0.55) if _jump_pressed else Color(1.0, 1.0, 1.0, 0.18)
	draw_circle(_get_jump_center(), JUMP_RADIUS, jump_col)
	draw_arc(_get_jump_center(), JUMP_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.50), 2.5)
	draw_string(ThemeDB.fallback_font, _get_jump_center() + Vector2(-14.0, 8.0), "jump",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 1.0, 1.0, 0.80))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_handle_touch(touch.index, touch.position, touch.pressed)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _joy_index:
			_update_knob(drag.position)

func _handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _joy_index == -1 and pos.distance_to(_get_joy_center()) <= BASE_RADIUS * 1.5:
			_joy_index = index
			_update_knob(pos)
		elif _jump_index == -1 and pos.distance_to(_get_jump_center()) <= JUMP_RADIUS * 1.5:
			_jump_index = index
			_jump_pressed = true
			Input.action_press("jump")
			queue_redraw()
	else:
		if index == _joy_index:
			_joy_index = -1
			_knob_offset = Vector2.ZERO
			_release_move()
			queue_redraw()
		elif index == _jump_index:
			_jump_index = -1
			_jump_pressed = false
			Input.action_release("jump")
			queue_redraw()

func _update_knob(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - _get_joy_center()
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

func _release_move() -> void:
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_right")
