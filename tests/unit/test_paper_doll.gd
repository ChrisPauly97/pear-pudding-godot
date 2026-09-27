## Unit tests for the layered player sprite (GID-137).
##
## PaperDoll draws the hero part by part so gear changes the body. Nothing at
## runtime fails loudly if a new item lacks a visual — the hero just looks
## unequipped — so the table is checked against WeaponRegistry here.
extends "res://tests/framework/test_case.gd"

const _PaperDoll = preload("res://game_logic/character/PaperDoll.gd")
const _WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")


func _opaque(img: Image) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n


func _differs(a: Image, b: Image) -> bool:
	return a.get_data() != b.get_data()


func test_frames_match_legacy_size_and_stand_on_bottom_row() -> void:
	var img: Image = _PaperDoll.render_frame({}, {}, 0)
	assert_eq(img.get_width(), _PaperDoll.FRAME_W)
	assert_eq(img.get_height(), _PaperDoll.FRAME_H)
	var feet: bool = false
	for x: int in _PaperDoll.FRAME_W:
		if img.get_pixel(x, _PaperDoll.FRAME_H - 1).a > 0.0:
			feet = true
	assert_true(feet, "feet must touch the bottom row (sprite origin math)")


func test_walk_frames_differ_from_idle() -> void:
	var idle: Image = _PaperDoll.render_frame({}, {}, 0)
	for pose: int in range(1, _PaperDoll.WALK_POSES + 1):
		assert_true(_differs(idle, _PaperDoll.render_frame({}, {}, pose)), "walk pose %d == idle" % pose)


func test_sprite_frames_have_idle_and_walk() -> void:
	var sf: SpriteFrames = _PaperDoll.build_frames({}, {}, 6.0)
	assert_eq(sf.get_frame_count("idle"), 1)
	assert_eq(sf.get_frame_count("walk"), _PaperDoll.WALK_POSES)
	assert_false(sf.has_animation("default"))


func test_same_look_is_cached() -> void:
	var gear: Dictionary = {"armor": "chainmail"}
	assert_true(_PaperDoll.build_frames(gear) == _PaperDoll.build_frames(gear.duplicate()))
	assert_false(_PaperDoll.build_frames(gear) == _PaperDoll.build_frames({}))


func test_every_visible_item_has_a_visual_that_changes_the_sprite() -> void:
	var base: Image = _PaperDoll.render_frame({}, {}, 0)
	for slot: String in _PaperDoll.VISIBLE_SLOTS:
		for id: String in _WeaponRegistry.get_by_slot(slot):
			assert_true(_PaperDoll.GEAR_VISUALS.has(id), "%s (%s) has no PaperDoll visual" % [id, slot])
			var img: Image = _PaperDoll.render_frame({slot: id}, {}, 0)
			assert_true(_differs(base, img), "%s draws nothing" % id)


func test_every_visual_is_a_real_item() -> void:
	for id: String in _PaperDoll.GEAR_VISUALS:
		assert_true(_WeaponRegistry.has_weapon(id), "GEAR_VISUALS lists unknown item %s" % id)


func test_armor_covers_torso_and_cloak_widens_silhouette() -> void:
	var base: Image = _PaperDoll.render_frame({}, {}, 0)
	var cloak: Image = _PaperDoll.render_frame({"armor": "warded_cloak"}, {}, 0)
	assert_true(_opaque(cloak) > _opaque(base), "cloak should add pixels behind the body")
	var mail: Image = _PaperDoll.render_frame({"armor": "chainmail"}, {}, 0)
	assert_true(mail.get_pixel(8, 13) != base.get_pixel(8, 13), "chainmail should recolour the chest")


func test_unknown_gear_is_ignored() -> void:
	var base: Image = _PaperDoll.render_frame({}, {}, 0)
	assert_false(_differs(base, _PaperDoll.render_frame({"weapon": "no_such_item"}, {}, 0)))


func test_appearance_overrides_colours() -> void:
	var base: Image = _PaperDoll.render_frame({}, {}, 0)
	var dark: Image = _PaperDoll.render_frame({}, {"hair": Color(0.1, 0.1, 0.1)}, 0)
	assert_true(_differs(base, dark))


func test_gear_of_record_reads_equipped_fields() -> void:
	var gear: Dictionary = _PaperDoll.gear_of_record({"equipped_armor": "leather_vest", "equipped_weapon": "dusk_blade"})
	assert_eq(str(gear["armor"]), "leather_vest")
	assert_eq(str(gear["weapon"]), "dusk_blade")
	assert_eq(str(gear["offhand"]), "")
