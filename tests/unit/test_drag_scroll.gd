## DragScroll autoload: tap-and-drag scrolls whatever ScrollContainer is under
## the finger, but only along an axis that container can scroll, so sideways
## card drags in a vertical list stay drag-and-drop.
extends "res://tests/framework/test_case.gd"

const _DragScroll = preload("res://autoloads/DragScroll.gd")


## The unit runner is synchronous, so nothing enters the tree and there is no
## hover. The probe resolves "the container under the finger" to the fixture
## when the press lands inside it; everything else is the real code.
class _Probe extends "res://autoloads/DragScroll.gd":
	var target: ScrollContainer = null

	func _find_scroll(vertical: bool) -> ScrollContainer:
		if Rect2(target.position, target.size).has_point(_press_pos) and can_scroll(target, vertical):
			return target
		return null

var _ds: _Probe = null
var _sc: ScrollContainer = null


func before_each() -> void:
	_ds = _Probe.new()
	_sc = ScrollContainer.new()
	_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sc.position = Vector2.ZERO
	_sc.size = Vector2(200, 200)
	_ds._on_node_added(_sc)
	_ds.target = _sc
	var bar: VScrollBar = _sc.get_v_scroll_bar()
	bar.max_value = 1000.0
	bar.page = 200.0
	bar.value = 100.0


func after_each() -> void:
	_sc.free()
	_ds.free()


func test_new_scroll_containers_are_registered() -> void:
	assert_true(_sc.is_in_group(_DragScroll.GROUP))
	assert_gt(_sc.scroll_deadzone, 1000, "engine touch drag is handed over to DragScroll")


func test_vertical_drag_scrolls_content_with_the_finger() -> void:
	_ds._begin(Vector2(100, 150))
	_ds._move(Vector2(100, 90))
	assert_true(_ds._dragging)
	assert_almost_eq(_sc.get_v_scroll_bar().value, 160.0, 0.5, "dragging up 60 px scrolls down 60")
	_ds._end()
	assert_false(_ds._dragging)


func test_small_motion_is_still_a_tap() -> void:
	_ds._begin(Vector2(100, 150))
	_ds._move(Vector2(100, 147))
	assert_false(_ds._dragging)
	assert_almost_eq(_sc.get_v_scroll_bar().value, 100.0)


func test_sideways_drag_in_a_vertical_list_is_left_alone() -> void:
	_ds._begin(Vector2(100, 150))
	_ds._move(Vector2(40, 145))
	assert_false(_ds._dragging, "horizontal gesture is not claimed")
	assert_almost_eq(_sc.get_v_scroll_bar().value, 100.0)


func test_press_outside_any_scroll_is_ignored() -> void:
	_ds._begin(Vector2(500, 500))
	_ds._move(Vector2(500, 400))
	assert_false(_ds._dragging)
