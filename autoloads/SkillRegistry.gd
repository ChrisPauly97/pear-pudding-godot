const SkillData = preload("res://data/SkillData.gd")
const RegistryUtil = preload("res://game_logic/RegistryUtil.gd")

# Explicit preloads create a compile-time dependency chain so Godot's export
# scanner includes these files in the Android APK. Add a line here whenever a
# new skill .tres is created.
const _S_ASH_BONE_ARMOUR     := preload("res://data/skills/ash_bone_armour.tres")
const _S_BLOOM_BOUNTIFUL_HARVEST   := preload("res://data/skills/bloom_bountiful_harvest.tres")
const _S_BLOOM_DEEP_ROOTS          := preload("res://data/skills/bloom_deep_roots.tres")
const _S_BLOOM_FIRST_SHOOTS        := preload("res://data/skills/bloom_first_shoots.tres")
const _S_BLOOM_OVERGROWTH          := preload("res://data/skills/bloom_overgrowth.tres")
const _S_BLOOM_SEEDLING            := preload("res://data/skills/bloom_seedling.tres")
const _S_BLOOM_SUNWARD_REACH       := preload("res://data/skills/bloom_sunward_reach.tres")
const _S_FLUX_KINETIC_CHARGE       := preload("res://data/skills/flux_kinetic_charge.tres")
const _S_FLUX_LEYWARD_FOCUS        := preload("res://data/skills/flux_leyward_focus.tres")
const _S_FLUX_MANA_SURGE           := preload("res://data/skills/flux_mana_surge.tres")
const _S_FLUX_PHASE_SHIFT          := preload("res://data/skills/flux_phase_shift.tres")
const _S_FLUX_REWEAVE              := preload("res://data/skills/flux_reweave.tres")
const _S_FLUX_UNSTABLE_FORM        := preload("res://data/skills/flux_unstable_form.tres")
const _S_FRACTURE_FAULT_LINE       := preload("res://data/skills/fracture_fault_line.tres")
const _S_FRACTURE_HAIRLINE_CRACK   := preload("res://data/skills/fracture_hairline_crack.tres")
const _S_FRACTURE_HOLLOW_CORE      := preload("res://data/skills/fracture_hollow_core.tres")
const _S_FRACTURE_SCAVENGED_SHARDS := preload("res://data/skills/fracture_scavenged_shards.tres")
const _S_FRACTURE_SHATTERWAVE      := preload("res://data/skills/fracture_shatterwave.tres")
const _S_FRACTURE_SPLINTERING      := preload("res://data/skills/fracture_splintering.tres")
const _S_THORN_BARBED_GROWTH       := preload("res://data/skills/thorn_barbed_growth.tres")
const _S_THORN_BRAMBLE_WALL        := preload("res://data/skills/thorn_bramble_wall.tres")
const _S_THORN_RAMPANT_VINES       := preload("res://data/skills/thorn_rampant_vines.tres")
const _S_THORN_SECOND_BLOOM        := preload("res://data/skills/thorn_second_bloom.tres")
const _S_THORN_THORNBURST          := preload("res://data/skills/thorn_thornburst.tres")
const _S_THORN_WILD_SAP            := preload("res://data/skills/thorn_wild_sap.tres")
const _S_ASH_BRITTLE_CURSE   := preload("res://data/skills/ash_brittle_curse.tres")
const _S_ASH_BRITTLE_EDGE    := preload("res://data/skills/ash_brittle_edge.tres")
const _S_ASH_CINDERHEART     := preload("res://data/skills/ash_cinderheart.tres")
const _S_ASH_ENTROPY         := preload("res://data/skills/ash_entropy.tres")
const _S_ASH_GRAVE_CALL      := preload("res://data/skills/ash_grave_call.tres")
const _S_DAWN_ARCANE_CLARITY := preload("res://data/skills/dawn_arcane_clarity.tres")
const _S_DAWN_CLARITY        := preload("res://data/skills/dawn_clarity.tres")
const _S_DAWN_INNER_LIGHT    := preload("res://data/skills/dawn_inner_light.tres")
const _S_DAWN_RADIANT_SHIELD := preload("res://data/skills/dawn_radiant_shield.tres")
const _S_DAWN_RESTORATION    := preload("res://data/skills/dawn_restoration.tres")
const _S_DAWN_WELLSPRING     := preload("res://data/skills/dawn_wellspring.tres")
const _S_DUSK_DARK_PACT      := preload("res://data/skills/dusk_dark_pact.tres")
const _S_DUSK_LIFETAP        := preload("res://data/skills/dusk_lifetap.tres")
const _S_DUSK_MANA_DRAIN     := preload("res://data/skills/dusk_mana_drain.tres")
const _S_DUSK_SHADOW_WELL    := preload("res://data/skills/dusk_shadow_well.tres")
const _S_DUSK_SOUL_SIPHON    := preload("res://data/skills/dusk_soul_siphon.tres")
const _S_DUSK_VOID_TEMPO     := preload("res://data/skills/dusk_void_tempo.tres")
const _S_EMBER_BLAZING_DRAW  := preload("res://data/skills/ember_blazing_draw.tres")
const _S_EMBER_FLAME_TEMPO   := preload("res://data/skills/ember_flame_tempo.tres")
const _S_EMBER_INFERNO_SURGE := preload("res://data/skills/ember_inferno_surge.tres")
const _S_EMBER_PYROBLAST     := preload("res://data/skills/ember_pyroblast.tres")
const _S_EMBER_SEARING_FOCUS := preload("res://data/skills/ember_searing_focus.tres")
const _S_EMBER_TORCH_BEARER  := preload("res://data/skills/ember_torch_bearer.tres")

