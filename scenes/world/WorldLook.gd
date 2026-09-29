## The overworld's base look (BID-055 extraction from WorldScene._setup_environment):
## the Environment (procedural sky, distance fog, ambient, filmic tone mapping,
## emissive-only bloom) and the soft unshadowed fill light. DayNightCycle, weather
## and GraphicsQuality then drive these live; this only builds the starting state.
extends RefCounted


static func make_environment() -> Environment:
	var env := Environment.new()
	# Procedural sky with depth gradient — updated each frame by DayNightCycle
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.04, 0.10, 0.32)
	sky_mat.sky_horizon_color    = Color(0.25, 0.50, 0.85)
	sky_mat.ground_horizon_color = Color(0.20, 0.42, 0.70)
	sky_mat.ground_bottom_color  = Color(0.08, 0.06, 0.04)
	sky_mat.sun_angle_max = 55.0
	sky_mat.sun_curve     = 0.25
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Distance fog for horizon depth
	env.fog_enabled            = true
	env.fog_density            = 0.004
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect         = 0.45
	env.fog_light_color        = Color(0.80, 0.82, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.63, 0.60)
	env.ambient_light_energy = 0.7
	# Filmic tone mapping lifts shadow detail and prevents blown highlights
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# Bloom so emissive materials (items, coins) visibly glow.
	# Threshold must stay above the lit-terrain luminance (~1.0 at midday) so
	# only true emissives bloom — 0.5 made the entire sunlit ground glow.
	# glow_bloom must stay 0: any positive value adds glow to pixels BELOW the
	# threshold too, hazing the whole screen regardless of glow_hdr_threshold.
	env.glow_enabled = true
	env.glow_bloom = 0.0
	env.glow_intensity = 1.0
	env.glow_strength = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_luminance_cap = 12.0
	return env


static func make_fill_light() -> DirectionalLight3D:
	# Soft neutral bounce from above-opposite, no shadows, lifts black areas.
	var light := DirectionalLight3D.new()
	light.light_color = Color(0.78, 0.77, 0.80)
	light.light_energy = 0.35
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0  # unshadowed: would only haze the sun-ray fog
	light.rotation_degrees = Vector3(60.0, 45.0, 0.0)
	return light
