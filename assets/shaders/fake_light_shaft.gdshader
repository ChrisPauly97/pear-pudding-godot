// Fake light shaft (GID-130 / TID-495) — a stand-in for volumetric sun shafts
// on renderers without volumetric fog (Mobile, Compatibility).
//
// A unit QuadMesh on a translation-only node whose origin sits on the ground.
// The vertex shader lays the quad along `axis` (pointing up toward the sun)
// and turns it about that axis to face the camera, so from the iso view every
// shaft reads as a slanted soft beam. The fragment fades the edges, both ends
// and — via the depth texture — wherever the beam meets the ground or a
// sprite, so there is never a hard intersection line. Additive; FakeVolumetrics
// sets `strength` from the dawn/dusk ray strength and hides it at 0.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 axis = vec3(0.0, 1.0, 0.0);
uniform float width = 1.6;
uniform float shaft_length = 14.0;
uniform vec3 shaft_color : source_color = vec3(1.0, 0.8, 0.5);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Peak added brightness at full strength.
uniform float intensity = 0.22;
// World units over which the beam fades out in front of the surface behind it.
uniform float softness = 1.5;
uniform float seed = 0.0;

void vertex() {
	vec3 a = normalize(axis);
	vec3 cam_back = normalize(INV_VIEW_MATRIX[2].xyz);
	vec3 right = cross(a, cam_back);
	right = length(right) > 0.001 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	VERTEX = right * VERTEX.x * width + a * (VERTEX.y + 0.5) * shaft_length;
}

void fragment() {
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	edge *= edge;
	// UV.y: 0 at the sky end, 1 on the ground.
	float ends = smoothstep(0.0, 0.5, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
	// One slow, low-contrast swell per beam. A higher-frequency band here
	// (TID-500: sin(UV.y * 22)) read as moving wavy stripes on device.
	float motes = 0.92 + 0.08 * sin(UV.y * 3.0 - TIME * 0.25 + seed * 6.2831);
	float breathe = 0.85 + 0.15 * sin(TIME * 0.3 + seed * 12.0);

	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float soft = clamp((VERTEX.z - view.z) / softness, 0.0, 1.0);

	ALBEDO = shaft_color * (strength * intensity * edge * ends * motes * breathe * soft);
}
