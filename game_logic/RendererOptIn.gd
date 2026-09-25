extends RefCounted
## Opt-in Forward+ renderer on mobile (GID-130 / TID-499).
##
## The renderer is fixed at boot. project.godot points
## `application/config/project_settings_override` at OVERRIDE_PATH; when that
## file sets `rendering/renderer/rendering_method.mobile = "forward_plus"`, the
## next launch on a phone runs Forward+ and GraphicsQuality's High tier gets
## the real volumetric fog / SSAO path. The file itself is the setting — no
## save field — so it is read before any script runs.
##
## Crash guard: `on_boot()` drops LOCK_PATH while a Forward+ boot is unproven
## and `mark_boot_ok()` removes it once the game has run for BOOT_OK_SECONDS.
## A boot that finds the lock still there (the last Forward+ run died early)
## deletes the override, and so does a boot where Godot fell back to another
## renderer (Vulkan missing), since that fallback is Compatibility, not Mobile.

const OVERRIDE_PATH := "user://renderer_override.cfg"
const LOCK_PATH := "user://renderer_boot.lock"
const SECTION := "rendering"
const KEY := "renderer/rendering_method.mobile"
const FORWARD_PLUS := "forward_plus"
const BOOT_OK_SECONDS: float = 20.0

## Why `on_boot` reverted the override ("" = it didn't).
const REVERT_NONE := ""
const REVERT_CRASH := "crash"
const REVERT_FALLBACK := "fallback"


static func is_enabled(path: String = OVERRIDE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	return str(cfg.get_value(SECTION, KEY, "")) == FORWARD_PLUS


## Writes (or deletes) the override for the next launch.
static func set_enabled(enabled: bool, path: String = OVERRIDE_PATH) -> Error:
	if not enabled:
		if FileAccess.file_exists(path):
			return DirAccess.remove_absolute(path)
		return OK
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY, FORWARD_PLUS)
	return cfg.save(path)


## Run once at startup on mobile with the renderer actually running. Returns a
## REVERT_* reason when it turned the override off.
static func on_boot(running_method: String, path: String = OVERRIDE_PATH, lock: String = LOCK_PATH) -> String:
	if not is_enabled(path):
		if FileAccess.file_exists(lock):
			DirAccess.remove_absolute(lock)
		return REVERT_NONE
	var reason: String = REVERT_NONE
	if FileAccess.file_exists(lock):
		reason = REVERT_CRASH
	elif running_method != FORWARD_PLUS:
		reason = REVERT_FALLBACK
	if reason != REVERT_NONE:
		set_enabled(false, path)
		if FileAccess.file_exists(lock):
			DirAccess.remove_absolute(lock)
		return reason
	var f := FileAccess.open(lock, FileAccess.WRITE)
	if f != null:
		f.store_string("booting")
		f.close()
	return REVERT_NONE


## The Forward+ boot survived; forget the lock.
static func mark_boot_ok(lock: String = LOCK_PATH) -> void:
	if FileAccess.file_exists(lock):
		DirAccess.remove_absolute(lock)
