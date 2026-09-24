## Loads project scripts so GDScript's analyzer runs over them. With no user args
## it walks all of res://; with `-- res://a.gd res://b.gd` it loads only those.
## Unsafe member access is an error project-wide (project.godot), so every hit
## prints as a "Parse Error" with its file and line.
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
	var files: PackedStringArray = OS.get_cmdline_user_args()
	if files.is_empty():
		_walk("res://")
	else:
		for f: String in files:
			load(f)
	quit()
