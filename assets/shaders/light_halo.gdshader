// Night-light halo (GID-130 / TID-495) — fakes the glow a lamp throws into
// hazy night air, which Forward+ volumetric fog would draw for real.
//
// A camera-facing quad around the light: a wide soft radial falloff, slightly
// taller than wide, depth-faded against whatever stands behind it so the halo
// wraps around walls and the ground instead of cutting through them. Additive.
// NightLights sets `energy` every frame from the flicker × night factor.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 light_color : source_color = vec3(1.0, 0.72, 0.38);
uniform float energy = 0.0;
uniform float softness = 1.2;

void vertex() {
	// Billboard: keep the node's scale, face the camera.
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy,
			INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	c.y *= 0.85;
	float r = length(c);
	float glow = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);

	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float soft = clamp((VERTEX.z - view.z) / softness, 0.0, 1.0);

	ALBEDO = light_color * (energy * glow * soft);
}
