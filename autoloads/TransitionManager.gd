extends CanvasLayer
## Screen transitions (GID-133 / TID-516 replaced the plain black fade): a
## full-screen rect running `screen_wipe.gdshader`. `transition(change_fn,
## style)` covers the screen, calls `change_fn`, then uncovers it. Callers rely
## on the awaited covering finishing before `change_fn` runs (SceneManager's
## `_restore_world(after)`), so keep `fade_out`/`fade_in` awaitable.

const _WIPE_SHADER = preload("res://assets/shaders/screen_wipe.gdshader")

## Seconds to cover (and to uncover). Was 0.2 for the plain fade.
const FADE_DURATION: float = 0.3
const STYLE_WIPE := 0
const STYLE_BATTLE := 1

var _rect: ColorRect
var _mat: ShaderMaterial
var _transitioning: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = _WIPE_SHADER
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	_set_progress(0.0)

## Covers the screen, calls change_fn, then uncovers. Fire-and-forget from callers.
func transition(change_fn: Callable, style: int = STYLE_WIPE) -> void:
	if _transitioning:
		change_fn.call()
		return
	_transitioning = true
	_mat.set_shader_parameter("style", style)
	await fade_out()
	change_fn.call()
	await get_tree().process_frame
	await fade_in()
	_transitioning = false

func fade_out() -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.visible = true
	_update_aspect()
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(_set_progress, 0.0, 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished

func fade_in() -> void:
	_update_aspect()
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(_set_progress, 1.0, 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false

## 0 clear .. 1 covered (tests, debugging).
func progress() -> float:
	return float(_mat.get_shader_parameter("progress"))

func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)

func _update_aspect() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	if size.y > 0.0:
		_mat.set_shader_parameter("aspect", size.x / size.y)
