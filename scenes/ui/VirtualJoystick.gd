extends Control

# All sizing is computed from viewport height in _ready() so controls scale
# correctly across phones, tablets, and varying DPI rather than using fixed px.
const DEADZONE: float = 0.25
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _base_r: float       # joystick outer ring radius
var _knob_r: float       # joystick knob radius
var _jump_r: float       # jump button radius
var _interact_r: float   # interact button radius
var _edge_margin: float  # distance from screen edge to button centre

var _joy_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
var _jump_index: int = -1
var _jump_pressed: bool = false
var _interact_index: int = -1
var _interact_pressed: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.has_feature("android")

	var vh: float = get_viewport_rect().size.y
	_base_r      = vh * 0.085   # ≈130 px at 1520 px vh (typical phone landscape)
	_knob_r      = vh * 0.035
	_jump_r      = vh * 0.060
	_interact_r  = vh * 0.055
	_edge_margin = vh * 0.118   # ≈180 px at 1520 px vh
	# Keep thumb controls out of display cutouts / rounded corners
	# (GID-120 / TID-455). Both bottom corners host controls, so take the
	# largest relevant inset.
	var ins: Dictionary = _UiUtil.safe_insets(get_viewport())
	_edge_margin += maxf(float(ins.get("bottom", 0.0)),
		maxf(float(ins.get("left", 0.0)), float(ins.get("right", 0.0))))

func _get_joy_center() -> Vector2:
	return get_viewport_rect().size - Vector2(_edge_margin, _edge_margin)

func _get_jump_center() -> Vector2:
	var s: Vector2 = get_viewport_rect().size
	return Vector2(_edge_margin, s.y - _edge_margin)

func _get_interact_center() -> Vector2:
	var s: Vector2 = get_viewport_rect().size
	return Vector2(_edge_margin, s.y - _edge_margin * 2.4)

func _draw() -> void:
	# Joystick
	var jc: Vector2 = _get_joy_center()
	draw_circle(jc, _base_r, Color(1.0, 1.0, 1.0, 0.18))
	draw_arc(jc, _base_r, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.50), 2.5)
	draw_circle(jc + _knob_offset, _knob_r, Color(1.0, 1.0, 1.0, 0.55))
	# Jump button
	var jump_col: Color = Color(1.0, 1.0, 1.0, 0.55) if _jump_pressed else Color(1.0, 1.0, 1.0, 0.18)
	draw_circle(_get_jump_center(), _jump_r, jump_col)
	draw_arc(_get_jump_center(), _jump_r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.50), 2.5)
	draw_string(ThemeDB.fallback_font, _get_jump_center() + Vector2(-14.0, 8.0), "jump",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 1.0, 1.0, 0.80))
	# Interact button
	var interact_col: Color = Color(1.0, 1.0, 1.0, 0.55) if _interact_pressed else Color(1.0, 1.0, 1.0, 0.18)
	draw_circle(_get_interact_center(), _interact_r, interact_col)
	draw_arc(_get_interact_center(), _interact_r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.50), 2.5)
	draw_string(ThemeDB.fallback_font, _get_interact_center() + Vector2(-24.0, 8.0), "use",
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
		if _joy_index == -1 and pos.distance_to(_get_joy_center()) <= _base_r * 1.5:
			_joy_index = index
			_update_knob(pos)
		elif _jump_index == -1 and pos.distance_to(_get_jump_center()) <= _jump_r * 1.5:
			_jump_index = index
			_jump_pressed = true
			Input.action_press("jump")
			queue_redraw()
		elif _interact_index == -1 and pos.distance_to(_get_interact_center()) <= _interact_r * 1.5:
			_interact_index = index
			_interact_pressed = true
			Input.action_press("interact")
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
		elif index == _interact_index:
			_interact_index = -1
			_interact_pressed = false
			Input.action_release("interact")
			queue_redraw()

func _update_knob(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - _get_joy_center()
	if offset.length() > _base_r:
		offset = offset.normalized() * _base_r
	_knob_offset = offset
	var dir: Vector2 = _knob_offset / _base_r
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

# Returns true if pos falls within any of the virtual-joystick interactive circles.
# Used by WorldScene to prevent tap-to-move from firing when the player touches
# the joystick pad, jump button, or interact button.
func is_touch_in_control_area(pos: Vector2) -> bool:
	if not visible:
		return false
	if pos.distance_to(_get_joy_center()) <= _base_r * 1.5:
		return true
	if pos.distance_to(_get_jump_center()) <= _jump_r * 1.5:
		return true
	if pos.distance_to(_get_interact_center()) <= _interact_r * 1.5:
		return true
	return false