static var _skills: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_skills = RegistryUtil.build_id_dict([
		_S_ASH_BONE_ARMOUR, _S_ASH_BRITTLE_CURSE, _S_ASH_BRITTLE_EDGE,
		_S_ASH_CINDERHEART, _S_ASH_ENTROPY, _S_ASH_GRAVE_CALL,
		_S_DAWN_ARCANE_CLARITY, _S_DAWN_CLARITY, _S_DAWN_INNER_LIGHT,
		_S_DAWN_RADIANT_SHIELD, _S_DAWN_RESTORATION, _S_DAWN_WELLSPRING,
		_S_DUSK_DARK_PACT, _S_DUSK_LIFETAP, _S_DUSK_MANA_DRAIN,
		_S_DUSK_SHADOW_WELL, _S_DUSK_SOUL_SIPHON, _S_DUSK_VOID_TEMPO,
		_S_EMBER_BLAZING_DRAW, _S_EMBER_FLAME_TEMPO, _S_EMBER_INFERNO_SURGE,
		_S_EMBER_PYROBLAST, _S_EMBER_SEARING_FOCUS, _S_EMBER_TORCH_BEARER,
		_S_BLOOM_BOUNTIFUL_HARVEST, _S_BLOOM_DEEP_ROOTS,
		_S_BLOOM_FIRST_SHOOTS, _S_BLOOM_OVERGROWTH,
		_S_BLOOM_SEEDLING, _S_BLOOM_SUNWARD_REACH,
		_S_THORN_BARBED_GROWTH, _S_THORN_BRAMBLE_WALL,
		_S_THORN_RAMPANT_VINES, _S_THORN_SECOND_BLOOM,
		_S_THORN_THORNBURST, _S_THORN_WILD_SAP,
		_S_FLUX_KINETIC_CHARGE, _S_FLUX_LEYWARD_FOCUS,
		_S_FLUX_MANA_SURGE, _S_FLUX_PHASE_SHIFT,
		_S_FLUX_REWEAVE, _S_FLUX_UNSTABLE_FORM,
		_S_FRACTURE_FAULT_LINE, _S_FRACTURE_HAIRLINE_CRACK,
		_S_FRACTURE_HOLLOW_CORE, _S_FRACTURE_SCAVENGED_SHARDS,
		_S_FRACTURE_SHATTERWAVE, _S_FRACTURE_SPLINTERING,
	], "SkillRegistry")

static func get_skill(id: String) -> SkillData:
	_ensure_loaded()
	if _skills.has(id):
		return _skills[id] as SkillData
	return null

static func get_all_ids() -> Array[String]:
	_ensure_loaded()
	return RegistryUtil.get_all_ids(_skills)

static func get_by_branch(branch: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _skills.keys():
		var s: SkillData = _skills[k] as SkillData
		if s != null and s.magic_branch == branch:
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
