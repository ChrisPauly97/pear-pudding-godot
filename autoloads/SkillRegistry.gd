const SkillData = preload("res://data/SkillData.gd")
const SKILL_DIR := "res://data/skills"

static var _skills: Dictionary = {}  # id -> SkillData
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(SKILL_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := ResourceLoader.load(SKILL_DIR + "/" + fname)
			if res is SkillData:
				var skill := res as SkillData
				_skills[skill.id] = skill
		fname = dir.get_next()

static func get_skill(id: String) -> SkillData:
	_ensure_loaded()
	if _skills.has(id):
		return _skills[id] as SkillData
	return null

static func get_all_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _skills.keys():
		result.append(str(k))
	return result

static func get_by_type(skill_type: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _skills.keys():
		var s: SkillData = _skills[k] as SkillData
		if s != null and s.skill_type == skill_type:
			result.append(str(k))
	return result
