## GID-145 / TID-617: a besieged town swaps its track for the siege music.
extends "res://tests/framework/test_case.gd"

const _TownSiege = preload("res://scenes/world/modules/TownSiege.gd")

const TOWN_TRACK := "res://assets/audio/music/grasslands.ogg"

func test_siege_track_is_shipped() -> void:
	assert_true(ResourceLoader.exists(_TownSiege.SIEGE_MUSIC), "siege.ogg must be imported")

func test_no_siege_keeps_town_track() -> void:
	assert_eq(_TownSiege.pick_music("madrian", TOWN_TRACK, {}, ""), TOWN_TRACK)

func test_solo_siege_on_this_town_plays_siege_track() -> void:
	var active: Dictionary = {"town": "madrian", "stage": 0}
	assert_eq(_TownSiege.pick_music("madrian", TOWN_TRACK, active, ""), _TownSiege.SIEGE_MUSIC)

func test_siege_elsewhere_keeps_town_track() -> void:
	var active: Dictionary = {"town": "marsax_hold", "stage": 1}
	assert_eq(_TownSiege.pick_music("madrian", TOWN_TRACK, active, ""), TOWN_TRACK)

func test_coop_siege_on_this_town_plays_siege_track() -> void:
	assert_eq(_TownSiege.pick_music("madrian", TOWN_TRACK, {}, "madrian"), _TownSiege.SIEGE_MUSIC)

func test_wilds_never_play_siege_track() -> void:
	assert_eq(_TownSiege.pick_music("", "", {"town": ""}, ""), "")
