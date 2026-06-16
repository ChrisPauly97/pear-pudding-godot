extends CanvasLayer

const FADE_DURATION: float = 0.2

var _rect: ColorRect
var _transitioning: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

## Fades to black, calls change_fn, then fades back in. Fire-and-forget from callers.
func transition(change_fn: Callable) -> void:
	if _transitioning:
		change_fn.call()
		return
	_transitioning = true
	await fade_out()
	change_fn.call()
	await get_tree().process_frame
	await fade_in()
	_transitioning = false

func fade_out() -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_rect, "color:a", 1.0, FADE_DURATION)
	await tw.finished

func fade_in() -> void:
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_rect, "color:a", 0.0, FADE_DURATION)
	await tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
