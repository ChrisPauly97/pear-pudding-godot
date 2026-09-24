## Factory for weather particle nodes.
## Creates a GPUParticles3D node configured for the given weather type.
## The caller is responsible for parenting and positioning the node.
extends Node3D

const _WeatherLook = preload("res://game_logic/WeatherLook.gd")

static func make(weather_id: String) -> GPUParticles3D:
	var node := GPUParticles3D.new()
	node.emitting = true
	node.one_shot = false

	var mat := ParticleProcessMaterial.new()
	var mesh := QuadMesh.new()

	match weather_id:
		"rain":
			node.amount = 200
			node.lifetime = 3.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(30.0, 0.5, 30.0)
			mat.direction = Vector3(0.15, -1.0, 0.0)
			mat.spread = 5.0
			mat.initial_velocity_min = 8.0
			mat.initial_velocity_max = 12.0
			mat.gravity = Vector3(0.0, -9.8, 0.0)
			mat.color = Color(0.7, 0.8, 1.0, 0.45)
			mesh.size = Vector2(0.025, 0.18)

		"heavy_rain":
			node.amount = 350
			node.lifetime = 2.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(30.0, 0.5, 30.0)
			mat.direction = Vector3(0.25, -1.0, 0.0)
			mat.spread = 5.0
			mat.initial_velocity_min = 12.0
			mat.initial_velocity_max = 18.0
			mat.gravity = Vector3(0.0, -9.8, 0.0)
			mat.color = Color(0.6, 0.7, 0.95, 0.55)
			mesh.size = Vector2(0.025, 0.22)

		"sandstorm":
			node.amount = 150
			node.lifetime = 4.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(32.0, 3.0, 32.0)
			mat.direction = Vector3(1.0, 0.05, 0.2)
			mat.spread = 15.0
			mat.initial_velocity_min = 5.0
			mat.initial_velocity_max = 10.0
			mat.gravity = Vector3(0.0, 0.0, 0.0)
			mat.color = Color(0.85, 0.70, 0.40, 0.35)
			mesh.size = Vector2(0.08, 0.08)

		"dust_devil":
			node.amount = 80
			node.lifetime = 4.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			mat.emission_sphere_radius = 2.0
			mat.direction = Vector3(0.5, 0.5, 0.5)
			mat.spread = 45.0
			mat.initial_velocity_min = 3.0
			mat.initial_velocity_max = 6.0
			mat.gravity = Vector3(0.0, 1.0, 0.0)
			mat.color = Color(0.75, 0.62, 0.38, 0.30)
			mesh.size = Vector2(0.07, 0.07)

		"ash_fall":
			node.amount = 80
			node.lifetime = 5.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(30.0, 0.5, 30.0)
			mat.direction = Vector3(0.1, -1.0, 0.05)
			mat.spread = 8.0
			mat.initial_velocity_min = 0.8
			mat.initial_velocity_max = 2.0
			mat.gravity = Vector3(0.0, -0.5, 0.0)
			mat.color = Color(0.45, 0.42, 0.40, 0.50)
			mesh.size = Vector2(0.07, 0.07)

		"volcanic":
			node.amount = 100
			node.lifetime = 4.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(28.0, 0.5, 28.0)
			mat.direction = Vector3(0.2, -1.0, 0.1)
			mat.spread = 10.0
			mat.initial_velocity_min = 1.0
			mat.initial_velocity_max = 3.0
			mat.gravity = Vector3(0.0, -0.5, 0.0)
			mat.color = Color(0.3, 0.25, 0.22, 0.60)
			mesh.size = Vector2(0.09, 0.09)

		"snow":
			node.amount = 120
			node.lifetime = 4.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(30.0, 0.5, 30.0)
			mat.direction = Vector3(0.1, -1.0, 0.05)
			mat.spread = 20.0
			mat.initial_velocity_min = 0.6
			mat.initial_velocity_max = 1.5
			mat.gravity = Vector3(0.0, -0.4, 0.0)
			mat.color = Color(0.95, 0.96, 1.0, 0.70)
			mesh.size = Vector2(0.09, 0.09)

		"blizzard":
			node.amount = 250
			node.lifetime = 3.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(32.0, 2.0, 32.0)
			mat.direction = Vector3(0.8, -0.5, 0.2)
			mat.spread = 12.0
			mat.initial_velocity_min = 5.0
			mat.initial_velocity_max = 10.0
			mat.gravity = Vector3(0.0, -1.5, 0.0)
			mat.color = Color(0.90, 0.92, 1.0, 0.60)
			mesh.size = Vector2(0.07, 0.07)

		_:
			return null

	var std_mat := StandardMaterial3D.new()
	std_mat.albedo_color = mat.color
	std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	std_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	std_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh.material = std_mat  # TID-493: was built but never assigned
	node.process_material = mat
	node.draw_pass_1 = mesh
	node.position = Vector3(0.0, 12.0, 0.0)
	return node

# Wind direction per weather type (Vector2: X and Z bias). The per-weather look
# table (tint, wind, fog, sun) lives in WeatherLook; these are thin delegates.
static func get_wind_direction(weather_id: String) -> Vector2:
	return _WeatherLook.wind_direction(weather_id)

# Screen tint color per weather type (multiply over day/night ambient)
static func get_screen_tint(weather_id: String) -> Color:
	return _WeatherLook.screen_tint(weather_id)
