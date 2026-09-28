// Occluded-character silhouette (X-ray pass).
//
// Chained as `next_pass` of a character's sprite_outline material by
// SpriteOutline.apply_xray(). Drawn after the opaque scene with depth testing
// off; each fragment compares its own depth with the scene depth texture and
// only draws where something (a wall, hill or tree) stands in front of the
// character by more than `occlusion_bias`. There it paints a bright two-texel
// rim around the sprite's silhouette plus a faint fill, so the hero stays
// readable behind scenery without cutting the scenery away. Where the
// character is in plain view nothing is drawn (grass tufts at the feet sit
// inside the bias).
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D sprite_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 xray_color : source_color = vec4(1.0, 0.9, 0.55, 1.0);
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.95;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.15;
// View-space distance (world units) an occluder must stand in front.
uniform float occlusion_bias = 0.8;

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy,
			INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float view_depth(vec2 screen_uv, float depth, mat4 inv_proj) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float ndc_z = depth * 2.0 - 1.0;  // GL depth range is [-1, 1]
#else
	float ndc_z = depth;
#endif
	vec4 v = inv_proj * vec4(screen_uv * 2.0 - 1.0, ndc_z, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(sprite_tex, 0));
	float a = texture(sprite_tex, UV).a;
	float n_max = 0.0;
	float n_min = 1.0;
	for (int i = 0; i < 4; i++) {
		vec2 o = i == 0 ? vec2(px.x, 0.0) : i == 1 ? vec2(-px.x, 0.0) : i == 2 ? vec2(0.0, px.y) : vec2(0.0, -px.y);
		float s = texture(sprite_tex, UV + o).a;
		n_max = max(n_max, s);
		n_min = min(n_min, s);
	}
	bool inside = a >= 0.5;
	// Rim: the transparent texel just outside the silhouette and the opaque
	// texel just inside it.
	bool rim = inside ? n_min < 0.5 : n_max >= 0.5;
	if (!inside && !rim) {
		discard;
	}
	float scene = view_depth(SCREEN_UV, texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float self = view_depth(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX);
	if (scene > self - occlusion_bias) {
		discard;
	}
	ALBEDO = xray_color.rgb;
	ALPHA = (rim ? rim_alpha : fill_alpha) * COLOR.a;
}
