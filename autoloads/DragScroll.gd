## Tap-and-drag scrolling for every ScrollContainer in the game.
##
## Buttons and other MOUSE_FILTER_STOP children swallow the drag before it can
## reach the ScrollContainer, so on touch only the thin scrollbar worked. This
## autoload watches raw input instead: once a press moves past a small
## threshold along an axis the container under the finger can scroll, it takes
## the gesture over, scrolls the content, flings on release, and cancels the
## press on whatever button the finger started on so it doesn't fire.
##
## Horizontal-dominant drags in a vertical-only list are left alone, so
## sideways card drag-and-drop (InventoryScene) keeps working. Sliders and text
## fields keep their own drags.
extends Node

const THRESHOLD_FRAC: float = 0.012   # of viewport height, min 8 px
const FLING_DECAY: float = 6.0        # per second, exponential
const FLING_MIN_SPEED: float = 30.0   # px/s below which the fling stops
## Off-screen release sent to the pressed control so it cancels instead of firing.
const CANCEL_POS := Vector2(-100000.0, -100000.0)
const GROUP := &"drag_scroll"

var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _last_ms: int = 0
var _velocity: Vector2 = Vector2.ZERO
var _scroll: ScrollContainer = null
var _vertical: bool = true
var _fling: Vector2 = Vector2.ZERO
var _fling_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	var sc := n as ScrollContainer
	if sc == null:
		return
	sc.add_to_group(GROUP)
	# This handler replaces the engine's own touch drag, which would otherwise
	# also move background-started drags.
	sc.scroll_deadzone = 100000


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.position == CANCEL_POS:
			return
		if mb.pressed:
			_begin(mb.position)
		else:
			_end()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _pressing:
		_move(mm.position)


func _begin(pos: Vector2) -> void:
	_pressing = true
	_dragging = false
	_scroll = null
	_press_pos = pos
	_last_pos = pos
	_last_ms = Time.get_ticks_msec()
	_velocity = Vector2.ZERO
	_stop_fling()


func _move(pos: Vector2) -> void:
	if not _dragging:
		var d: Vector2 = pos - _press_pos
		var vp: Viewport = get_viewport()
		var vh: float = vp.get_visible_rect().size.y if vp != null else 0.0
		if d.length() < maxf(8.0, vh * THRESHOLD_FRAC):
			return
		if vp != null and vp.gui_is_dragging():
			_pressing = false
			return
		var vertical: bool = absf(d.y) >= absf(d.x)
		var sc: ScrollContainer = _find_scroll(vertical)
		if sc == null:
			_pressing = false  # not a scroll gesture; leave it alone
			return
		_scroll = sc
		_vertical = vertical
		_dragging = true
		_cancel_press()
		_last_pos = _press_pos
	if not is_instance_valid(_scroll):
		_pressing = false
		_dragging = false
		return
	var delta: Vector2 = pos - _last_pos
	_apply(delta)
	var now: int = Time.get_ticks_msec()
	var dt: float = maxf(0.001, float(now - _last_ms) / 1000.0)
	_velocity = _velocity.lerp(delta / dt, 0.5)
	_last_pos = pos
	_last_ms = now
	_mark_handled()


func _end() -> void:
	var was_dragging: bool = _dragging
	_pressing = false
	_dragging = false
	if not was_dragging:
		return
	_mark_handled()
	# A finger held still before lifting shouldn't fling.
	if Time.get_ticks_msec() - _last_ms < 80 and is_instance_valid(_scroll):
		_fling = _velocity
		_fling_pos = Vector2.ZERO
		set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_scroll) or _fling.length() < FLING_MIN_SPEED:
		_stop_fling()
		return
	_apply(_fling * delta)
	_fling *= exp(-FLING_DECAY * delta)


func _stop_fling() -> void:
	_fling = Vector2.ZERO
	set_process(false)


## Content follows the finger: dragging down scrolls toward the top.
func _apply(delta: Vector2) -> void:
	if _vertical:
		var bar: VScrollBar = _scroll.get_v_scroll_bar()
		bar.value = bar.value - delta.y
	else:
		var hbar: HScrollBar = _scroll.get_h_scroll_bar()
		hbar.value = hbar.value - delta.x


## Releases the press on the control the finger started on, off its rect, so a
## button that began a scroll doesn't also fire.
func _mark_handled() -> void:
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _cancel_press() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = CANCEL_POS
	ev.global_position = CANCEL_POS
	vp.push_input(ev, true)


## The innermost ScrollContainer that can scroll along the drag's axis, found
## from the control under the finger. Text fields and ranges keep their drags.
func _find_scroll(vertical: bool) -> ScrollContainer:
	if not is_inside_tree():
		return null
	var n: Node = get_viewport().gui_get_hovered_control()
	if n == null:
		return _scroll_at(_press_pos, vertical)
	while n != null:
		if n is Range or n is LineEdit or n is TextEdit:
			return null
		var sc := n as ScrollContainer
		if sc != null and sc.is_visible_in_tree() and can_scroll(sc, vertical):
			return sc
		n = n.get_parent()
	return null


## Fallback when nothing reports hover (a touch with no prior motion): the
## innermost scrollable container whose rect holds the press.
func _scroll_at(pos: Vector2, vertical: bool) -> ScrollContainer:
	var best: ScrollContainer = null
	var best_depth: int = -1
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var sc := node as ScrollContainer
		if sc == null or not sc.is_visible_in_tree() or not can_scroll(sc, vertical):
			continue
		var local: Vector2 = sc.get_global_transform_with_canvas().affine_inverse() * pos
		if not Rect2(Vector2.ZERO, sc.size).has_point(local):
			continue
		var depth: int = sc.get_path().get_name_count()
		if depth > best_depth:
			best = sc
			best_depth = depth
	return best


static func can_scroll(sc: ScrollContainer, vertical: bool) -> bool:
	if vertical:
		var bar: VScrollBar = sc.get_v_scroll_bar()
		return sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and bar.max_value - bar.page > 0.5
	var hbar: HScrollBar = sc.get_h_scroll_bar()
	return sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and hbar.max_value - hbar.page > 0.5
