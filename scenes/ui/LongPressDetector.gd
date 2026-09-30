extends Node

signal long_pressed

const _LongPressTracker = preload("res://scenes/ui/LongPressTracker.gd")

const THRESHOLD_SEC: float = _LongPressTracker.THRESHOLD_SEC
const SLOP_PX: float = _LongPressTracker.SLOP_PX

var _press := _LongPressTracker.new()
var _touch_index: int = -1

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not _press.is_holding():
		set_process(false)
	elif _press.tick(delta):
		set_process(false)
		long_pressed.emit()

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
				_begin(e.position)
		else:
			if e.index == _touch_index:
				_cancel()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _touch_index and _press.strayed(e.position):
			_cancel()
	elif event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if parent.get_global_rect().has_point(e.position):
					_begin(e.position)
			else:
				_cancel()
	elif event is InputEventMouseMotion:
		if _press.is_holding() and _press.strayed((event as InputEventMouseMotion).position):
			_cancel()

func _begin(pos: Vector2) -> void:
	_press.press(pos)
	set_process(true)

func _cancel() -> void:
	_press.cancel()
	_touch_index = -1
	set_process(false)
