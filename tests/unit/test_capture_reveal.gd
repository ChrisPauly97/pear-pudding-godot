## GID-188 / TID-796: the soulbind reveal — a card back that flips to the captured
## card's face and points the player at the Deck Table.
extends "res://tests/framework/test_case.gd"

const CaptureReveal = preload("res://scenes/ui/CaptureReveal.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const MagicTypes = preload("res://game_logic/MagicTypes.gd")


func _reveal(card_id: String) -> CaptureReveal:
	var r: CaptureReveal = CaptureReveal.new()
	r.setup(card_id, 720.0)
	return r


func test_starts_face_down_and_flips_to_the_card() -> void:
	var r := _reveal("wolf")
	assert_false(r.is_face_up(), "starts on the card back")
	r.show_face()
	assert_true(r.is_face_up(), "flips to the face")
	assert_gt(r.custom_minimum_size.y, 720.0 * CaptureReveal.CARD_H_FRAC, "room for the card and the hint")
	r.free()


func test_face_names_the_card_and_hints_the_deck_table() -> void:
	var r := _reveal("wolf")
	var texts: Array[String] = []
	for lbl: Node in r.find_children("*", "Label", true, false):
		texts.append((lbl as Label).text)
	assert_has(texts, str(CardRegistry.get_template("wolf").get("name", "")), "card name shown")
	assert_has(texts, CaptureReveal.DECK_HINT, "Deck Table hint shown")
	r.free()


func test_glow_takes_the_branch_colour() -> void:
	var tmpl: Dictionary = {"magic_branch": MagicTypes.branches_for("light")[0]}
	assert_eq(CaptureReveal.card_color(tmpl), MagicTypes.branch_color(str(tmpl["magic_branch"])))
	assert_eq(CaptureReveal.card_color({}), Color(1.0, 0.85, 0.45), "no branch: gold")
