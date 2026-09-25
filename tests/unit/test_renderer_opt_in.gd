## Unit tests for the opt-in Forward+ renderer on mobile (GID-130 / TID-499).
extends "res://tests/framework/test_case.gd"

const RO = preload("res://game_logic/RendererOptIn.gd")

const _CFG := "user://test_renderer_override.cfg"
const _LOCK := "user://test_renderer_boot.lock"


func _clean() -> void:
	for p: String in [_CFG, _LOCK]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_project_points_at_the_override_file() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/config/project_settings_override", "")), RO.OVERRIDE_PATH)

func test_enable_writes_a_loadable_override() -> void:
	_clean()
	assert_false(RO.is_enabled(_CFG))
	assert_eq(RO.set_enabled(true, _CFG), OK)
	assert_true(RO.is_enabled(_CFG))
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(_CFG), OK)
	assert_eq(str(cfg.get_value("rendering", "renderer/rendering_method.mobile")), "forward_plus")
	RO.set_enabled(false, _CFG)
	assert_false(FileAccess.file_exists(_CFG))
	assert_eq(RO.set_enabled(false, _CFG), OK, "disabling twice is fine")

func test_boot_guard_happy_path() -> void:
	_clean()
	RO.set_enabled(true, _CFG)
	assert_eq(RO.on_boot("forward_plus", _CFG, _LOCK), RO.REVERT_NONE)
	assert_true(FileAccess.file_exists(_LOCK), "an unproven Forward+ boot leaves a lock")
	RO.mark_boot_ok(_LOCK)
	assert_false(FileAccess.file_exists(_LOCK))
	assert_eq(RO.on_boot("forward_plus", _CFG, _LOCK), RO.REVERT_NONE)
	assert_true(RO.is_enabled(_CFG))
	_clean()

func test_boot_guard_reverts_after_a_crash() -> void:
	_clean()
	RO.set_enabled(true, _CFG)
	RO.on_boot("forward_plus", _CFG, _LOCK)  # this boot "crashes": lock never cleared
	assert_eq(RO.on_boot("forward_plus", _CFG, _LOCK), RO.REVERT_CRASH)
	assert_false(RO.is_enabled(_CFG))
	assert_false(FileAccess.file_exists(_LOCK))
	_clean()

func test_boot_guard_reverts_after_a_renderer_fallback() -> void:
	_clean()
	RO.set_enabled(true, _CFG)
	assert_eq(RO.on_boot("gl_compatibility", _CFG, _LOCK), RO.REVERT_FALLBACK)
	assert_false(RO.is_enabled(_CFG))
	_clean()

func test_boot_without_override_is_a_no_op() -> void:
	_clean()
	assert_eq(RO.on_boot("mobile", _CFG, _LOCK), RO.REVERT_NONE)
	assert_false(FileAccess.file_exists(_LOCK))
