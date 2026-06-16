extends Node

signal long_pressed

const THRESHOLD_SEC: float = 0.5
const SLOP_PX: float = 12.0

var _holding: bool = false
var _elapsed: float = 0.0
var _touch_index: int = -1
var _start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if _holding:
		_elapsed += delta
		if _elapsed >= THRESHOLD_SEC:
			_holding = false
			set_process(false)
			long_pressed.emit()
	else:
		set_process(false)

func _input(event: InputEvent) -> void:
	# Only activate if the press starts within the parent Control's rect.
	var parent: Control = get_parent() as Control
	if parent == null:
		return

	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if _touch_index == -1 and parent.get_global_rect().has_point(e.position):
				# Don't fire if touch started on a child Button (avoids double-action)
				var hit := parent.get_viewport().gui_get_focus_owner()
				if hit != null and hit is Button and parent.is_ancestor_of(hit):
					return
				_touch_index = e.index
				_start_pos = e.position
				_holding = true
				_elapsed = 0.0
				set_process(true)
		else:
			if e.index == _touch_index:
				_cancel()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _touch_index and e.position.distance_to(_start_pos) > SLOP_PX:
			_cancel()
	elif event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if parent.get_global_rect().has_point(e.position):
					_start_pos = e.position
					_holding = true
					_elapsed = 0.0
					set_process(true)
			else:
				_cancel()
	elif event is InputEventMouseMotion:
		if _holding:
			var e := event as InputEventMouseMotion
			if e.position.distance_to(_start_pos) > SLOP_PX:
				_cancel()

func _cancel() -> void:
	_holding = false
	_touch_index = -1
	set_process(false)
