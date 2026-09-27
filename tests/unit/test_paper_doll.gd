## Unit tests for the layered player sprite (GID-137).
##
## PaperDoll draws the hero part by part so gear changes the body. Nothing at
## runtime fails loudly if a new item lacks a visual — the hero just looks
## unequipped — so the table is checked against WeaponRegistry here.
extends "res://tests/framework/test_case.gd"

const _PaperDoll = preload("res://game_logic/character/PaperDoll.gd")
const _WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const _HeroAnim = preload("res://game_logic/character/HeroAnim.gd")


func _opaque(img: Image) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n


func _differs(a: Image, b: Image) -> bool:
	return a.get_data() != b.get_data()


func test_frames_keep_legacy_height_and_stand_on_bottom_row() -> void:
	var img: Image = _PaperDoll.render_frame({}, {})
	assert_eq(img.get_width(), _PaperDoll.FRAME_W)
	assert_eq(img.get_height(), _PaperDoll.FRAME_H)
	var feet: bool = false
	for x: int in _PaperDoll.FRAME_W:
		if img.get_pixel(x, _PaperDoll.FRAME_H - 1).a > 0.0:
			feet = true
	assert_true(feet, "feet must touch the bottom row (sprite origin math)")


func test_body_is_centred_in_the_frame() -> void:
	var img: Image = _PaperDoll.render_frame({}, {})
	var lo: int = _PaperDoll.FRAME_W
	var hi: int = -1
	for y: int in _PaperDoll.FRAME_H:
		for x: int in _PaperDoll.FRAME_W:
			if img.get_pixel(x, y).a > 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	assert_true(absi((lo + hi) - _PaperDoll.FRAME_W) <= 3, "idle body off-centre (%d..%d)" % [lo, hi])


func test_every_walk_frame_is_distinct() -> void:
	var seen: Array[PackedByteArray] = [_PaperDoll.render_frame({}, {}).get_data()]
	for i: int in _PaperDoll.WALK_POSES:
		var data: PackedByteArray = _PaperDoll.render_frame({}, {}, "walk", i).get_data()
		assert_false(seen.has(data), "walk frame %d repeats an earlier frame" % i)
		seen.append(data)


func test_sprite_frames_carry_every_animation() -> void:
	var sf: SpriteFrames = _PaperDoll.build_frames({"weapon": "dusk_blade"})
	assert_eq(sf.get_frame_count("idle"), 1)
	assert_eq(sf.get_frame_count("walk"), _PaperDoll.WALK_POSES)
	assert_eq(sf.get_frame_count("swing"), 4)
	assert_eq(sf.get_frame_count("jump"), 2)
	assert_eq(sf.get_frame_count("fall"), 1)
	assert_eq(sf.get_frame_count("land"), 2)
	assert_true(sf.get_animation_loop("walk"))
	assert_false(sf.get_animation_loop("swing"), "swing must end so HeroAnim returns to idle/walk")
	assert_false(sf.get_animation_loop("land"))
	assert_false(sf.has_animation("default"))


func test_swing_rotates_the_weapon_forward() -> void:
	# At the strike the blade points forward, so pixels land right of the body column.
	var gear: Dictionary = {"weapon": "dusk_blade"}
	var strike: Image = _PaperDoll.render_frame(gear, {}, "swing", 1)
	var reach: int = 0
	for y: int in _PaperDoll.FRAME_H:
		for x: int in range(_PaperDoll.OX + 17, _PaperDoll.FRAME_W):
			if strike.get_pixel(x, y).a > 0.0:
				reach += 1
	assert_true(reach >= 3, "strike frame should extend the blade forward (got %d px)" % reach)
	var windup: Image = _PaperDoll.render_frame(gear, {}, "swing", 0)
	assert_true(_differs(windup, strike))


func test_unarmed_swing_still_moves_the_arm() -> void:
	assert_true(_differs(_PaperDoll.render_frame({}, {}), _PaperDoll.render_frame({}, {}, "swing", 1)))


func test_jump_and_land_poses_differ_from_idle() -> void:
	var idle: Image = _PaperDoll.render_frame({}, {})
	for anim: String in ["jump", "fall", "land"]:
		assert_true(_differs(idle, _PaperDoll.render_frame({}, {}, anim, 0)), "%s == idle" % anim)


