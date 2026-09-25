// Depth-fog post pass (GID-130 / TID-498) — ground fog that reads as volumetric
// on renderers without volumetric fog (Mobile, Compatibility).
//
// A full-screen quad (the vertex shader writes clip space directly) drawn in
// the transparent pass. Each pixel rebuilds the world position of the opaque
// surface behind it from the depth texture, then adds fog by how far that
// surface sits below `fog_top`, broken up by two octaves of world-space value
// noise drifting with the wind. The fog is lit by the sun (or moon) with a
// forward-scattering boost when the camera looks toward the light, and thins
// around the player so the hero never disappears. FakeVolumetrics drives
// `density` (0 hides the node — no cost at midday).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float density : hint_range(0.0, 1.0) = 0.0;
uniform vec3 fog_color : source_color = vec3(0.6, 0.65, 0.72);
uniform vec3 light_color : source_color = vec3(1.0, 0.85, 0.6);
uniform vec3 light_dir = vec3(0.0, 1.0, 0.0);
uniform float fog_top = 1.2;
uniform float fog_depth = 1.6;
uniform float noise_scale = 0.09;
uniform vec2 wind = vec2(0.3, 0.1);
uniform vec3 player_pos = vec3(0.0);
uniform float clear_radius = 3.5;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	float sky = step(0.99999, depth);
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	float sky = step(depth, 0.00001);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;

	float h = clamp((fog_top - world.y) / fog_depth, 0.0, 1.0);
	vec2 q = world.xz * noise_scale;
	float n = vnoise(q + wind * TIME) * 0.65 + vnoise(q * 2.3 - wind * TIME * 1.4) * 0.35;
	float clear = smoothstep(clear_radius * 0.4, clear_radius, distance(world.xz, player_pos.xz));
	float amount = density * h * mix(0.3, 1.0, n) * clear * (1.0 - sky);

	// The iso camera always looks down, so compare headings only: fog facing a
	// low sun glows, fog with the sun behind the camera stays flat.
	vec2 cam_fwd = -INV_VIEW_MATRIX[2].xz;
	vec2 light_h = light_dir.xz;
	float scatter = 0.0;
	if (dot(cam_fwd, cam_fwd) > 0.0001 && dot(light_h, light_h) > 0.0001) {
		scatter = pow(max(dot(normalize(cam_fwd), normalize(light_h)), 0.0), 3.0);
	}
	ALBEDO = fog_color + light_color * (0.15 + 0.45 * scatter) * n;
	ALPHA = clamp(amount, 0.0, 1.0);
}
