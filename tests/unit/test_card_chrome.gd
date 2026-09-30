## CardChrome (GID-151 / TID-631): every magic type has its own frame and the
## shared chrome pieces load.
extends "res://tests/framework/test_case.gd"

const CardChrome = preload("res://game_logic/CardChrome.gd")
const MagicTypes = preload("res://game_logic/MagicTypes.gd")

func test_every_magic_type_has_a_frame() -> void:
	for mt: String in MagicTypes.all_types():
		assert_true(CardChrome.has_frame(mt), "%s has no card frame" % mt)
		assert_not_null(CardChrome.frame_texture(mt))

func test_unknown_type_gets_neutral_frame() -> void:
	var neutral: Texture2D = CardChrome.frame_texture("")
	assert_not_null(neutral)
	assert_eq(CardChrome.frame_texture("nope"), neutral)
	assert_ne(CardChrome.frame_texture("light"), neutral)

func test_frames_are_nine_sliceable() -> void:
	for mt: String in MagicTypes.all_types():
		var tex: Texture2D = CardChrome.frame_texture(mt)
		assert_true(tex.get_width() > CardChrome.FRAME_MARGIN * 2, "%s frame too narrow" % mt)
		assert_true(tex.get_height() > CardChrome.FRAME_MARGIN * 2, "%s frame too short" % mt)

func test_chrome_pieces_load() -> void:
	for tex: Texture2D in [CardChrome.back_texture(), CardChrome.crest_texture(), CardChrome.gem_texture(),
			CardChrome.attack_badge_texture(), CardChrome.health_badge_texture(), CardChrome.plate_texture()]:
		assert_not_null(tex)
