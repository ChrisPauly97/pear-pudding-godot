// Night light pool (GID-129 / TID-489) — a fake point light that also reaches
// the unshaded grass, props and sprites (BID-060).
//
// Drawn on a small ellipsoid around the light after the opaque pass: front
// faces culled and depth test off, so each covered pixel runs exactly once.
// The fragment reads the depth texture, rebuilds the world position of the
// opaque surface behind the pixel and adds `light_color * energy` by its
// distance to the light centre. Lit or unshaded, everything in reach glows.
// NightLights.gd flickers `energy` per light each frame.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 light_color : source_color = vec3(1.0, 0.72, 0.38);
uniform float energy = 0.5;
uniform float radius = 4.5;
// < 1 stretches the pool upward so a sprite standing in it lights head to toe.
uniform float vertical_squash = 0.75;

varying vec3 center_world;

void vertex() {
	center_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 d = world - center_world;
	d.y *= vertical_squash;
	float t = clamp(1.0 - length(d) / radius, 0.0, 1.0);
	ALBEDO = light_color * (energy * t * t);
}
