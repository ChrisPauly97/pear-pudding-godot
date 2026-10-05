## GID-164 / TID-679: real-time battles refresh the hero HUD every frame, so the
## status row and the hero panel style must not churn nodes / styleboxes when
## nothing changed.
extends "res://tests/framework/test_case.gd"

const BattleFx = preload("res://scenes/battle/BattleFx.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const HeroPanelStyle = preload("res://scenes/battle/HeroPanelStyle.gd")


func test_status_row_rebuilds_only_on_change() -> void:
	var fx := BattleFx.new()
	fx.setup(800.0, null, null, null, null, null, null)
	var hero := HeroState.new(0)
	var row := HBoxContainer.new()
	hero.apply_status("poison", 2)
	fx.update_status_icons_hero(row, hero)
	assert_eq(row.get_child_count(), 1)
	var lbl: Node = row.get_child(0)
	assert_eq((lbl as Label).text, "P2")
	fx.update_status_icons_hero(row, hero)
	assert_eq(row.get_child(0), lbl, "same statuses → same label node")
	assert_false(lbl.is_queued_for_deletion())
	hero.apply_status("armor", 3)
	fx.update_status_icons_hero(row, hero)
	assert_true(lbl.is_queued_for_deletion(), "a changed status rebuilds the row")
	row.free()


func test_hero_panel_style_is_shared_per_state() -> void:
	assert_eq(HeroPanelStyle.key_for(false, true, true), "player")
	assert_eq(HeroPanelStyle.key_for(true, true, true), "spell")
	assert_eq(HeroPanelStyle.key_for(true, false, true), "attack")
	assert_eq(HeroPanelStyle.key_for(true, false, false), "enemy")
	assert_eq(HeroPanelStyle.get_style("enemy"), HeroPanelStyle.get_style("enemy"))
	assert_ne(HeroPanelStyle.get_style("enemy"), HeroPanelStyle.get_style("player"))
	assert_eq(HeroPanelStyle.get_style("spell").border_color, Color.CYAN)
