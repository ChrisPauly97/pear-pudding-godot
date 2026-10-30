## GID-189: the opt-in frames layout for real-time battles — you top-left, enemies
## top-right (adds stacked under), unit rows under each frame, nothing overlapping
## and everything on screen.
extends "res://tests/framework/test_case.gd"

const FramesLayout = preload("res://scenes/battle/modules/FramesLayout.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")


func _check(vp: Vector2, enemies: int) -> void:
	var vh: float = vp.y
	var frame := Vector2(vh * FramesLayout.FRAME_W, vh * 0.2)
	var unit := Vector2(vh * 0.135, vh * 0.24) * FramesLayout.UNIT_SCALE
	var sizes: Array[Vector2] = []
	for i: int in enemies:
		sizes.append(frame)
	var margin: float = vh * 0.02
	var lay: Dictionary = FramesLayout.frames_layout(vp, frame, sizes, unit, margin)
	var screen := Rect2(Vector2.ZERO, vp)
	var rects: Array[Rect2] = [Rect2(lay["player"], frame)]
	var allies := Rect2(lay["allies"], Vector2(unit.x * RealtimeCombat.MAX_ALLIES, unit.y))
	rects.append(allies)
	var e_pos: Array[Vector2] = lay["enemies"]
	var m_pos: Array[Vector2] = lay["minions"]
	assert_eq(e_pos.size(), enemies)
	for i: int in enemies:
		rects.append(Rect2(e_pos[i], frame))
		rects.append(Rect2(m_pos[i], Vector2(unit.x * RealtimeCombat.MAX_ENEMY_MINIONS, unit.y)))
	for r: Rect2 in rects:
		assert_true(screen.encloses(r), "on screen at %s: %s" % [str(vp), str(r)])
	for a: int in rects.size():
		for b: int in range(a + 1, rects.size()):
			assert_false(rects[a].intersects(rects[b]), "frames %d and %d overlap at %s" % [a, b, str(vp)])
	assert_lt((lay["player"] as Vector2).x, vp.x * 0.5, "you are on the left")
	assert_gt(e_pos[0].x, vp.x * 0.5, "the target is on the right")


func test_landscape_phone_and_desktop() -> void:
	_check(Vector2(1280, 720), 1)
	_check(Vector2(2400, 1080), 1)
	_check(Vector2(1920, 1080), 2)


func test_setting_is_opt_in() -> void:
	assert_eq(FramesLayout.MODES[0], FramesLayout.CLASSIC, "classic is the first (default) option")
	assert_has(FramesLayout.MODES, FramesLayout.FRAMES)
	assert_eq(FramesLayout.MODES.size(), FramesLayout.MODE_LABELS.size())
