## CardArt: a recycled card panel must show the new card's art (hand shift bug).
extends "res://tests/framework/test_case.gd"

const CardArt = preload("res://scenes/battle/CardArt.gd")

func _tex() -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)

func test_swaps_texture_on_reused_vbox() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_child(Label.new())
	var a: Texture2D = _tex()
	var b: Texture2D = _tex()
	CardArt.set_texture(vbox, a, 1000.0)
	var art: TextureRect = vbox.get_node(CardArt.NODE_NAME) as TextureRect
	assert_eq(art.get_index(), 0, "art is the first row")
	assert_eq(art.texture, a)
	CardArt.set_texture(vbox, b, 1000.0)
	assert_eq(art.texture, b, "reused panel shows the new card's art")
	assert_eq(vbox.get_child_count(), 2, "no duplicate art rect")
	vbox.free()

func test_hides_art_when_new_card_has_none() -> void:
	var vbox := VBoxContainer.new()
	CardArt.set_texture(vbox, _tex(), 1000.0)
	CardArt.set_texture(vbox, null, 1000.0)
	var art: TextureRect = vbox.get_node(CardArt.NODE_NAME) as TextureRect
	assert_false(art.visible)
	vbox.free()

func test_no_rect_created_without_art() -> void:
	var vbox := VBoxContainer.new()
	CardArt.set_texture(vbox, null, 1000.0)
	assert_eq(vbox.get_child_count(), 0)
	vbox.free()