func test_hero_anim_priorities() -> void:
	assert_eq(_HeroAnim.pick(true, false, 5.0, 1.0, true, &"walk", true), &"idle", "rider sits still")
	assert_eq(_HeroAnim.pick(false, false, 5.0, 0.0, false, &"idle", true), &"jump")
	assert_eq(_HeroAnim.pick(false, false, -2.0, 0.05, true, &"walk", true), &"walk", "slope hop is not a fall")
	assert_eq(_HeroAnim.pick(false, false, -2.0, 0.5, false, &"jump", false), &"fall")
	assert_eq(_HeroAnim.pick(false, true, 0.0, 0.0, true, &"swing", true), &"swing", "swing finishes")
	assert_eq(_HeroAnim.pick(false, true, 0.0, 0.0, true, &"swing", false), &"walk")
	assert_eq(_HeroAnim.pick(false, true, 0.0, 0.0, false, &"land", true), &"land")
	assert_eq(_HeroAnim.pick(false, true, 0.0, 0.0, false, &"land", false), &"idle")


func test_same_look_is_cached() -> void:
	var gear: Dictionary = {"armor": "chainmail"}
	assert_true(_PaperDoll.build_frames(gear) == _PaperDoll.build_frames(gear.duplicate()))
	assert_false(_PaperDoll.build_frames(gear) == _PaperDoll.build_frames({}))


func test_every_visible_item_has_a_visual_that_changes_the_sprite() -> void:
	var base: Image = _PaperDoll.render_frame({}, {})
	for slot: String in _PaperDoll.VISIBLE_SLOTS:
		for id: String in _WeaponRegistry.get_by_slot(slot):
			assert_true(_PaperDoll.GEAR_VISUALS.has(id), "%s (%s) has no PaperDoll visual" % [id, slot])
			var img: Image = _PaperDoll.render_frame({slot: id}, {})
			assert_true(_differs(base, img), "%s draws nothing" % id)


func test_every_visual_is_a_real_item() -> void:
	for id: String in _PaperDoll.GEAR_VISUALS:
		assert_true(_WeaponRegistry.has_weapon(id), "GEAR_VISUALS lists unknown item %s" % id)


func test_armor_covers_torso_and_cloak_widens_silhouette() -> void:
	var base: Image = _PaperDoll.render_frame({}, {})
	var cloak: Image = _PaperDoll.render_frame({"armor": "warded_cloak"}, {})
	assert_true(_opaque(cloak) > _opaque(base), "cloak should add pixels behind the body")
	var mail: Image = _PaperDoll.render_frame({"armor": "chainmail"}, {})
	var chest := Vector2i(_PaperDoll.OX + 8, 13)
	assert_true(mail.get_pixelv(chest) != base.get_pixelv(chest), "chainmail should recolour the chest")


func test_unknown_gear_is_ignored() -> void:
	var base: Image = _PaperDoll.render_frame({}, {})
	assert_false(_differs(base, _PaperDoll.render_frame({"weapon": "no_such_item"}, {})))


func test_appearance_overrides_colours() -> void:
	var base: Image = _PaperDoll.render_frame({}, {})
	var dark: Image = _PaperDoll.render_frame({}, {"hair": Color(0.1, 0.1, 0.1)})
	assert_true(_differs(base, dark))


func test_gear_of_record_reads_equipped_fields() -> void:
	var gear: Dictionary = _PaperDoll.gear_of_record({"equipped_armor": "leather_vest", "equipped_weapon": "dusk_blade"})
	assert_eq(str(gear["armor"]), "leather_vest")
	assert_eq(str(gear["weapon"]), "dusk_blade")
	assert_eq(str(gear["offhand"]), "")


func test_gear_payload_round_trips() -> void:
	var gear: Dictionary = {"armor": "warded_cloak", "shoulders": "spiked_spaulders", "weapon": "dawn_staff",
			"offhand": "", "trinket": "bone_charm"}
	var back: Dictionary = _PaperDoll.decode_gear(_PaperDoll.encode_gear(gear))
	for slot: String in _PaperDoll.VISIBLE_SLOTS:
		assert_eq(str(back[slot]), str(gear[slot]), slot)


func test_gear_payload_rejects_junk() -> void:
	var g: Dictionary = _PaperDoll.decode_gear(["../evil", 42, "dusk_blade"])
	assert_eq(str(g["armor"]), "", "unknown id dropped")
	assert_eq(str(g["shoulders"]), "", "non-string dropped")
	assert_eq(str(g["weapon"]), "dusk_blade")
	assert_eq(str(g["trinket"]), "", "short payload pads with empty slots")
	assert_eq(_PaperDoll.decode_gear("not an array").size(), _PaperDoll.VISIBLE_SLOTS.size())
