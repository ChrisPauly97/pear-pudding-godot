## Loads every project script once so GDScript's analyzer runs over all of them.
## Only meaningful under tests/typecheck/override.cfg (scripts/check-typed-access.sh
## installs it), which raises the unsafe-access warnings to errors. The check then
## fails on any access to a member that does not exist on a known project-script type.
extends SceneTree


func _walk(dir_path: String) -> void:
	for f: String in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			load(dir_path.path_join(f))
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with("."):
			_walk(dir_path.path_join(sub))


func _initialize() -> void:
	await process_frame  # autoloads must be registered before scripts that name them compile
	_walk("res://")
	quit()
